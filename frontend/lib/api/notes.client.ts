import {
  noteSchema,
  diffResponseSchema,
  mergePreviewResponseSchema,
  type Note,
  type DiffResponse,
  type MergePreviewResponse,
} from "./schemas";

/**
 * Client-side Notes API functions
 * These call Next.js API routes which handle auth server-side
 * Use these in Client Components
 */

/**
 * Get a note by calling the Next.js API route
 */
export async function getNote(id: number): Promise<Note> {
  const response = await fetch(`/api/notes/${id}`);

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error?.message || "Failed to fetch note");
  }

  const data = await response.json();
  return noteSchema.parse(data);
}

/**
 * Diff Options
 */
export interface DiffOptions {
  mode?: "line" | "word";
  context?: number;
}

/**
 * Get a diff by calling the backend through the API route
 * Note: This currently needs an API route to be created
 */
export async function getDiff(
  noteId: number,
  versionId: number,
  compareToId: number,
  options?: DiffOptions
): Promise<DiffResponse> {
  const params = new URLSearchParams({
    compare_to: compareToId.toString(),
  });

  if (options?.mode) {
    params.append("mode", options.mode);
  }
  if (options?.context !== undefined) {
    params.append("context", options.context.toString());
  }

  const response = await fetch(
    `/api/notes/${noteId}/versions/${versionId}/diff?${params.toString()}`
  );

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error?.message || "Failed to get diff");
  }

  const data = await response.json();
  return diffResponseSchema.parse(data);
}

/**
 * Get a merge preview by calling the Next.js API route
 * Used by client components like conflict-dialog
 */
export async function getMergePreview(
  noteId: number,
  localVersionId: number,
  baseVersionId: number,
  headVersionId: number
): Promise<MergePreviewResponse> {
  const response = await fetch(
    `/api/notes/${noteId}/versions/${localVersionId}/merge-preview`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        base_version_id: baseVersionId,
        head_version_id: headVersionId,
      }),
    }
  );

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error?.message || "Failed to get merge preview");
  }

  const data = await response.json();
  return mergePreviewResponseSchema.parse(data);
}
