require 'rails_helper'

RSpec.describe Version, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:note) }
    it { is_expected.to belong_to(:author).class_name('User') }
    it { is_expected.to belong_to(:parent_version).class_name('Version').optional }
    it { is_expected.to have_many(:child_versions).class_name('Version').with_foreign_key(:parent_version_id) }
  end

  describe 'validations' do
    subject { build(:version) }

    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:summary) }
    it { is_expected.to validate_presence_of(:note) }
    it { is_expected.to validate_presence_of(:author) }
    it { is_expected.to validate_uniqueness_of(:version_number).scoped_to(:note_id) }

    context 'parent_version must belong to same note' do
      it 'is valid when parent_version belongs to same note' do
        note = create(:note, :with_head_version)
        parent = note.head_version
        child = build(:version, note: note, parent_version: parent)

        expect(child).to be_valid
      end

      it 'is invalid when parent_version belongs to different note' do
        note1 = create(:note, :with_head_version)
        note2 = create(:note)
        parent_from_different_note = note1.head_version

        child = build(:version, note: note2, parent_version: parent_from_different_note)

        expect(child).not_to be_valid
        expect(child.errors[:parent_version]).to include('must belong to the same note')
      end

      it 'is valid when parent_version is nil (first version)' do
        version = build(:version, parent_version: nil)
        expect(version).to be_valid
      end
    end

    describe 'content immutability (CRITICAL per CLAUDE.md)' do
      it 'allows creating a version with content' do
        version = build(:version, content: 'Initial content')
        expect(version.save).to be true
      end

      it 'prevents updating content after creation' do
        version = create(:version, content: 'Original content')
        version.content = 'Modified content'

        expect(version).not_to be_valid
        expect(version.errors[:content]).to include('cannot be changed after creation')
      end

      it 'prevents saving when content is changed' do
        version = create(:version, content: 'Original content')
        version.content = 'Modified content'

        expect(version.save).to be false
      end

      it 'allows updating other fields without changing content' do
        version = create(:version, content: 'Original content', summary: 'Old summary')
        version.summary = 'New summary'

        expect(version).to be_valid
        expect(version.save).to be true
        expect(version.reload.summary).to eq('New summary')
        expect(version.reload.content).to eq('Original content')
      end

      it 'raises error when trying to update! with changed content' do
        version = create(:version, content: 'Original content')
        version.content = 'Modified content'

        expect { version.save! }.to raise_error(ActiveRecord::RecordInvalid, /Content cannot be changed/)
      end

      it 'prevents update_attribute for content' do
        version = create(:version, content: 'Original content')

        # update_attribute bypasses validations but callbacks still run
        # Rails 7+ update_attribute respects readonly attributes if set
        expect {
          version.update_attribute(:content, 'New content')
        }.not_to change { version.reload.content }
      end
    end

    describe 'version_number auto-increment' do
      it 'automatically sets version_number to 1 for first version' do
        note = create(:note)
        version = create(:version, note: note)

        expect(version.version_number).to eq(1)
      end

      it 'auto-increments version_number for subsequent versions' do
        note = create(:note)
        v1 = create(:version, note: note)
        v2 = create(:version, note: note)
        v3 = create(:version, note: note)

        expect(v1.version_number).to eq(1)
        expect(v2.version_number).to eq(2)
        expect(v3.version_number).to eq(3)
      end

      it 'different notes have independent version numbering' do
        note1 = create(:note)
        note2 = create(:note)

        # Create versions for note1
        v1_n1 = create(:version, note: note1)
        v2_n1 = create(:version, note: note1)

        # Create versions for note2
        v1_n2 = create(:version, note: note2)
        v2_n2 = create(:version, note: note2)

        # Each note should have its own sequence
        expect(v1_n1.version_number).to eq(1)
        expect(v2_n1.version_number).to eq(2)
        expect(v1_n2.version_number).to eq(1)
        expect(v2_n2.version_number).to eq(2)
      end

      it 'version_number is immutable after creation' do
        version = create(:version)
        original_number = version.version_number
        version.version_number = 999

        expect(version).not_to be_valid
        expect(version.errors[:version_number]).to include('cannot be changed after creation')
      end

      it 'does not allow duplicate version_numbers within same note' do
        note = create(:note)
        v1 = create(:version, note: note)

        # Try to create another version with same version_number
        v2 = build(:version, note: note)
        v2.instance_variable_set(:@skip_set_version_number, true)
        v2.version_number = v1.version_number

        expect(v2).not_to be_valid
      end

      it 'allows same version_number across different notes' do
        note1 = create(:note)
        note2 = create(:note)

        v1 = create(:version, note: note1)
        v2 = create(:version, note: note2)

        expect(v1.version_number).to eq(v2.version_number)
        expect(v1.version_number).to eq(1)
      end
    end
  end

  describe 'version chain' do
    it 'can create a chain of versions' do
      note = create(:note)
      v1 = create(:version, note: note, content: 'Version 1')
      note.update_column(:head_version_id, v1.id)

      v2 = create(:version, note: note, parent_version: v1, content: 'Version 2')
      note.update_column(:head_version_id, v2.id)

      v3 = create(:version, note: note, parent_version: v2, content: 'Version 3')

      expect(v3.parent_version).to eq(v2)
      expect(v2.parent_version).to eq(v1)
      expect(v1.parent_version).to be_nil

      expect(v1.child_versions).to include(v2)
      expect(v2.child_versions).to include(v3)
    end
  end

  describe 'first version (bootstrap case)' do
    it 'can be created without parent_version' do
      note = create(:note)
      version = create(:version, note: note, parent_version: nil)

      expect(version).to be_persisted
      expect(version.parent_version).to be_nil
    end

    it 'is valid as first version of a note' do
      note = create(:note)
      version = build(:version, note: note, parent_version: nil)

      expect(version).to be_valid
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      version = build(:version)
      expect(version).to be_valid
    end

    it 'creates with_parent trait' do
      note = create(:note, :with_head_version)
      version = create(:version, :with_parent, note: note)

      expect(version.parent_version).to eq(note.head_version)
    end

    it 'generates realistic content with Faker' do
      version = create(:version)
      expect(version.content).to be_present
      expect(version.content.length).to be > 10
    end
  end

  describe 'edge cases' do
    it 'different authors can create versions for same note' do
      note = create(:note)
      author1 = create(:user)
      author2 = create(:user)

      v1 = create(:version, note: note, author: author1)
      v2 = create(:version, note: note, author: author2, parent_version: v1)

      expect(v1.author).to eq(author1)
      expect(v2.author).to eq(author2)
      expect(v1.note).to eq(v2.note)
    end

    it 'handles long content' do
      long_content = 'a' * 10_000
      version = create(:version, content: long_content)

      expect(version.content.length).to eq(10_000)
    end
  end
end
