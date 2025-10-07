import { apiFetch, apiFetchPaginated } from "./http";
import {
  noteSchema,
  versionSchema,
  diffResponseSchema,
  mergePreviewResponseSchema,
  revertPreviewResponseSchema,
  type Note,
  type Version,
  type DiffResponse,
  type MergePreviewResponse,
  type RevertPreviewResponse,
} from "./schemas";
import { z } from "zod";

/**
 * Notes API functions
 */

export async function listNotes(page: number = 1, perPage: number = 25) {
  const response = await apiFetchPaginated<Note>("/notes", page, perPage);

  // Validate each note
  const validatedData = response.data.map((note) => noteSchema.parse(note));

  return {
    ...response,
    data: validatedData,
  };
}

export async function getNote(id: number): Promise<Note> {
  const data = await apiFetch<Note>(`/notes/${id}`);
  return noteSchema.parse(data);
}

export async function createNote(params: {
  title: string;
  visibility: "private" | "link" | "public";
}): Promise<Note> {
  const data = await apiFetch<Note>("/notes", {
    method: "POST",
    body: JSON.stringify({ note: params }),
  });
  return noteSchema.parse(data);
}

export async function updateNote(
  id: number,
  params: Partial<{ title: string; visibility: "private" | "link" | "public" }>
): Promise<Note> {
  const data = await apiFetch<Note>(`/notes/${id}`, {
    method: "PATCH",
    body: JSON.stringify({ note: params }),
  });
  return noteSchema.parse(data);
}

export async function deleteNote(id: number): Promise<void> {
  await apiFetch<void>(`/notes/${id}`, {
    method: "DELETE",
  });
}

/**
 * Versions API functions
 */

export async function listVersions(noteId: number, page: number = 1, perPage: number = 25) {
  const response = await apiFetchPaginated<Version>(
    `/notes/${noteId}/versions`,
    page,
    perPage
  );

  // Validate each version
  const validatedData = response.data.map((version) => versionSchema.parse(version));

  return {
    ...response,
    data: validatedData,
  };
}

export async function getVersion(noteId: number, versionId: number): Promise<Version> {
  const data = await apiFetch<Version>(`/notes/${noteId}/versions/${versionId}`);
  return versionSchema.parse(data);
}

export async function createVersion(
  noteId: number,
  params: {
    content: string;
    summary: string;
    base_version_id?: number;
  }
): Promise<Version> {
  const data = await apiFetch<Version>(`/notes/${noteId}/versions`, {
    method: "POST",
    body: JSON.stringify({ version: params }),
  });
  return versionSchema.parse(data);
}

export async function revertVersion(
  noteId: number,
  versionId: number,
  summary?: string
): Promise<Version> {
  const data = await apiFetch<Version>(`/notes/${noteId}/versions/${versionId}/revert`, {
    method: "POST",
    body: JSON.stringify({ summary }),
  });
  return versionSchema.parse(data);
}

/**
 * Diff & Merge API functions
 */

export interface DiffOptions {
  mode?: "line" | "word";
  context?: number;
}

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

  const data = await apiFetch<DiffResponse>(
    `/notes/${noteId}/versions/${versionId}/diff?${params.toString()}`
  );
  return diffResponseSchema.parse(data);
}

export async function getMergePreview(
  noteId: number,
  localVersionId: number,
  baseVersionId: number,
  headVersionId: number
): Promise<MergePreviewResponse> {
  const data = await apiFetch<MergePreviewResponse>(
    `/notes/${noteId}/versions/${localVersionId}/merge_preview`,
    {
      method: "POST",
      body: JSON.stringify({
        base_version_id: baseVersionId,
        head_version_id: headVersionId,
      }),
    }
  );
  return mergePreviewResponseSchema.parse(data);
}

export async function getRevertPreview(
  noteId: number,
  versionId: number
): Promise<RevertPreviewResponse> {
  const data = await apiFetch<RevertPreviewResponse>(
    `/notes/${noteId}/versions/${versionId}/revert_preview`
  );
  return revertPreviewResponseSchema.parse(data);
}
