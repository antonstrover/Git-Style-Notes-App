# frozen_string_literal: true

require 'diff/lcs'

module Diffs
  class Compute
    class Error < StandardError; end
    class ContentTooLargeError < Error; end

    DEFAULT_OPTIONS = {
      mode: :line,              # :line or :word
      context: 3,               # number of context lines
      word_threshold_lines: 60  # use word-level if changed lines <= this
    }.freeze

    def initialize(left_content:, right_content:, options: {})
      @left_content = left_content
      @right_content = right_content
      @options = DEFAULT_OPTIONS.merge(options)
      @config = Rails.application.config.diff_settings
    end

    def call
      validate_content_size!

      # Convert to arrays of lines
      left_lines = left_content.to_s.lines.map(&:chomp)
      right_lines = right_content.to_s.lines.map(&:chomp)

      # Compute line-based diff
      line_diff = Diff::LCS.sdiff(left_lines, right_lines)

      # Group into hunks with context
      hunks = group_into_hunks(line_diff, left_lines, right_lines)

      # Apply word-level diff if appropriate
      if should_use_word_level?(hunks)
        hunks = apply_word_level_diff(hunks)
      end

      # Truncate if necessary
      truncated = hunks.size > @config[:max_hunks]
      hunks = hunks.take(@config[:max_hunks]) if truncated

      {
        hunks: hunks,
        stats: compute_stats(line_diff),
        truncated: truncated,
        mode: effective_mode(hunks)
      }
    end

    private

    attr_reader :left_content, :right_content, :options, :config

    def validate_content_size!
      left_size = left_content.to_s.bytesize
      right_size = right_content.to_s.bytesize

      if left_size > config[:max_content_size] || right_size > config[:max_content_size]
        raise ContentTooLargeError, "Content exceeds maximum size of #{config[:max_content_size]} bytes"
      end
    end

    def group_into_hunks(line_diff, left_lines, right_lines)
      hunks = []
      current_hunk = nil
      context = options[:context]

      line_diff.each_with_index do |change, index|
        case change.action
        when '='
          # Context line - add to current hunk or start tracking for next hunk
          if current_hunk
            current_hunk[:context_after] ||= []
            current_hunk[:context_after] << {
              old_line: change.old_position + 1,
              new_line: change.new_position + 1,
              text: change.old_element
            }

            # Close hunk if we have enough trailing context
            if current_hunk[:context_after].size >= context
              # Keep only the requested context lines
              current_hunk[:context_after] = current_hunk[:context_after].take(context)
              hunks << finalize_hunk(current_hunk)
              current_hunk = nil
            end
          elsif upcoming_change?(line_diff, index, context)
            # Start collecting context before a change
            current_hunk = {
              context_before: [{
                old_line: change.old_position + 1,
                new_line: change.new_position + 1,
                text: change.old_element
              }],
              changes: [],
              context_after: []
            }
          end

        when '-', '+', '!'
          # Changed line - ensure we have a hunk
          unless current_hunk
            # Collect context before this change
            context_before = collect_context_before(line_diff, index, context, left_lines, right_lines)
            current_hunk = {
              context_before: context_before,
              changes: [],
              context_after: []
            }
          end

          # Reset context_after since we found another change
          current_hunk[:context_after] = []

          # Add the change
          current_hunk[:changes] << {
            type: change_type(change.action),
            old_line: change.old_position ? change.old_position + 1 : nil,
            new_line: change.new_position ? change.new_position + 1 : nil,
            old_text: change.old_element,
            new_text: change.new_element
          }
        end
      end

      # Finalize last hunk if exists
      hunks << finalize_hunk(current_hunk) if current_hunk

      hunks
    end

    def upcoming_change?(line_diff, index, context)
      # Look ahead to see if there's a change within context lines
      (index + 1).upto([index + context, line_diff.size - 1].min) do |i|
        return true if line_diff[i].action != '='
      end
      false
    end

    def collect_context_before(line_diff, index, context, left_lines, right_lines)
      context_lines = []
      start_index = [0, index - context].max

      start_index.upto(index - 1) do |i|
        change = line_diff[i]
        if change.action == '='
          context_lines << {
            old_line: change.old_position + 1,
            new_line: change.new_position + 1,
            text: change.old_element
          }
        end
      end

      # Keep only the last N context lines
      context_lines.last(context)
    end

    def finalize_hunk(hunk)
      # Truncate changes if necessary
      truncated = hunk[:changes].size > config[:max_changes_per_hunk]
      changes = truncated ? hunk[:changes].take(config[:max_changes_per_hunk]) : hunk[:changes]

      # Calculate positions
      first_change = hunk[:changes].first
      last_change = hunk[:changes].last

      old_start = if hunk[:context_before].any?
        hunk[:context_before].first[:old_line]
      else
        first_change[:old_line] || 0
      end

      new_start = if hunk[:context_before].any?
        hunk[:context_before].first[:new_line]
      else
        first_change[:new_line] || 0
      end

      old_lines = hunk[:context_before].size + hunk[:changes].count { |c| c[:old_text] } + hunk[:context_after].size
      new_lines = hunk[:context_before].size + hunk[:changes].count { |c| c[:new_text] } + hunk[:context_after].size

      {
        old_start: old_start,
        old_lines: old_lines,
        new_start: new_start,
        new_lines: new_lines,
        context_before: hunk[:context_before],
        changes: changes,
        context_after: hunk[:context_after],
        truncated: truncated
      }
    end

    def change_type(action)
      case action
      when '-' then :delete
      when '+' then :add
      when '!' then :modify
      else :context
      end
    end

    def should_use_word_level?(hunks)
      return false if options[:mode] == :line
      return true if options[:mode] == :word

      # Auto-detect: use word-level if total changed lines is small
      total_changed_lines = hunks.sum { |h| h[:changes].size }
      total_changed_lines <= options[:word_threshold_lines]
    end

    def apply_word_level_diff(hunks)
      hunks.map do |hunk|
        enhanced_changes = hunk[:changes].map do |change|
          if change[:type] == :modify && change[:old_text] && change[:new_text]
            # Compute word-level diff for modified lines
            change.merge(word_diff: compute_word_diff(change[:old_text], change[:new_text]))
          else
            change
          end
        end

        hunk.merge(changes: enhanced_changes)
      end
    end

    def compute_word_diff(old_text, new_text)
      old_words = tokenize(old_text)
      new_words = tokenize(new_text)

      word_changes = Diff::LCS.sdiff(old_words, new_words)

      {
        old_tokens: build_token_spans(word_changes, :old),
        new_tokens: build_token_spans(word_changes, :new)
      }
    end

    def tokenize(text)
      # Split on word boundaries while preserving spaces
      text.scan(/\S+|\s+/)
    end

    def build_token_spans(word_changes, side)
      spans = []
      current_text = []
      current_type = nil

      word_changes.each do |change|
        token = side == :old ? change.old_element : change.new_element
        type = case change.action
        when '=' then :unchanged
        when '-' then (side == :old ? :deleted : nil)
        when '+' then (side == :new ? :added : nil)
        when '!' then (side == :old ? :deleted : :added)
        end

        next if token.nil? || type.nil?

        if type != current_type && current_type
          # Flush current span
          spans << { type: current_type, text: current_text.join }
          current_text = []
        end

        current_type = type
        current_text << token
      end

      # Flush final span
      if current_text.any?
        spans << { type: current_type, text: current_text.join }
      end

      spans
    end

    def compute_stats(line_diff)
      stats = { additions: 0, deletions: 0, modifications: 0, unchanged: 0 }

      line_diff.each do |change|
        case change.action
        when '=' then stats[:unchanged] += 1
        when '-' then stats[:deletions] += 1
        when '+' then stats[:additions] += 1
        when '!' then stats[:modifications] += 1
        end
      end

      stats
    end

    def effective_mode(hunks)
      # Check if any hunk has word-level diff
      has_word_diff = hunks.any? { |h| h[:changes].any? { |c| c[:word_diff] } }
      has_word_diff ? :word : :line
    end
  end
end
