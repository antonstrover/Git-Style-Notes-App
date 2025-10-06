import { apiFetch, apiFetchPaginated } from "./http";
import { noteSchema, versionSchema, type Note, type Version } from "./schemas";
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
