require 'rails_helper'

RSpec.describe Versions::Revert, type: :service do
  let(:owner) { create(:user) }
  let(:note) { create(:note, owner: owner) }
  let(:editor) { create(:user) }
  let(:unauthorized_user) { create(:user) }
  let(:v1) { create(:version, note: note, author: owner, content: 'Version 1') }
  let(:v2) { create(:version, note: note, author: owner, content: 'Version 2', parent_version: v1) }
  let(:v3) { create(:version, note: note, author: owner, content: 'Version 3', parent_version: v2) }

  before do
    create(:collaborator, :editor, note: note, user: editor)
    note.update_column(:head_version_id, v3.id)
  end

  describe '#call' do
    context 'with valid params' do
      it 'creates new version with reverted content' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        expect { service.call }.to change { Version.count }.by(1)
      end

      it 'copies content from target version' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        reverted = service.call
        expect(reverted.content).to eq(v1.content)
        expect(reverted.content).to eq('Version 1')
      end

      it 'sets current head as parent of revert version' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        reverted = service.call
        expect(reverted.parent_version_id).to eq(v3.id)
      end

      it 'atomically updates note.head_version_id' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        reverted = service.call
        expect(note.reload.head_version_id).to eq(reverted.id)
      end

      it 'sets default summary when not provided' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        reverted = service.call
        expect(reverted.summary).to eq("Reverted to version #{v1.id}")
      end

      it 'uses custom summary when provided' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id,
          summary: 'Custom revert message'
        )

        reverted = service.call
        expect(reverted.summary).to eq('Custom revert message')
      end

      it 'allows owner to revert' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        expect { service.call }.not_to raise_error
      end

      it 'allows editor to revert' do
        service = described_class.new(
          note: note,
          author: editor,
          target_version_id: v1.id
        )

        expect { service.call }.not_to raise_error
      end

      it 'logs revert operation' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        allow(Rails.logger).to receive(:info)
        reverted = service.call

        expect(Rails.logger).to have_received(:info).with(
          /Version reverted: new_version_id=#{reverted.id}.*target_version_id=#{v1.id}/
        )
      end
    end

    context 'reverting to first version' do
      it 'reverts to version with nil parent' do
        expect(v1.parent_version).to be_nil

        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        reverted = service.call
        expect(reverted.content).to eq(v1.content)
        expect(reverted.parent_version_id).to eq(v3.id)
      end
    end

    context 'validation' do
      it 'validates target version belongs to same note' do
        other_note = create(:note, :with_head_version)
        other_version = other_note.head_version

        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: other_version.id
        )

        expect { service.call }.to raise_error(
          Versions::Revert::InvalidTargetError,
          /Target version must belong to the same note/
        )
      end

      it 'rejects non-existent target_version_id' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: 99999
        )

        expect { service.call }.to raise_error(
          Versions::Revert::InvalidTargetError
        )
      end
    end

    context 'authorization' do
      it 'rejects unauthorized user (viewer)' do
        viewer = create(:user)
        create(:collaborator, :viewer, note: note, user: viewer)

        service = described_class.new(
          note: note,
          author: viewer,
          target_version_id: v1.id
        )

        expect { service.call }.to raise_error(
          Versions::Revert::UnauthorizedError,
          /does not have permission to revert versions/
        )
      end

      it 'rejects completely unauthorized user' do
        service = described_class.new(
          note: note,
          author: unauthorized_user,
          target_version_id: v1.id
        )

        expect { service.call }.to raise_error(
          Versions::Revert::UnauthorizedError
        )
      end
    end

    context 'transaction behavior' do
      it 'rolls back on failure' do
        allow_any_instance_of(Note).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new)

        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        initial_count = Version.count
        expect { service.call }.to raise_error(Versions::Revert::Error)
        expect(Version.count).to eq(initial_count)
        expect(note.reload.head_version_id).to eq(v3.id)
      end

      it 'ensures atomicity of revert version creation and head update' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        # Mock to ensure transaction wraps both operations
        expect(ActiveRecord::Base).to receive(:transaction).and_call_original

        service.call
      end
    end

    context 'edge cases' do
      it 'can revert to the current head (no-op content-wise)' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v3.id
        )

        reverted = service.call
        expect(reverted.content).to eq(v3.content)
        expect(reverted.parent_version_id).to eq(v3.id)
      end

      it 'creates valid version chain after revert' do
        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        v4_reverted = service.call

        expect(v4_reverted.parent_version).to eq(v3)
        expect(v3.child_versions).to include(v4_reverted)
        expect(note.reload.head_version).to eq(v4_reverted)
      end

      it 'can revert multiple times in sequence' do
        revert1 = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        ).call

        note.reload

        revert2 = described_class.new(
          note: note,
          author: owner,
          target_version_id: v2.id
        ).call

        expect(revert2.parent_version).to eq(revert1)
        expect(note.reload.head_version).to eq(revert2)
      end

      it 'handles reverting when note has single version' do
        single_note = create(:note)
        single_version = create(:version, note: single_note, author: owner)
        single_note.update_column(:head_version_id, single_version.id)

        service = described_class.new(
          note: single_note,
          author: owner,
          target_version_id: single_version.id
        )

        reverted = service.call
        expect(reverted.content).to eq(single_version.content)
      end
    end

    context 'error handling' do
      it 'wraps ActiveRecord::RecordInvalid errors' do
        allow_any_instance_of(Version).to receive(:save!).and_raise(
          ActiveRecord::RecordInvalid.new
        )

        service = described_class.new(
          note: note,
          author: owner,
          target_version_id: v1.id
        )

        expect { service.call }.to raise_error(
          Versions::Revert::Error,
          /Failed to revert version/
        )
      end
    end
  end
end
