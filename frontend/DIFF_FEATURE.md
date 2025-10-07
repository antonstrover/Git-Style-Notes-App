# Diff & Merge Preview Feature

Complete implementation of diff viewing and merge conflict detection for the versioned notes system.

## Overview

This feature provides comprehensive diff visualization and three-way merge conflict detection, allowing users to:
- Compare any two versions of a note side-by-side or inline
- See word-level changes for small modifications
- Detect and visualize merge conflicts before saving
- Make informed decisions when concurrent edits occur

## Components

### Core Diff Components

#### `components/diff/diff-viewer.tsx`
Main diff display component that orchestrates hunk rendering.
- Supports inline and side-by-side views
- Displays diff stats and hunk count
- Shows truncation warnings
- Optional merge preview overlay

#### `components/diff/diff-hunk.tsx`
Renders individual diff hunks with context lines.
- Collapsible context sections
- Line-by-line change highlighting
- Word-level token rendering for modifications
- Separate rendering for inline vs side-by-side modes

#### `components/diff/diff-stats.tsx`
Visual summary of changes (additions, deletions, modifications).
- Compact and full display modes
- Color-coded stats bars
- Singular/plural formatting

#### `components/diff/diff-toolbar.tsx`
Control panel for diff viewing options.
- View mode toggle (inline/side-by-side)
- Context lines selector (0, 1, 3, 5, 10)
- Hunk navigation (prev/next)
- Action buttons (revert, fork)

#### `components/diff/merge-conflict-overlay.tsx`
Displays three-way merge analysis with conflict highlighting.
- Tabs for conflicts/clean/all changes
- Side-by-side conflict comparison
- Clean/conflicted status indicators

### Integration Points

#### Dedicated Diff Page
**Route:** `/notes/[id]/diff?left=X&right=Y&view=inline|side`

Full-page diff viewer accessible from:
- Version history "Compare to Head" buttons
- Conflict dialog "View Diff" action
- Manual URL navigation

Features:
- Persistent view mode in URL
- Configurable context lines
- Navigation back to note editor

#### Conflict Dialog Enhancement
**Component:** `components/editor/conflict-dialog.tsx`

Enhanced to fetch and display merge preview on open:
- Shows conflict count and status
- Displays clean vs conflicted summary
- "View Diff" button navigates to diff page
- Supports refresh and fork actions

#### Version History Integration
**Location:** `app/notes/[id]/page.tsx` (History panel)

Each version item includes:
- "Compare to Head" icon button
- Opens diff page with version vs current head
- Hidden for head version itself

## API Integration

### Client Functions (`lib/api/notes.ts`)

```typescript
// Get diff between two versions
getDiff(noteId, versionId, compareToId, options?)
  - mode: 'line' | 'word'
  - context: number (0-10)

// Get three-way merge preview
getMergePreview(noteId, localVersionId, baseVersionId, headVersionId)

// Get revert preview (diff to head)
getRevertPreview(noteId, versionId)
```

### Schemas (`lib/api/schemas.ts`)

Complete Zod schemas for:
- `DiffResult` - Two-way diff output
- `DiffHunk` - Individual hunk structure
- `DiffChange` - Change types (add/delete/modify)
- `WordDiff` - Token-level changes
- `MergePreviewResult` - Three-way analysis
- `MergeHunk` - Conflict vs clean hunks

### Query Keys (`lib/api/keys.ts`)

TanStack Query keys for caching:
```typescript
queryKeys.diffs.diff(noteId, versionId, compareToId, options)
queryKeys.diffs.mergePreview(noteId, localVersionId, baseVersionId, headVersionId)
queryKeys.diffs.revertPreview(noteId, versionId)
```

## User Workflows

### Comparing Versions

1. User opens note editor
2. Views history panel (mobile tab or desktop sidebar)
3. Clicks compare icon on any non-head version
4. Diff page opens showing changes
5. User toggles view mode, adjusts context
6. Can navigate between hunks with toolbar

### Handling Conflicts

1. User attempts to save changes
2. Receives 409 conflict response
3. Conflict dialog opens automatically
4. Dialog fetches merge preview from API
5. Shows conflict count and clean changes
6. User can:
   - View Diff → opens detailed comparison
   - Refresh → discards local changes
   - Fork → creates new note with changes
   - Cancel → keeps editing

### Diff Display Modes

**Inline View:**
- Single column display
- +/- markers for additions/deletions
- ~ marker for modifications
- Context lines in muted color
- Word-level highlights within modified lines

**Side-by-Side View:**
- Two-column synchronized layout
- Left: old version
- Right: new version
- Empty rows for non-matching changes
- Line number alignment

## Configuration

### Diff Settings (Backend)
Configured in `config/initializers/diff.rb`:
- `max_content_size`: 10MB
- `max_hunks`: 1000
- `max_changes_per_hunk`: 500
- `word_threshold_lines`: 60
- `cache_ttl`: 60 seconds

### Frontend Options
- View mode: inline (default) or side-by-side
- Context lines: 0, 1, 3 (default), 5, 10
- Mode: line (default) or word (auto for small changes)

## Testing

### Unit Tests
- `test/unit/diff-viewer.test.tsx` - Main viewer component
- `test/unit/diff-stats.test.tsx` - Stats display

Tests cover:
- Empty state rendering
- Stats calculation and display
- Truncation warnings
- Mode badges
- Compact vs full display

### E2E Tests
- `test/e2e/diff.spec.ts` - Integration flows

Test scenarios:
- Navigate to diff from history
- Toggle view modes
- Conflict detection and resolution
- "View Diff" from conflict dialog

## Accessibility

- Semantic HTML with proper roles
- ARIA labels for interactive elements
- Keyboard navigation for hunk controls
- Screen reader announcements for stats
- Color contrast for change highlighting

## Performance

- React.memo for hunk components
- TanStack Query caching (60s TTL)
- Truncation for large diffs
- Lazy loading of hunks
- URL state management

## Future Enhancements

Potential improvements for future PRs:
- Virtualization for very large diffs
- Persistent view preferences
- Copy line/hunk actions
- Manual merge resolution UI
- Diff annotations/comments
- Export diff as patch file
- Search within diff

## Related Documentation

- Backend API: `/docs/api/diffs.md`
- Frontend Guide: `/frontend/IMPLEMENTATION_GUIDE.md`
- Main README: `/frontend/README.md`
