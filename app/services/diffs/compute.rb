# frozen_string_literal: true

require 'diff/lcs'
require 'nokogiri'

module Diffs
  class Compute
    class Error < StandardError; end
    class ContentTooLargeError < Error; end

    DEFAULT_OPTIONS = {
      mode: :line,              # :line or :word
      context: 3,               # number of context lines
      word_threshold_lines: 60, # use word-level if changed lines <= this
      extract_text_from_html: true # extract plain text from HTML for better diffs
    }.freeze

    def initialize(left_content:, right_content:, options: {})
      @left_content = left_content
      @right_content = right_content
      @options = DEFAULT_OPTIONS.merge(options)
      @config = Rails.application.config.diff_settings
    end

    def call
      validate_content_size!

      # Prepare content for diffing (extract text from HTML if needed)
      left_prepared = prepare_content_for_diff(left_content.to_s)
      right_prepared = prepare_content_for_diff(right_content.to_s)

      # Convert to arrays of lines
      left_lines = left_prepared.lines.map(&:chomp)
      right_lines = right_prepared.lines.map(&:chomp)

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
        when '!'
          # Check if this is a real modification or should be split into delete+add
          if should_split_modification?(change.old_element, change.new_element)
            stats[:deletions] += 1
            stats[:additions] += 1
          else
            stats[:modifications] += 1
          end
        end
      end

      stats
    end

    def should_split_modification?(old_text, new_text)
      return false if old_text.nil? || new_text.nil?

      # Calculate similarity ratio
      # If lines share very little in common, treat as separate delete+add
      similarity = calculate_similarity(old_text, new_text)
      similarity < 0.3 # Less than 30% similar = split into delete+add
    end

    def calculate_similarity(str1, str2)
      return 0.0 if str1.empty? && str2.empty?
      return 0.0 if str1.empty? || str2.empty?

      # Use Levenshtein-based similarity
      # Calculate the length of the longest common subsequence
      longer = [str1.length, str2.length].max
      distance = levenshtein_distance(str1, str2)

      (longer - distance).to_f / longer
    end

    def levenshtein_distance(str1, str2)
      n = str1.length
      m = str2.length
      return m if n == 0
      return n if m == 0

      # Use a 2-row approach to save memory
      prev_row = (0..m).to_a
      curr_row = Array.new(m + 1)

      (0...n).each do |i|
        curr_row[0] = i + 1
        (0...m).each do |j|
          cost = str1[i] == str2[j] ? 0 : 1
          curr_row[j + 1] = [
            curr_row[j] + 1,      # insertion
            prev_row[j + 1] + 1,  # deletion
            prev_row[j] + cost    # substitution
          ].min
        end
        prev_row, curr_row = curr_row, prev_row
      end

      prev_row[m]
    end

    def effective_mode(hunks)
      # Check if any hunk has word-level diff
      has_word_diff = hunks.any? { |h| h[:changes].any? { |c| c[:word_diff] } }
      has_word_diff ? :word : :line
    end

    def prepare_content_for_diff(content)
      return content unless options[:extract_text_from_html]
      return content unless html_content?(content)

      # Try to extract plain text from HTML
      extract_text_from_html(content)
    rescue => e
      Rails.logger.warn "Failed to extract text from HTML: #{e.message}, falling back to formatted HTML"
      # Fallback: pretty-print HTML for better line-by-line diffs
      format_html(content)
    end

    def html_content?(content)
      # Check if content contains HTML tags
      # Look for common HTML patterns
      content.match?(/<[a-z][\s\S]*>/i) &&
        (content.include?('<p>') || content.include?('<div>') ||
         content.include?('<h1>') || content.include?('<h2>') ||
         content.include?('<ul>') || content.include?('<ol>') ||
         content.include?('<br'))
    end

    def extract_text_from_html(html)
      doc = Nokogiri::HTML::DocumentFragment.parse(html)

      # Extract text while preserving structure
      extract_text_with_structure(doc.children)
    end

    def extract_text_with_structure(nodes, depth = 0, parent_is_list = false)
      result = []

      nodes.each do |node|
        case node.name
        when 'text'
          # Add text nodes, trimming excessive whitespace
          text = node.text.strip
          result << text unless text.empty?
        when 'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'
          # Block elements: add content on new lines
          inner_text = extract_text_with_structure(node.children, depth + 1, false)
          result << inner_text unless inner_text.empty?
          result << "" unless nodes.last == node # Add blank line after block
        when 'br'
          # Line breaks
          result << ""
        when 'ul', 'ol'
          # Lists: extract items - pass flag to treat children as list items
          list_items = extract_text_with_structure(node.children, depth + 1, true)
          result << list_items unless list_items.empty?
        when 'li'
          # List items: prefix with marker and treat as block-level
          marker = depth > 0 ? "  " * (depth - 1) + "- " : "- "
          inner_text = extract_text_with_structure(node.children, depth + 1, false)
          result << (marker + inner_text) unless inner_text.empty?
        when 'strong', 'b', 'em', 'i', 'code', 'span', 'a'
          # Inline elements: just extract text
          inner_text = extract_text_with_structure(node.children, depth, false)
          result << inner_text unless inner_text.empty?
        else
          # Other elements: recurse
          inner_text = extract_text_with_structure(node.children, depth, parent_is_list)
          result << inner_text unless inner_text.empty?
        end
      end

      # Join with appropriate separators
      if depth == 0 || parent_is_list
        # At root level or inside a list, use newlines to separate items
        result.join("\n").gsub(/\n{3,}/, "\n\n") # Remove excessive blank lines
      else
        # Inside inline or nested elements, use spaces
        result.join(" ")
      end
    end

    def format_html(html)
      # Pretty-print HTML to ensure proper line breaks
      doc = Nokogiri::HTML::DocumentFragment.parse(html)

      # Format with indentation and line breaks
      formatted = []
      format_node(doc, formatted, 0)
      formatted.join("\n")
    rescue => e
      Rails.logger.error "Failed to format HTML: #{e.message}"
      html # Return original if formatting fails
    end

    def format_node(node, output, indent_level)
      indent = "  " * indent_level

      node.children.each do |child|
        case child.type
        when Nokogiri::XML::Node::ELEMENT_NODE
          # Opening tag
          attrs = child.attributes.map { |k, v| "#{k}=\"#{v.value}\"" }.join(" ")
          tag = attrs.empty? ? "<#{child.name}>" : "<#{child.name} #{attrs}>"

          if child.children.empty?
            # Self-closing or empty element
            output << "#{indent}#{tag}</#{child.name}>"
          elsif child.children.size == 1 && child.children.first.text?
            # Single text child - keep on same line
            output << "#{indent}#{tag}#{child.children.first.text}</#{child.name}>"
          else
            # Multi-child - format with indentation
            output << "#{indent}#{tag}"
            format_node(child, output, indent_level + 1)
            output << "#{indent}</#{child.name}>"
          end
        when Nokogiri::XML::Node::TEXT_NODE
          text = child.text.strip
          output << "#{indent}#{text}" unless text.empty?
        end
      end
    end
  end
end
