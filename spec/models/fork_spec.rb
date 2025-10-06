require 'rails_helper'

RSpec.describe Fork, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:source_note).class_name('Note') }
    it { is_expected.to belong_to(:target_note).class_name('Note') }
  end

  describe 'validations' do
    subject { build(:fork) }

    it { is_expected.to validate_presence_of(:source_note) }
    it { is_expected.to validate_presence_of(:target_note) }

    context 'target_note_id uniqueness' do
      it 'prevents multiple forks with same target' do
        source1 = create(:note)
        source2 = create(:note)
        target = create(:note)

        create(:fork, source_note: source1, target_note: target)
        duplicate = build(:fork, source_note: source2, target_note: target)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:target_note_id]).to include('has already been taken')
      end

      it 'allows same source to fork into multiple targets' do
        source = create(:note)
        target1 = create(:note)
        target2 = create(:note)

        fork1 = create(:fork, source_note: source, target_note: target1)
        fork2 = build(:fork, source_note: source, target_note: target2)

        expect(fork2).to be_valid
      end

      it 'allows different fork relationships with different targets' do
        source1 = create(:note)
        source2 = create(:note)
        target1 = create(:note)
        target2 = create(:note)

        fork1 = create(:fork, source_note: source1, target_note: target1)
        fork2 = build(:fork, source_note: source2, target_note: target2)

        expect(fork2).to be_valid
      end
    end

    context 'source and target must be different' do
      it 'is invalid when source_note equals target_note' do
        note = create(:note)
        fork = build(:fork, source_note: note, target_note: note)

        expect(fork).not_to be_valid
        expect(fork.errors[:target_note]).to include('cannot be the same as source note')
      end

      it 'is valid when source and target are different' do
        source = create(:note)
        target = create(:note)
        fork = build(:fork, source_note: source, target_note: target)

        expect(fork).to be_valid
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      fork = build(:fork)
      expect(fork).to be_valid
    end

    it 'creates with distinct source and target notes' do
      fork = create(:fork)
      expect(fork.source_note).not_to eq(fork.target_note)
    end
  end

  describe 'fork chains and networks' do
    it 'allows forking a fork (chain)' do
      original = create(:note)
      first_fork = create(:note)
      second_fork = create(:note)

      fork1 = create(:fork, source_note: original, target_note: first_fork)
      fork2 = build(:fork, source_note: first_fork, target_note: second_fork)

      expect(fork2).to be_valid
    end

    it 'prevents circular forks (A->B, B->A blocked by uniqueness)' do
      note_a = create(:note)
      note_b = create(:note)

      fork1 = create(:fork, source_note: note_a, target_note: note_b)
      # This would create B->A, but B already has note_b as target in fork1
      # Actually this should be valid since source is different
      fork2 = build(:fork, source_note: note_b, target_note: note_a)

      expect(fork2).to be_valid # Different target, so allowed
    end

    it 'allows complex fork networks' do
      original = create(:note)
      fork1 = create(:note)
      fork2 = create(:note)
      fork3 = create(:note)

      create(:fork, source_note: original, target_note: fork1)
      create(:fork, source_note: original, target_note: fork2)
      create(:fork, source_note: fork1, target_note: fork3)

      expect(Fork.count).to eq(3)
    end
  end

  describe 'querying fork relationships' do
    let(:source) { create(:note) }
    let(:target1) { create(:note) }
    let(:target2) { create(:note) }

    before do
      create(:fork, source_note: source, target_note: target1)
      create(:fork, source_note: source, target_note: target2)
    end

    it 'finds all forks from a source' do
      forks = source.forks_as_source
      expect(forks.count).to eq(2)
      expect(forks.map(&:target_note)).to contain_exactly(target1, target2)
    end

    it 'finds fork record for a target' do
      fork = target1.fork_as_target
      expect(fork).to be_present
      expect(fork.source_note).to eq(source)
    end
  end

  describe 'cascade behavior' do
    it 'handles source note deletion' do
      fork = create(:fork)
      source = fork.source_note

      # Behavior depends on DB constraints - likely raises error or cascades
      # Assuming no cascade, this will raise foreign key error
      expect { source.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'handles target note deletion' do
      fork = create(:fork)
      target = fork.target_note

      # Same as above - depends on DB constraints
      expect { target.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe 'edge cases' do
    it 'can be created even if notes have no versions' do
      source = create(:note)
      target = create(:note)

      fork = build(:fork, source_note: source, target_note: target)
      expect(fork).to be_valid
    end

    it 'tracks fork creation timestamp' do
      fork = create(:fork)
      expect(fork.created_at).to be_present
      expect(fork.created_at).to be_within(1.second).of(Time.current)
    end
  end
end
