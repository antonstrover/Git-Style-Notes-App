require 'rails_helper'

RSpec.describe VersionPolicy, type: :policy do
  subject { described_class }

  let(:owner) { create(:user) }
  let(:editor) { create(:user) }
  let(:viewer) { create(:user) }
  let(:other_user) { create(:user) }
  let(:note) { create(:note, owner: owner, visibility: :private) }
  let(:version) { create(:version, note: note, author: owner) }

  before do
    create(:collaborator, :editor, note: note, user: editor)
    create(:collaborator, :viewer, note: note, user: viewer)
  end

  permissions :index? do
    it 'delegates to note policy - allows owner' do
      expect(subject).to permit(owner, version)
    end

    it 'delegates to note policy - allows collaborator' do
      expect(subject).to permit(viewer, version)
    end

    it 'delegates to note policy - denies unauthorized' do
      expect(subject).not_to permit(other_user, version)
    end
  end

  permissions :show? do
    it 'delegates to note policy - allows owner' do
      expect(subject).to permit(owner, version)
    end

    it 'delegates to note policy - allows collaborator' do
      expect(subject).to permit(viewer, version)
    end

    it 'delegates to note policy - denies unauthorized' do
      expect(subject).not_to permit(other_user, version)
    end

    context 'public note' do
      before { note.update_column(:visibility, 'public') }

      it 'allows anyone' do
        expect(subject).to permit(other_user, version)
      end
    end
  end

  permissions :create? do
    it 'allows owner' do
      expect(subject).to permit(owner, version)
    end

    it 'allows editor' do
      expect(subject).to permit(editor, version)
    end

    it 'denies viewer' do
      expect(subject).not_to permit(viewer, version)
    end

    it 'denies unauthorized user' do
      expect(subject).not_to permit(other_user, version)
    end
  end

  permissions :revert? do
    it 'has same permissions as create - allows owner' do
      expect(subject).to permit(owner, version)
    end

    it 'has same permissions as create - allows editor' do
      expect(subject).to permit(editor, version)
    end

    it 'has same permissions as create - denies viewer' do
      expect(subject).not_to permit(viewer, version)
    end

    it 'has same permissions as create - denies unauthorized' do
      expect(subject).not_to permit(other_user, version)
    end
  end

  describe VersionPolicy::Scope do
    let!(:owned_note) { create(:note, owner: owner) }
    let!(:other_note) { create(:note) }
    let!(:public_note) { create(:note, visibility: :public) }

    let!(:owned_version) { create(:version, note: owned_note) }
    let!(:other_version) { create(:version, note: other_note) }
    let!(:public_version) { create(:version, note: public_note) }

    it 'includes versions from accessible notes' do
      scope = described_class.new(owner, Version.all).resolve

      expect(scope).to include(owned_version)
      expect(scope).to include(public_version)
    end

    it 'excludes versions from inaccessible notes' do
      scope = described_class.new(owner, Version.all).resolve

      expect(scope).not_to include(other_version)
    end
  end
end
