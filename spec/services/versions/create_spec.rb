require 'rails_helper'

RSpec.describe Versions::Create, type: :service do
  let(:owner) { create(:user) }
  let(:note) { create(:note, owner: owner) }
  let(:editor) { create(:user) }
  let(:unauthorized_user) { create(:user) }

  before do
    create(:collaborator, :editor, note: note, user: editor)
  end

  describe '#call' do
    context 'with valid params' do
      it 'creates version successfully' do
        service = described_class.new(
          note: note,
          author: owner,
          content: 'Test content',
          summary: 'Test summary'
        )

        expect { service.call }.to change { Version.count }.by(1)
      end

      it 'returns the created version' do
        service = described_class.new(
          note: note,
          author: owner,
          content: 'Test content',
          summary: 'Test summary'
        )

        version = service.call
        expect(version).to be_a(Version)
        expect(version).to be_persisted
        expect(version.content).to eq('Test content')
        expect(version.summary).to eq('Test summary')
      end

      it 'atomically updates note.head_version_id in transaction' do
        service = described_class.new(
          note: note,
          author: owner,
          content: 'Test content',
          summary: 'Test summary'
        )

        version = service.call
        expect(note.reload.head_version_id).to eq(version.id)
      end

      it 'sets parent_version_id to current head if not provided' do
        first_version = create(:version, note: note, author: owner)
        note.update_column(:head_version_id, first_version.id)

        service = described_class.new(
          note: note,
          author: owner,
          content: 'Second version',
          summary: 'Summary'
        )

        version = service.call
        expect(version.parent_version_id).to eq(first_version.id)
      end

      it 'allows owner to create version' do
        service = described_class.new(
          note: note,
          author: owner,
          content: 'Content',
          summary: 'Summary'
        )

        expect { service.call }.not_to raise_error
      end

      it 'allows editor to create version' do
        service = described_class.new(
          note: note,
          author: editor,
          content: 'Content',
          summary: 'Summary'
        )

        expect { service.call }.not_to raise_error
      end

      it 'logs version creation' do
        service = described_class.new(
          note: note,
          author: owner,
          content: 'Content',
          summary: 'Summary'
        )

        allow(Rails.logger).to receive(:info)
        version = service.call

        expect(Rails.logger).to have_received(:info).with(
          /Version created: id=#{version.id}, note_id=#{note.id}/
        )
      end
    end

    context 'first version (bootstrap case)' do
      it 'creates first version when note has no head_version_id' do
        service = described_class.new(
          note: note,
          author: owner,
          content: 'First version',
          summary: 'Initial'
        )

        version = service.call
        expect(version.parent_version_id).to be_nil
        expect(note.reload.head_version_id).to eq(version.id)
      end

      it 'handles nil head_version_id correctly' do
        expect(note.head_version_id).to be_nil

        service = described_class.new(
          note: note,
          author: owner,
          content: 'Content',
          summary: 'Summary'
        )

        expect { service.call }.to change { Version.count }.by(1)
      end
    end

    context 'with explicit parent_version_id' do
      it 'uses provided parent_version_id' do
        v1 = create(:version, note: note)
        v2 = create(:version, note: note, parent_version: v1)
        note.update_column(:head_version_id, v2.id)

        # Create v3 with explicit parent v1 (not current head v2)
        service = described_class.new(
          note: note,
          author: owner,
          content: 'Branch version',
          summary: 'Summary',
          parent_version_id: v1.id
        )

        version = service.call
        expect(version.parent_version_id).to eq(v1.id)
      end

      it 'validates parent belongs to same note' do
        other_note = create(:note)
        other_version = create(:version, note: other_note)

        service = described_class.new(
          note: note,
          author: owner,
          content: 'Content',
          summary: 'Summary',
          parent_version_id: other_version.id
        )

        expect { service.call }.to raise_error(
          Versions::Create::InvalidParentError,
          /Parent version must belong to the same note/
        )
      end

      it 'rejects non-existent parent_version_id' do
        service = described_class.new(
          note: note,
          author: owner,
          content: 'Content',
          summary: 'Summary',
          parent_version_id: 99999
        )

        expect { service.call }.to raise_error(
          Versions::Create::InvalidParentError
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
          content: 'Content',
          summary: 'Summary'
        )

        expect { service.call }.to raise_error(
          Versions::Create::UnauthorizedError,
          /does not have permission to create versions/
        )
      end

      it 'rejects completely unauthorized user' do
        service = described_class.new(
          note: note,
          author: unauthorized_user,
          content: 'Content',
          summary: 'Summary'
        )

        expect { service.call }.to raise_error(
          Versions::Create::UnauthorizedError
        )
      end
    end

    context 'transaction behavior' do
      it 'rolls back on failure' do
        service = described_class.new(
          note: note,
          author: owner,
          content: '', # Invalid - content required
          summary: 'Summary'
        )

        expect { service.call }.to raise_error(Versions::Create::Error)
        expect(note.reload.head_version_id).to be_nil
        expect(Version.count).to eq(0)
      end

      it 'ensures atomicity of version creation and head update' do
        allow_any_instance_of(Note).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new)

        service = described_class.new(
          note: note,
          author: owner,
          content: 'Content',
          summary: 'Summary'
        )

        expect { service.call }.to raise_error(Versions::Create::Error)
        expect(Version.where(note: note).count).to eq(0)
      end
    end

    context 'validation errors' do
      it 'wraps ActiveRecord::RecordInvalid errors' do
        service = described_class.new(
          note: note,
          author: owner,
          content: '', # Invalid
          summary: 'Summary'
        )

        expect { service.call }.to raise_error(
          Versions::Create::Error,
          /Failed to create version/
        )
      end
    end

    context 'edge cases' do
      it 'handles empty summary (uses default empty string)' do
        service = described_class.new(
          note: note,
          author: owner,
          content: 'Content'
        )

        version = service.call
        expect(version.summary).to eq('')
      end

      it 'creates version chain correctly' do
        v1 = create(:version, note: note)
        note.update_column(:head_version_id, v1.id)

        service2 = described_class.new(
          note: note,
          author: owner,
          content: 'V2',
          summary: 'Summary 2'
        )
        v2 = service2.call

        service3 = described_class.new(
          note: note,
          author: owner,
          content: 'V3',
          summary: 'Summary 3'
        )
        v3 = service3.call

        expect(v2.parent_version).to eq(v1)
        expect(v3.parent_version).to eq(v2)
        expect(note.reload.head_version).to eq(v3)
      end

      it 'allows long content' do
        long_content = 'x' * 100_000

        service = described_class.new(
          note: note,
          author: owner,
          content: long_content,
          summary: 'Summary'
        )

        version = service.call
        expect(version.content.length).to eq(100_000)
      end
    end
  end
end
