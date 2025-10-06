require 'rails_helper'

RSpec.describe CollaboratorPolicy, type: :policy do
  subject { described_class }

  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:note) { create(:note, owner: owner) }
  let(:collaborator) { create(:collaborator, note: note, user: other_user) }

  permissions :index? do
    it 'allows if user can view note (owner)' do
      expect(subject).to permit(owner, collaborator)
    end

    it 'allows if user can view note (collaborator)' do
      expect(subject).to permit(other_user, collaborator)
    end

    it 'denies if user cannot view note' do
      unrelated_user = create(:user)
      expect(subject).not_to permit(unrelated_user, collaborator)
    end
  end

  permissions :show? do
    it 'allows if user can view note (owner)' do
      expect(subject).to permit(owner, collaborator)
    end

    it 'allows if user can view note (collaborator)' do
      expect(subject).to permit(other_user, collaborator)
    end

    it 'denies if user cannot view note' do
      unrelated_user = create(:user)
      expect(subject).not_to permit(unrelated_user, collaborator)
    end
  end

  permissions :create? do
    it 'allows owner' do
      new_collab = build(:collaborator, note: note)
      expect(subject).to permit(owner, new_collab)
    end

    it 'denies non-owner' do
      new_collab = build(:collaborator, note: note)
      expect(subject).not_to permit(other_user, new_collab)
    end
  end

  permissions :destroy? do
    it 'allows owner' do
      expect(subject).to permit(owner, collaborator)
    end

    it 'denies non-owner' do
      expect(subject).not_to permit(other_user, collaborator)
    end
  end

  describe CollaboratorPolicy::Scope do
    let!(:owned_note) { create(:note, owner: owner) }
    let!(:other_note) { create(:note) }
    let!(:owned_collab) { create(:collaborator, note: owned_note) }
    let!(:other_collab) { create(:collaborator, note: other_note) }

    it 'includes collaborators from accessible notes' do
      scope = described_class.new(owner, Collaborator.all).resolve

      expect(scope).to include(owned_collab)
    end

    it 'excludes collaborators from inaccessible notes' do
      scope = described_class.new(owner, Collaborator.all).resolve

      expect(scope).not_to include(other_collab)
    end
  end
end
