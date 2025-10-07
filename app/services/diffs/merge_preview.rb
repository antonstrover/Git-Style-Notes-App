# frozen_string_literal: true

module Diffs
  class MergePreview
    class Error < StandardError; end

    def initialize(base_content:, local_content:, head_content:, options: {})
      @base_content = base_content
      @local_content = local_content
      @head_content = head_content
      @options = options
    end

    def call
      # Fast paths
      return clean_result if base_content == head_content # No remote changes
      return clean_result if base_content == local_content # No local changes

      # Compute diffs from base to both sides
      base_to_local = compute_diff(base_content, local_content)
      base_to_head = compute_diff(base_content, head_content)

      # Analyze hunks for conflicts
      hunks = detect_conflicts(base_to_local[:hunks], base_to_head[:hunks])

      # Count clean vs conflicted
      clean_count = hunks.count { |h| h[:status] == :clean }
      conflict_count = hunks.count { |h| h[:status] == :conflict }

      {
        status: conflict_count > 0 ? :conflicted : :clean,
        hunks: hunks,
        summary: {
          total_hunks: hunks.size,
          clean_count: clean_count,
          conflict_count: conflict_count,
          local_stats: base_to_local[:stats],
          head_stats: base_to_head[:stats]
        }
      }
    end

    private

    attr_reader :base_content, :local_content, :head_content, :options

    def compute_diff(left, right)
      Diffs::Compute.new(
        left_content: left,
        right_content: right,
        options: options
      ).call
    end

    def clean_result
      {
        status: :clean,
        hunks: [],
        summary: {
          total_hunks: 0,
          clean_count: 0,
          conflict_count: 0,
          local_stats: { additions: 0, deletions: 0, modifications: 0, unchanged: 0 },
          head_stats: { additions: 0, deletions: 0, modifications: 0, unchanged: 0 }
        }
      }
    end

    def detect_conflicts(local_hunks, head_hunks)
      all_hunks = []

      # Track which hunks we've already processed
      processed_head_indices = Set.new

      local_hunks.each do |local_hunk|
        # Find overlapping head hunks
        overlapping_head_hunks = head_hunks.each_with_index.select do |head_hunk, index|
          !processed_head_indices.include?(index) && hunks_overlap?(local_hunk, head_hunk)
        end

        if overlapping_head_hunks.empty?
          # No conflict - local change only
          all_hunks << {
            status: :clean,
            type: :local_only,
            local_hunk: local_hunk,
            head_hunk: nil
          }
        else
          # Potential conflict - mark all overlapping regions
          overlapping_head_hunks.each do |head_hunk, index|
            processed_head_indices << index

            # Check if changes are identical
            if hunks_identical?(local_hunk, head_hunk)
              all_hunks << {
                status: :clean,
                type: :identical,
                local_hunk: local_hunk,
                head_hunk: head_hunk
              }
            else
              all_hunks << {
                status: :conflict,
                type: :overlapping,
                local_hunk: local_hunk,
                head_hunk: head_hunk,
                conflict_region: {
                  start: [local_hunk[:old_start], head_hunk[:old_start]].min,
                  end: [
                    local_hunk[:old_start] + local_hunk[:old_lines],
                    head_hunk[:old_start] + head_hunk[:old_lines]
                  ].max
                }
              }
            end
          end
        end
      end

      # Add head-only hunks (not overlapping with any local hunk)
      head_hunks.each_with_index do |head_hunk, index|
        next if processed_head_indices.include?(index)

        all_hunks << {
          status: :clean,
          type: :head_only,
          local_hunk: nil,
          head_hunk: head_hunk
        }
      end

      # Sort by position in the base document
      all_hunks.sort_by do |hunk|
        if hunk[:local_hunk]
          hunk[:local_hunk][:old_start]
        elsif hunk[:head_hunk]
          hunk[:head_hunk][:old_start]
        else
          Float::INFINITY
        end
      end
    end

    def hunks_overlap?(hunk1, hunk2)
      # Check if the hunks affect overlapping regions in the base content
      range1 = (hunk1[:old_start]...(hunk1[:old_start] + hunk1[:old_lines]))
      range2 = (hunk2[:old_start]...(hunk2[:old_start] + hunk2[:old_lines]))

      # Ranges overlap if one starts before the other ends
      range1.begin < range2.end && range2.begin < range1.end
    end

    def hunks_identical?(hunk1, hunk2)
      # Check if both hunks make the same changes
      return false if hunk1[:changes].size != hunk2[:changes].size

      hunk1[:changes].zip(hunk2[:changes]).all? do |change1, change2|
        change1[:type] == change2[:type] &&
          change1[:old_text] == change2[:old_text] &&
          change1[:new_text] == change2[:new_text]
      end
    end
  end
end
