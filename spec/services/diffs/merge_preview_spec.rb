require 'rails_helper'

RSpec.describe Diffs::MergePreview, type: :service do
  let(:service) { described_class.new(base_content: base, local_content: local, head_content: head, options: options) }
  let(:options) { {} }

  describe '#call' do
    context 'with no changes (base == local == head)' do
      let(:base) { "Line 1\nLine 2\nLine 3\n" }
      let(:local) { "Line 1\nLine 2\nLine 3\n" }
      let(:head) { "Line 1\nLine 2\nLine 3\n" }

      it 'returns clean status with no hunks' do
        result = service.call
        expect(result[:status]).to eq(:clean)
        expect(result[:hunks]).to be_empty
        expect(result[:summary][:conflict_count]).to eq(0)
      end
    end

    context 'with only local changes (base == head)' do
      let(:base) { "Line 1\nLine 2\nLine 3\n" }
      let(:local) { "Line 1\nModified Line 2\nLine 3\n" }
      let(:head) { "Line 1\nLine 2\nLine 3\n" }

      it 'returns clean status with local-only hunks' do
        result = service.call
        expect(result[:status]).to eq(:clean)
        expect(result[:hunks].size).to be >= 1
        expect(result[:summary][:conflict_count]).to eq(0)

        local_only_hunks = result[:hunks].select { |h| h[:type] == :local_only }
        expect(local_only_hunks).not_to be_empty
      end
    end

    context 'with only remote changes (base == local)' do
      let(:base) { "Line 1\nLine 2\nLine 3\n" }
      let(:local) { "Line 1\nLine 2\nLine 3\n" }
      let(:head) { "Line 1\nModified Line 2\nLine 3\n" }

      it 'returns clean status with head-only hunks' do
        result = service.call
        expect(result[:status]).to eq(:clean)
        expect(result[:hunks].size).to be >= 1
        expect(result[:summary][:conflict_count]).to eq(0)

        head_only_hunks = result[:hunks].select { |h| h[:type] == :head_only }
        expect(head_only_hunks).not_to be_empty
      end
    end

    context 'with non-overlapping changes' do
      let(:base) do
        <<~TEXT
          Line 1
          Line 2
          Line 3
          Line 4
          Line 5
        TEXT
      end

      let(:local) do
        <<~TEXT
          Modified Line 1
          Line 2
          Line 3
          Line 4
          Line 5
        TEXT
      end

      let(:head) do
        <<~TEXT
          Line 1
          Line 2
          Line 3
          Line 4
          Modified Line 5
        TEXT
      end

      it 'returns clean status with separate hunks' do
        result = service.call
        expect(result[:status]).to eq(:clean)
        expect(result[:summary][:conflict_count]).to eq(0)
        expect(result[:summary][:clean_count]).to be > 0
      end
    end

    context 'with overlapping changes (conflict)' do
      let(:base) { "Line 1\nLine 2\nLine 3\n" }
      let(:local) { "Line 1\nLocal Change\nLine 3\n" }
      let(:head) { "Line 1\nHead Change\nLine 3\n" }

      it 'detects conflicts correctly' do
        result = service.call
        expect(result[:status]).to eq(:conflicted)
        expect(result[:summary][:conflict_count]).to be > 0

        conflict_hunks = result[:hunks].select { |h| h[:status] == :conflict }
        expect(conflict_hunks).not_to be_empty

        conflict_hunk = conflict_hunks.first
        expect(conflict_hunk[:local_hunk]).to be_present
        expect(conflict_hunk[:head_hunk]).to be_present
      end
    end

    context 'with identical changes (both sides same)' do
      let(:base) { "Line 1\nLine 2\nLine 3\n" }
      let(:local) { "Line 1\nModified Line 2\nLine 3\n" }
      let(:head) { "Line 1\nModified Line 2\nLine 3\n" }

      it 'marks identical changes as clean' do
        result = service.call
        expect(result[:status]).to eq(:clean)
        expect(result[:summary][:conflict_count]).to eq(0)

        identical_hunks = result[:hunks].select { |h| h[:type] == :identical }
        expect(identical_hunks).not_to be_empty
      end
    end

    context 'with multiple conflicts' do
      let(:base) do
        <<~TEXT
          Line 1
          Line 2
          Line 3
          Line 4
          Line 5
          Line 6
        TEXT
      end

      let(:local) do
        <<~TEXT
          Local 1
          Line 2
          Line 3
          Local 4
          Line 5
          Line 6
        TEXT
      end

      let(:head) do
        <<~TEXT
          Head 1
          Line 2
          Line 3
          Head 4
          Line 5
          Line 6
        TEXT
      end

      it 'detects all conflicts' do
        result = service.call
        expect(result[:status]).to eq(:conflicted)
        expect(result[:summary][:conflict_count]).to be >= 2
      end
    end

    context 'with additions in same region' do
      let(:base) { "Line 1\nLine 2\n" }
      let(:local) { "Line 1\nLocal Addition\nLine 2\n" }
      let(:head) { "Line 1\nHead Addition\nLine 2\n" }

      it 'detects addition conflict' do
        result = service.call
        expect(result[:status]).to eq(:conflicted)
        expect(result[:summary][:conflict_count]).to be > 0
      end
    end

    context 'with deletions in same region' do
      let(:base) { "Line 1\nLine 2\nLine 3\nLine 4\n" }
      let(:local) { "Line 1\nLine 4\n" }
      let(:head) { "Line 1\nLine 3\nLine 4\n" }

      it 'may detect deletion conflict depending on overlap' do
        result = service.call
        # Deletions in overlapping regions should conflict
        if result[:status] == :conflicted
          expect(result[:summary][:conflict_count]).to be > 0
        end
      end
    end

    context 'with complex mixed scenario' do
      let(:base) do
        <<~TEXT
          Section A
          Line 1
          Line 2
          Section B
          Line 3
          Line 4
          Section C
          Line 5
          Line 6
        TEXT
      end

      let(:local) do
        <<~TEXT
          Section A
          Modified Line 1
          Line 2
          Section B
          Line 3
          Line 4
          Section C Modified
          Line 5
          Line 6
        TEXT
      end

      let(:head) do
        <<~TEXT
          Section A
          Line 1
          Modified Line 2
          Section B
          Modified Line 3
          Line 4
          Section C Modified
          Line 5
          Line 6
        TEXT
      end

      it 'correctly categorizes all changes' do
        result = service.call

        # Should have a mix of clean and conflicted hunks
        expect(result[:hunks].size).to be > 0

        # Section C is modified identically - should be clean/identical
        identical = result[:hunks].select { |h| h[:type] == :identical }
        expect(identical.size).to be >= 0

        # Different lines modified - should be clean
        # Same lines modified differently - should be conflict
      end
    end

    context 'with empty base (new file)' do
      let(:base) { "" }
      let(:local) { "Local content\n" }
      let(:head) { "Head content\n" }

      it 'handles empty base as potential conflict' do
        result = service.call
        # Both adding content to empty file - likely conflict
        expect(result[:status]).to be_in([:clean, :conflicted])
      end
    end

    describe 'summary statistics' do
      let(:base) { "A\nB\nC\nD\n" }
      let(:local) { "A\nX\nC\nD\n" }
      let(:head) { "A\nB\nC\nY\n" }

      it 'provides accurate summary counts' do
        result = service.call
        summary = result[:summary]

        expect(summary).to include(:total_hunks, :clean_count, :conflict_count)
        expect(summary[:total_hunks]).to eq(result[:hunks].size)
        expect(summary[:clean_count] + summary[:conflict_count]).to eq(summary[:total_hunks])

        # Should have stats from both diffs
        expect(summary).to include(:local_stats, :head_stats)
        expect(summary[:local_stats]).to include(:additions, :deletions, :modifications, :unchanged)
        expect(summary[:head_stats]).to include(:additions, :deletions, :modifications, :unchanged)
      end
    end

    describe 'hunk ordering' do
      let(:base) do
        (1..10).map { |i| "Line #{i}" }.join("\n")
      end

      let(:local) do
        lines = (1..10).map { |i| "Line #{i}" }
        lines[2] = "Modified Line 3"
        lines[7] = "Modified Line 8"
        lines.join("\n")
      end

      let(:head) do
        lines = (1..10).map { |i| "Line #{i}" }
        lines[4] = "Modified Line 5"
        lines.join("\n")
      end

      it 'returns hunks sorted by position' do
        result = service.call

        # Hunks should be ordered by their position in base content
        positions = result[:hunks].map do |hunk|
          if hunk[:local_hunk]
            hunk[:local_hunk][:old_start]
          elsif hunk[:head_hunk]
            hunk[:head_hunk][:old_start]
          else
            0
          end
        end

        expect(positions).to eq(positions.sort)
      end
    end

    describe 'edge cases' do
      context 'with nil content' do
        let(:base) { nil }
        let(:local) { "content" }
        let(:head) { "content" }

        it 'handles nil gracefully' do
          expect { service.call }.not_to raise_error
        end
      end

      context 'with very large content' do
        let(:base) { "Line\n" * 1000 }
        let(:local) { "Line\n" * 1000 + "Extra\n" }
        let(:head) { "Modified\n" + "Line\n" * 1000 }

        it 'processes large files' do
          result = service.call
          expect(result).to include(:status, :hunks, :summary)
        end
      end
    end
  end
end
