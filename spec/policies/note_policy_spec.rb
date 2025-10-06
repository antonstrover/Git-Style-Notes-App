require 'rails_helper'

RSpec.describe NotePolicy, type: :policy do
  subject { described_class }

  let(:owner) { create(:user) }
  let(:editor) { create(:user) }
  let(:viewer) { create(:user) }
  let(:other_user) { create(:user) }
  let(:note) { create(:note, owner: owner, visibility: :private) }

  before do
    create(:collaborator, :editor, note: note, user: editor)
    create(:collaborator, :viewer, note: note, user: viewer)
  end

  permissions :index? do
    it 'allows any authenticated user' do
      expect(subject).to permit(other_user, Note)
    end

    it 'allows owner' do
      expect(subject).to permit(owner, Note)
    end
  end

  permissions :show? do
    context 'private note' do
      it 'allows owner' do
        expect(subject).to permit(owner, note)
      end

      it 'allows editor collaborator' do
        expect(subject).to permit(editor, note)
      end

      it 'allows viewer collaborator' do
        expect(subject).to permit(viewer, note)
      end

      it 'denies other user' do
        expect(subject).not_to permit(other_user, note)
      end
    end

    context 'public note' do
      before { note.update_column(:visibility, 'public') }

      it 'allows anyone' do
        expect(subject).to permit(other_user, note)
      end
    end

    context 'link visibility note' do
      before { note.update_column(:visibility, 'link') }

      it 'allows anyone' do
        expect(subject).to permit(other_user, note)
      end
    end
  end

  permissions :create? do
    it 'allows any authenticated user' do
      expect(subject).to permit(other_user, Note)
    end
  end

  permissions :update? do
    it 'allows owner' do
      expect(subject).to permit(owner, note)
    end

    it 'denies editor' do
      expect(subject).not_to permit(editor, note)
    end

    it 'denies viewer' do
      expect(subject).not_to permit(viewer, note)
    end

    it 'denies other user' do
      expect(subject).not_to permit(other_user, note)
    end
  end

  permissions :destroy? do
    it 'allows owner' do
      expect(subject).to permit(owner, note)
    end

    it 'denies editor' do
      expect(subject).not_to permit(editor, note)
    end

    it 'denies viewer' do
      expect(subject).not_to permit(viewer, note)
    end

    it 'denies other user' do
      expect(subject).not_to permit(other_user, note)
    end
  end

  permissions :fork? do
    context 'private note' do
      it 'allows owner' do
        expect(subject).to permit(owner, note)
      end

      it 'allows editor' do
        expect(subject).to permit(editor, note)
      end

      it 'allows viewer' do
        expect(subject).to permit(viewer, note)
      end

      it 'denies other user' do
        expect(subject).not_to permit(other_user, note)
      end
    end

    context 'public note' do
      before { note.update_column(:visibility, 'public') }

      it 'allows anyone' do
        expect(subject).to permit(other_user, note)
      end
    end
  end

  permissions :manage_collaborators? do
    it 'allows owner' do
      expect(subject).to permit(owner, note)
    end

    it 'denies editor' do
      expect(subject).not_to permit(editor, note)
    end

    it 'denies viewer' do
      expect(subject).not_to permit(viewer, note)
    end

    it 'denies other user' do
      expect(subject).not_to permit(other_user, note)
    end
  end

  describe NotePolicy::Scope do
    let!(:owned_note) { create(:note, owner: owner, visibility: :private) }
    let!(:public_note) { create(:note, visibility: :public) }
    let!(:link_note) { create(:note, visibility: :link) }
    let!(:collab_note) { create(:note, visibility: :private) }
    let!(:other_note) { create(:note, visibility: :private) }

    before do
      create(:collaborator, note: collab_note, user: owner)
    end

    it 'includes owned notes' do
      scope = described_class.new(owner, Note.all).resolve
      expect(scope).to include(owned_note)
    end

    it 'includes public notes' do
      scope = described_class.new(owner, Note.all).resolve
      expect(scope).to include(public_note)
    end

    it 'includes link visibility notes' do
      scope = described_class.new(owner, Note.all).resolve
      expect(scope).to include(link_note)
    end

    it 'includes collaborated notes' do
      scope = described_class.new(owner, Note.all).resolve
      expect(scope).to include(collab_note)
    end

    it 'excludes private notes without access' do
      scope = described_class.new(owner, Note.all).resolve
      expect(scope).not_to include(other_note)
    end

    it 'returns distinct results' do
      # Add multiple collaborators to same note to test distinct
      create(:collaborator, note: collab_note, user: owner, role: :editor)

      scope = described_class.new(owner, Note.all).resolve
      expect(scope.pluck(:id).uniq.count).to eq(scope.count)
    end
  end
end
