require 'rails_helper'

RSpec.describe Notes::Fork, type: :service do
  let(:source_owner) { create(:user) }
  let(:source_note) { create(:note, :with_head_version, owner: source_owner, title: 'Original Note') }
  let(:new_owner) { create(:user) }
  let(:unauthorized_user) { create(:user) }

  describe '#call' do
    context 'with valid params' do
      it 'creates a new forked note' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        expect { service.call }.to change { Note.count }.by(1)
      end

      it 'returns the forked note' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note).to be_a(Note)
        expect(forked_note).to be_persisted
      end

      it 'sets new_owner as owner of forked note' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note.owner).to eq(new_owner)
      end

      it 'copies title with (fork) suffix' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note.title).to eq('Original Note (fork)')
      end

      it 'copies content from source head version' do
        source_content = source_note.head_version.content
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note.head_version.content).to eq(source_content)
      end

      it 'sets visibility to private by default' do
        source_note.update_column(:visibility, 'public')
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note.visibility).to eq('private')
      end

      it 'creates initial version in target note' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        expect { service.call }.to change { Version.count }.by(1)
      end

      it 'sets initial version with nil parent (fresh start)' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note.head_version.parent_version_id).to be_nil
      end

      it 'updates forked note head_version_id' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note.head_version_id).to be_present
        expect(forked_note.head_version).to be_persisted
      end

      it 'creates Fork record with source → target mapping' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        expect { service.call }.to change { Fork.count }.by(1)
      end

      it 'links fork record correctly' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        fork_record = Fork.find_by(target_note: forked_note)

        expect(fork_record).to be_present
        expect(fork_record.source_note).to eq(source_note)
        expect(fork_record.target_note).to eq(forked_note)
      end

      it 'does NOT copy collaborators (privacy)' do
        create(:collaborator, note: source_note, user: create(:user))
        create(:collaborator, note: source_note, user: create(:user))

        service = described_class.new(source_note: source_note, new_owner: new_owner)
        forked_note = service.call

        expect(forked_note.collaborators.count).to eq(0)
      end

      it 'sets author of initial version to new_owner' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note.head_version.author).to eq(new_owner)
      end

      it 'sets version summary to indicate fork source' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note.head_version.summary).to eq("Forked from note #{source_note.id}")
      end

      it 'logs fork operation' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        allow(Rails.logger).to receive(:info)
        forked_note = service.call

        expect(Rails.logger).to have_received(:info).with(
          /Note forked: source_note_id=#{source_note.id}.*target_note_id=#{forked_note.id}/
        )
      end
    end

    context 'transaction behavior' do
      it 'uses transaction to ensure atomicity' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        expect(ActiveRecord::Base).to receive(:transaction).and_call_original
        service.call
      end

      it 'rolls back all changes on failure' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        # Simulate failure in fork record creation
        allow_any_instance_of(Fork).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)

        initial_note_count = Note.count
        initial_version_count = Version.count
        initial_fork_count = Fork.count

        expect { service.call }.to raise_error(Notes::Fork::Error)

        expect(Note.count).to eq(initial_note_count)
        expect(Version.count).to eq(initial_version_count)
        expect(Fork.count).to eq(initial_fork_count)
      end

      it 'ensures note, version, head_version_id, and fork are all created together' do
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = nil
        expect {
          forked_note = service.call
        }.to change { Note.count }.by(1)
          .and change { Version.count }.by(1)
          .and change { Fork.count }.by(1)

        expect(forked_note.head_version_id).to be_present
      end
    end

    context 'authorization' do
      it 'allows user with view permission (collaborator viewer)' do
        viewer = create(:user)
        create(:collaborator, :viewer, note: source_note, user: viewer)

        service = described_class.new(source_note: source_note, new_owner: viewer)

        expect { service.call }.not_to raise_error
      end

      it 'allows user with view permission (public note)' do
        source_note.update_column(:visibility, 'public')

        service = described_class.new(source_note: source_note, new_owner: new_owner)

        expect { service.call }.not_to raise_error
      end

      it 'allows user with view permission (link visibility)' do
        source_note.update_column(:visibility, 'link')

        service = described_class.new(source_note: source_note, new_owner: new_owner)

        expect { service.call }.not_to raise_error
      end

      it 'rejects user without view permission (private note)' do
        service = described_class.new(source_note: source_note, new_owner: unauthorized_user)

        expect { service.call }.to raise_error(
          Notes::Fork::UnauthorizedError,
          /does not have permission to view source note/
        )
      end
    end

    context 'edge cases' do
      it 'allows owner to fork their own note' do
        service = described_class.new(source_note: source_note, new_owner: source_owner)

        expect { service.call }.not_to raise_error
      end

      it 'creates distinct note even when owner forks own note' do
        service = described_class.new(source_note: source_note, new_owner: source_owner)

        forked_note = service.call
        expect(forked_note.id).not_to eq(source_note.id)
      end

      it 'handles long title correctly' do
        source_note.update_column(:title, 'a' * 200)
        service = described_class.new(source_note: source_note, new_owner: new_owner)

        forked_note = service.call
        expect(forked_note.title).to eq("#{'a' * 200} (fork)")
      end

      it 'can fork a note multiple times' do
        user1 = create(:user)
        user2 = create(:user)
        source_note.update_column(:visibility, 'public')

        service1 = described_class.new(source_note: source_note, new_owner: user1)
        service2 = described_class.new(source_note: source_note, new_owner: user2)

        fork1 = service1.call
        fork2 = service2.call

        expect(fork1.id).not_to eq(fork2.id)
        expect(Fork.where(source_note: source_note).count).to eq(2)
      end

      it 'can fork a forked note (chain)' do
        source_note.update_column(:visibility, 'public')

        first_fork = described_class.new(source_note: source_note, new_owner: new_owner).call
        first_fork.update_column(:visibility, 'public')

        second_owner = create(:user)
        second_fork = described_class.new(source_note: first_fork, new_owner: second_owner).call

        expect(second_fork).to be_persisted
        expect(Fork.where(source_note: first_fork).count).to eq(1)
      end
    end

    context 'error handling' do
      it 'wraps ActiveRecord::RecordInvalid errors' do
        allow_any_instance_of(Note).to receive(:save!).and_raise(
          ActiveRecord::RecordInvalid.new
        )

        service = described_class.new(source_note: source_note, new_owner: new_owner)

        expect { service.call }.to raise_error(
          Notes::Fork::Error,
          /Failed to fork note/
        )
      end

      it 'fails if source note has no head_version' do
        source_note.update_column(:head_version_id, nil)

        service = described_class.new(source_note: source_note, new_owner: new_owner)

        # This will raise NoMethodError on head_version.content
        expect { service.call }.to raise_error
      end
    end
  end
end
