require 'rails_helper'

RSpec.describe ForkPolicy, type: :policy do
  subject { described_class }

  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:source_note) { create(:note, owner: owner, visibility: :private) }
  let(:target_note) { create(:note, owner: other_user) }
  let(:fork_record) { create(:fork, source_note: source_note, target_note: target_note) }

  permissions :create? do
    it 'allows if user can view source note (owner)' do
      # For create, the record is the source note (not Fork record)
      expect(subject).to permit(owner, source_note)
    end

    it 'allows if user can view source note (public)' do
      source_note.update_column(:visibility, 'public')
      expect(subject).to permit(other_user, source_note)
    end

    it 'denies if user cannot view source note' do
      expect(subject).not_to permit(other_user, source_note)
    end
  end

  permissions :show? do
    it 'allows if user can see source note' do
      expect(subject).to permit(owner, fork_record)
    end

    it 'allows if user can see target note' do
      expect(subject).to permit(other_user, fork_record)
    end

    it 'denies if user can see neither note' do
      unrelated_user = create(:user)
      expect(subject).not_to permit(unrelated_user, fork_record)
    end

    it 'allows if user can see both notes' do
      source_note.update_column(:visibility, 'public')
      target_note.update_column(:visibility, 'public')

      anyone = create(:user)
      expect(subject).to permit(anyone, fork_record)
    end
  end

  describe ForkPolicy::Scope do
    let!(:my_source_fork) { create(:fork, source_note: source_note) }
    let!(:my_target_fork) { create(:fork, target_note: target_note) }
    let!(:other_fork) { create(:fork) }

    it 'includes forks where user owns source' do
      scope = described_class.new(owner, Fork.all).resolve

      expect(scope).to include(my_source_fork)
    end

    it 'includes forks where user owns target' do
      scope = described_class.new(other_user, Fork.all).resolve

      expect(scope).to include(my_target_fork)
    end

    it 'excludes forks where user has no access' do
      scope = described_class.new(owner, Fork.all).resolve

      expect(scope).not_to include(other_fork)
    end
  end
end
