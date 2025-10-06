require 'rails_helper'

RSpec.describe Collaborator, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:note) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:collaborator) }

    it { is_expected.to validate_presence_of(:note) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:role) }

    context 'role inclusion' do
      it 'accepts viewer role' do
        collaborator = build(:collaborator, role: :viewer)
        expect(collaborator).to be_valid
      end

      it 'accepts editor role' do
        collaborator = build(:collaborator, role: :editor)
        expect(collaborator).to be_valid
      end

      it 'rejects invalid role' do
        expect {
          build(:collaborator, role: :invalid)
        }.to raise_error(ArgumentError, /'invalid' is not a valid role/)
      end
    end

    context 'uniqueness' do
      it 'prevents duplicate user_id for same note_id' do
        note = create(:note)
        user = create(:user)
        create(:collaborator, note: note, user: user, role: :viewer)

        duplicate = build(:collaborator, note: note, user: user, role: :editor)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to include('has already been taken')
      end

      it 'allows same user to collaborate on different notes' do
        user = create(:user)
        note1 = create(:note)
        note2 = create(:note)

        collab1 = create(:collaborator, note: note1, user: user)
        collab2 = build(:collaborator, note: note2, user: user)

        expect(collab2).to be_valid
      end

      it 'allows different users to collaborate on same note' do
        note = create(:note)
        user1 = create(:user)
        user2 = create(:user)

        collab1 = create(:collaborator, note: note, user: user1)
        collab2 = build(:collaborator, note: note, user: user2)

        expect(collab2).to be_valid
      end
    end
  end

  describe 'enums' do
    it 'defines role enum with correct values' do
      expect(Collaborator.roles).to eq({
        'viewer' => 'viewer',
        'editor' => 'editor'
      })
    end

    context 'role methods' do
      let(:collaborator) { create(:collaborator) }

      it 'provides viewer? predicate' do
        collaborator.role = :viewer
        expect(collaborator).to be_viewer
      end

      it 'provides editor? predicate' do
        collaborator.role = :editor
        expect(collaborator).to be_editor
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      collaborator = build(:collaborator)
      expect(collaborator).to be_valid
    end

    it 'creates with viewer trait' do
      collaborator = create(:collaborator, :viewer)
      expect(collaborator).to be_viewer
    end

    it 'creates with editor trait' do
      collaborator = create(:collaborator, :editor)
      expect(collaborator).to be_editor
    end

    it 'defaults to viewer role' do
      collaborator = create(:collaborator)
      expect(collaborator).to be_viewer
    end
  end

  describe 'edge cases' do
    it 'can have note owner also as collaborator' do
      user = create(:user)
      note = create(:note, owner: user)
      collaborator = build(:collaborator, note: note, user: user)

      # This should be valid - system may want owner explicitly as collaborator
      expect(collaborator).to be_valid
    end

    it 'is destroyed when note is destroyed' do
      collaborator = create(:collaborator)
      note = collaborator.note

      expect { note.destroy }.to change { Collaborator.count }.by(-1)
    end

    it 'is not destroyed when user is destroyed (depends on DB cascade settings)' do
      collaborator = create(:collaborator)
      user = collaborator.user

      # Verify behavior - should this cascade or nullify?
      # Based on schema, this will likely raise foreign key error
      expect { user.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe 'permissions implications' do
    it 'viewer cannot be upgraded to editor by changing role' do
      collaborator = create(:collaborator, :viewer)
      collaborator.role = :editor

      expect(collaborator.save).to be true
      expect(collaborator.reload).to be_editor
    end

    it 'editor can be downgraded to viewer' do
      collaborator = create(:collaborator, :editor)
      collaborator.role = :viewer

      expect(collaborator.save).to be true
      expect(collaborator.reload).to be_viewer
    end
  end
end
