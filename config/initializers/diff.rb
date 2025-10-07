# frozen_string_literal: true

# Configuration for diff and merge services
Rails.application.config.diff_settings = {
  # Maximum content size in bytes (10MB default)
  max_content_size: 10.megabytes,

  # Maximum number of hunks to return (prevent huge responses)
  max_hunks: 1000,

  # Maximum number of changes per hunk
  max_changes_per_hunk: 500,

  # Word-level diff threshold (lines): if total changed lines <= this, use word-level
  word_threshold_lines: 60,

  # Default context lines for diffs
  default_context: 3,

  # Cache TTL for diff results (in seconds)
  cache_ttl: 60
}
