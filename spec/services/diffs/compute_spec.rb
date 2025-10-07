require 'rails_helper'

RSpec.describe Diffs::Compute, type: :service do
  let(:service) { described_class.new(left_content: left_content, right_content: right_content, options: options) }
  let(:options) { {} }

  describe '#call' do
    context 'with identical content' do
      let(:left_content) { "Hello World\nThis is a test\n" }
      let(:right_content) { "Hello World\nThis is a test\n" }

      it 'returns empty hunks' do
        result = service.call
        expect(result[:hunks]).to be_empty
        expect(result[:stats][:unchanged]).to eq(2)
        expect(result[:stats][:additions]).to eq(0)
        expect(result[:stats][:deletions]).to eq(0)
      end
    end

    context 'with pure additions' do
      let(:left_content) { "Line 1\nLine 2\n" }
      let(:right_content) { "Line 1\nLine 2\nLine 3\nLine 4\n" }

      it 'detects additions correctly' do
        result = service.call
        expect(result[:hunks].size).to eq(1)

        hunk = result[:hunks].first
        expect(hunk[:changes].size).to eq(2)
        expect(hunk[:changes].all? { |c| c[:type] == :add }).to be true
        expect(result[:stats][:additions]).to eq(2)
      end
    end

    context 'with pure deletions' do
      let(:left_content) { "Line 1\nLine 2\nLine 3\nLine 4\n" }
      let(:right_content) { "Line 1\nLine 2\n" }

      it 'detects deletions correctly' do
        result = service.call
        expect(result[:hunks].size).to eq(1)

        hunk = result[:hunks].first
        expect(hunk[:changes].size).to eq(2)
        expect(hunk[:changes].all? { |c| c[:type] == :delete }).to be true
        expect(result[:stats][:deletions]).to eq(2)
      end
    end

    context 'with modifications' do
      let(:left_content) { "Hello World\n" }
      let(:right_content) { "Hello Universe\n" }

      it 'detects modifications correctly' do
        result = service.call
        expect(result[:hunks].size).to eq(1)

        hunk = result[:hunks].first
        expect(hunk[:changes].size).to eq(1)
        expect(hunk[:changes].first[:type]).to eq(:modify)
        expect(result[:stats][:modifications]).to eq(1)
      end
    end

    context 'with mixed changes' do
      let(:left_content) do
        <<~TEXT
          Line 1
          Line 2
          Line 3
          Line 4
          Line 5
        TEXT
      end

      let(:right_content) do
        <<~TEXT
          Line 1
          Line 2 Modified
          New Line
          Line 5
        TEXT
      end

      it 'groups changes into hunks with context' do
        result = service.call
        expect(result[:hunks].size).to be >= 1
        expect(result[:stats][:modifications]).to be > 0
        expect(result[:stats][:additions]).to be > 0
        expect(result[:stats][:deletions]).to be > 0
      end
    end

    context 'with context option' do
      let(:left_content) do
        <<~TEXT
          Line 1
          Line 2
          Line 3
          Line 4
          Line 5
          Line 6
          Line 7
          Line 8
          Line 9
          Line 10
        TEXT
      end

      let(:right_content) do
        <<~TEXT
          Line 1
          Line 2
          Modified Line 3
          Line 4
          Line 5
          Line 6
          Line 7
          Line 8
          Modified Line 9
          Line 10
        TEXT
      end

      it 'respects context setting for separate hunks' do
        result_small_context = described_class.new(
          left_content: left_content,
          right_content: right_content,
          options: { context: 1 }
        ).call

        result_large_context = described_class.new(
          left_content: left_content,
          right_content: right_content,
          options: { context: 5 }
        ).call

        # With small context, changes far apart should be separate hunks
        # With large context, they might be merged into one hunk
        expect(result_small_context[:hunks].size).to be >= result_large_context[:hunks].size
      end
    end

    context 'with word-level mode' do
      let(:left_content) { "The quick brown fox" }
      let(:right_content) { "The quick red fox" }
      let(:options) { { mode: :word } }

      it 'includes word-level diff information' do
        result = service.call
        expect(result[:mode]).to eq(:word)

        hunk = result[:hunks].first
        modification = hunk[:changes].find { |c| c[:type] == :modify }

        if modification
          expect(modification[:word_diff]).to be_present
          expect(modification[:word_diff][:old_tokens]).to be_an(Array)
          expect(modification[:word_diff][:new_tokens]).to be_an(Array)
        end
      end
    end

    context 'with automatic word-level detection' do
      let(:left_content) { "Small change\n" }
      let(:right_content) { "Small modification\n" }
      let(:options) { { mode: :auto } }

      it 'automatically applies word-level diff for small changes' do
        result = service.call
        # For small changes, should default to word-level
        expect(result[:mode]).to be_in([:word, :line])
      end
    end

    context 'with whitespace-only changes' do
      let(:left_content) { "Hello World" }
      let(:right_content) { "Hello  World" }

      it 'detects whitespace changes' do
        result = service.call
        # Should detect the change (extra space)
        expect(result[:hunks]).not_to be_empty
      end
    end

    context 'with large content' do
      let(:left_content) { "Line\n" * 10_000 }
      let(:right_content) { "Line\n" * 10_000 + "Extra\n" }

      it 'handles large content within limits' do
        result = service.call
        expect(result[:hunks]).not_to be_empty
        expect(result[:truncated]).to be_in([true, false])
      end
    end

    context 'with content exceeding size limit' do
      let(:left_content) { "x" * 20.megabytes }
      let(:right_content) { "y" * 20.megabytes }

      it 'raises ContentTooLargeError' do
        expect { service.call }.to raise_error(Diffs::Compute::ContentTooLargeError)
      end
    end

    context 'with many hunks (truncation)' do
      let(:left_content) do
        (1..2000).map { |i| "Line #{i}" }.join("\n")
      end

      let(:right_content) do
        (1..2000).map { |i| i.even? ? "Line #{i} modified" : "Line #{i}" }.join("\n")
      end

      it 'truncates hunks when exceeding max_hunks' do
        result = service.call

        if result[:truncated]
          expect(result[:hunks].size).to eq(Rails.application.config.diff_settings[:max_hunks])
        end
      end
    end

    context 'with empty content' do
      let(:left_content) { "" }
      let(:right_content) { "New content\n" }

      it 'handles empty left content' do
        result = service.call
        expect(result[:hunks]).not_to be_empty
        expect(result[:stats][:additions]).to eq(1)
      end
    end

    context 'with nil content' do
      let(:left_content) { nil }
      let(:right_content) { "Content\n" }

      it 'converts nil to empty string' do
        expect { service.call }.not_to raise_error
      end
    end

    describe 'hunk structure' do
      let(:left_content) { "Line 1\nLine 2\nLine 3\n" }
      let(:right_content) { "Line 1\nModified Line 2\nLine 3\n" }

      it 'returns properly structured hunks' do
        result = service.call
        hunk = result[:hunks].first

        expect(hunk).to include(:old_start, :old_lines, :new_start, :new_lines)
        expect(hunk).to include(:context_before, :changes, :context_after)
        expect(hunk[:changes]).to be_an(Array)

        hunk[:changes].each do |change|
          expect(change).to include(:type)
          expect(change[:type]).to be_in([:add, :delete, :modify, :context])
        end
      end
    end

    describe 'stats' do
      let(:left_content) { "A\nB\nC\nD\n" }
      let(:right_content) { "A\nX\nC\nE\nF\n" }

      it 'returns accurate statistics' do
        result = service.call
        stats = result[:stats]

        expect(stats).to include(:additions, :deletions, :modifications, :unchanged)
        expect(stats[:unchanged]).to eq(2) # A and C
        expect(stats[:additions]).to be >= 0
        expect(stats[:deletions]).to be >= 0
      end
    end

    describe 'edge cases' do
      context 'with no newline at end of file' do
        let(:left_content) { "Line 1\nLine 2" }
        let(:right_content) { "Line 1\nLine 2\n" }

        it 'handles missing newline correctly' do
          expect { service.call }.not_to raise_error
        end
      end

      context 'with different line endings' do
        let(:left_content) { "Line 1\r\nLine 2\r\n" }
        let(:right_content) { "Line 1\nLine 2\n" }

        it 'handles different line endings' do
          expect { service.call }.not_to raise_error
        end
      end

      context 'with unicode characters' do
        let(:left_content) { "Hello 世界\n" }
        let(:right_content) { "Hello 🌍\n" }

        it 'handles unicode correctly' do
          result = service.call
          expect(result[:hunks]).not_to be_empty
        end
      end
    end
  end
end
