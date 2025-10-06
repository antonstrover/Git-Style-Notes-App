require 'rails_helper'

RSpec.describe Note, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:owner).class_name('User') }
    it { is_expected.to have_many(:versions).dependent(:destroy) }
    it { is_expected.to belong_to(:head_version).class_name('Version').optional }
    it { is_expected.to have_many(:collaborators).dependent(:destroy) }
    it { is_expected.to have_many(:collaborating_users).through(:collaborators).source(:user) }
    it { is_expected.to have_one(:fork_as_target).class_name('Fork').with_foreign_key(:target_note_id) }
    it { is_expected.to have_many(:forks_as_source).class_name('Fork').with_foreign_key(:source_note_id) }
  end

  describe 'validations' do
    subject { build(:note) }

    it { is_expected.to validate_presence_of(:owner) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:visibility) }

    context 'visibility inclusion' do
      it 'accepts private visibility' do
        note = build(:note, visibility: :private)
        expect(note).to be_valid
      end

      it 'accepts link visibility' do
        note = build(:note, visibility: :link)
        expect(note).to be_valid
      end

      it 'accepts public visibility' do
        note = build(:note, visibility: :public)
        expect(note).to be_valid
      end

      it 'rejects invalid visibility' do
        expect {
          build(:note, visibility: :invalid)
        }.to raise_error(ArgumentError, /'invalid' is not a valid visibility/)
      end
    end
  end

  describe 'enums' do
    it 'defines visibility enum with correct values' do
      expect(Note.visibilities).to eq({
        'private' => 'private',
        'link' => 'link',
        'public' => 'public'
      })
    end

    context 'visibility methods' do
      let(:note) { create(:note) }

      it 'provides private? predicate' do
        note.visibility = :private
        expect(note).to be_private
      end

      it 'provides link? predicate' do
        note.visibility = :link
        expect(note).to be_link
      end

      it 'provides public? predicate' do
        note.visibility = :public
        expect(note).to be_public
      end
    end
  end

  describe 'cascading deletes' do
    it 'deletes associated versions when note is destroyed' do
      note = create(:note, :with_head_version)

      expect { note.destroy }.to change { Version.count }.by(-1)
    end

    it 'deletes associated collaborators when note is destroyed' do
      note = create(:note)
      create(:collaborator, note: note)

      expect { note.destroy }.to change { Collaborator.count }.by(-1)
    end
  end

  describe 'head_version relationship' do
    it 'allows note without head_version (bootstrap case)' do
      note = create(:note)
      expect(note.head_version).to be_nil
      expect(note).to be_valid
    end

    it 'can have a head_version' do
      note = create(:note, :with_head_version)
      expect(note.head_version).to be_present
      expect(note.head_version).to be_a(Version)
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      note = build(:note)
      expect(note).to be_valid
    end

    it 'creates with_head_version trait' do
      note = create(:note, :with_head_version)
      expect(note.head_version).to be_present
      expect(note.versions.count).to eq(1)
    end

    it 'creates public_note trait' do
      note = create(:note, :public_note)
      expect(note).to be_public
    end

    it 'creates link_visible trait' do
      note = create(:note, :link_visible)
      expect(note).to be_link
    end
  end
end
