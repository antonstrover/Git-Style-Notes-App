import { z } from "zod";

// User schema
export const userSchema = z.object({
  id: z.number(),
  email: z.string().email(),
  created_at: z.string(),
  updated_at: z.string(),
});

export const userPartialSchema = z.object({
  id: z.number(),
  email: z.string().email(),
});

// Version schema
export const versionSchema = z.object({
  id: z.number(),
  note_id: z.number(),
  author_id: z.number(),
  parent_version_id: z.number().nullable(),
  summary: z.string(),
  content: z.string(),
  created_at: z.string(),
  author: userPartialSchema.optional(),
});

// Note schema
export const noteSchema = z.object({
  id: z.number(),
  title: z.string(),
  owner_id: z.number(),
  head_version_id: z.number().nullable(),
  visibility: z.enum(["private", "link", "public"]),
  created_at: z.string(),
  updated_at: z.string(),
  owner: userPartialSchema.optional(),
  head_version: versionSchema.optional(),
});

// Collaborator schema
export const collaboratorSchema = z.object({
  id: z.number(),
  note_id: z.number(),
  user_id: z.number(),
  role: z.enum(["viewer", "editor"]),
  created_at: z.string(),
  updated_at: z.string(),
  user: userPartialSchema.optional(),
});

// API Error schema
export const apiErrorSchema = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    details: z.record(z.unknown()).optional(),
  }),
});

// Pagination metadata (inferred from X-Total-Count header + query params)
export function createPaginatedResponse<T extends z.ZodTypeAny>(itemSchema: T) {
  return z.object({
    data: z.array(itemSchema),
    total: z.number(),
    page: z.number(),
    per_page: z.number(),
  });
}

// Diff schemas
export const wordTokenSchema = z.object({
  type: z.enum(["unchanged", "added", "deleted"]),
  text: z.string(),
});

export const wordDiffSchema = z.object({
  old_tokens: z.array(wordTokenSchema),
  new_tokens: z.array(wordTokenSchema),
});

export const diffChangeSchema = z.object({
  type: z.enum(["add", "delete", "modify", "context"]),
  old_line: z.number().nullable().optional(),
  new_line: z.number().nullable().optional(),
  old_text: z.string().optional(),
  new_text: z.string().optional(),
  word_diff: wordDiffSchema.optional(),
});

export const contextLineSchema = z.object({
  old_line: z.number(),
  new_line: z.number(),
  text: z.string(),
});

export const diffHunkSchema = z.object({
  old_start: z.number(),
  old_lines: z.number(),
  new_start: z.number(),
  new_lines: z.number(),
  context_before: z.array(contextLineSchema),
  changes: z.array(diffChangeSchema),
  context_after: z.array(contextLineSchema),
  truncated: z.boolean().optional(),
});

export const diffStatsSchema = z.object({
  additions: z.number(),
  deletions: z.number(),
  modifications: z.number(),
  unchanged: z.number(),
});

export const diffResultSchema = z.object({
  hunks: z.array(diffHunkSchema),
  stats: diffStatsSchema,
  truncated: z.boolean(),
  mode: z.enum(["line", "word"]),
});

export const versionSummarySchema = z.object({
  id: z.number(),
  summary: z.string(),
});

export const diffResponseSchema = z.object({
  left_version: versionSummarySchema,
  right_version: versionSummarySchema,
  diff: diffResultSchema,
});

// Merge preview schemas
export const mergeHunkSchema = z.object({
  status: z.enum(["clean", "conflict"]),
  type: z.enum(["local_only", "head_only", "identical", "overlapping"]),
  local_hunk: diffHunkSchema.nullable(),
  head_hunk: diffHunkSchema.nullable(),
  conflict_region: z.object({
    start: z.number(),
    end: z.number(),
  }).optional(),
});

export const mergeSummarySchema = z.object({
  total_hunks: z.number(),
  clean_count: z.number(),
  conflict_count: z.number(),
  local_stats: diffStatsSchema,
  head_stats: diffStatsSchema,
});

export const mergePreviewResultSchema = z.object({
  status: z.enum(["clean", "conflicted"]),
  hunks: z.array(mergeHunkSchema),
  summary: mergeSummarySchema,
});

export const mergePreviewResponseSchema = z.object({
  local_version: versionSummarySchema,
  base_version: versionSummarySchema,
  head_version: versionSummarySchema,
  merge_preview: mergePreviewResultSchema,
});

export const revertPreviewResponseSchema = z.object({
  revert_from: versionSummarySchema,
  current_head: versionSummarySchema,
  diff: diffResultSchema,
});

// Search schemas
export const searchResultSchema = z.object({
  chunk_id: z.string(),
  note_id: z.number(),
  version_id: z.number(),
  title: z.string(),
  snippet: z.string(),
  score: z.number(),
  updated_at: z.string(),
});

export const searchResponseSchema = z.object({
  results: z.array(searchResultSchema),
  total_count: z.number().optional(),
  query: z.string(),
  top: z.number(),
  skip: z.number(),
});

export const suggestionSchema = z.object({
  text: z.string(),
  note_id: z.number(),
});

export const suggestResponseSchema = z.object({
  suggestions: z.array(suggestionSchema),
});

// Type exports
export type User = z.infer<typeof userSchema>;
export type UserPartial = z.infer<typeof userPartialSchema>;
export type Version = z.infer<typeof versionSchema>;
export type Note = z.infer<typeof noteSchema>;
export type Collaborator = z.infer<typeof collaboratorSchema>;
export type ApiError = z.infer<typeof apiErrorSchema>;

// Diff type exports
export type WordToken = z.infer<typeof wordTokenSchema>;
export type WordDiff = z.infer<typeof wordDiffSchema>;
export type DiffChange = z.infer<typeof diffChangeSchema>;
export type ContextLine = z.infer<typeof contextLineSchema>;
export type DiffHunk = z.infer<typeof diffHunkSchema>;
export type DiffStats = z.infer<typeof diffStatsSchema>;
export type DiffResult = z.infer<typeof diffResultSchema>;
export type VersionSummary = z.infer<typeof versionSummarySchema>;
export type DiffResponse = z.infer<typeof diffResponseSchema>;

// Merge preview type exports
export type MergeHunk = z.infer<typeof mergeHunkSchema>;
export type MergeSummary = z.infer<typeof mergeSummarySchema>;
export type MergePreviewResult = z.infer<typeof mergePreviewResultSchema>;
export type MergePreviewResponse = z.infer<typeof mergePreviewResponseSchema>;
export type RevertPreviewResponse = z.infer<typeof revertPreviewResponseSchema>;

// Search type exports
export type SearchResult = z.infer<typeof searchResultSchema>;
export type SearchResponse = z.infer<typeof searchResponseSchema>;
export type Suggestion = z.infer<typeof suggestionSchema>;
export type SuggestResponse = z.infer<typeof suggestResponseSchema>;
