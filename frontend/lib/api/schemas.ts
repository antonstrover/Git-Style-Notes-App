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

// Type exports
export type User = z.infer<typeof userSchema>;
export type UserPartial = z.infer<typeof userPartialSchema>;
export type Version = z.infer<typeof versionSchema>;
export type Note = z.infer<typeof noteSchema>;
export type Collaborator = z.infer<typeof collaboratorSchema>;
export type ApiError = z.infer<typeof apiErrorSchema>;
