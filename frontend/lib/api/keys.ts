/**
 * TanStack Query key factories
 * Ensures consistent cache key structure across the app
 */

export const queryKeys = {
  notes: {
    all: ["notes"] as const,
    lists: () => [...queryKeys.notes.all, "list"] as const,
    list: (page: number, perPage: number) =>
      [...queryKeys.notes.lists(), { page, perPage }] as const,
    details: () => [...queryKeys.notes.all, "detail"] as const,
    detail: (id: number) => [...queryKeys.notes.details(), id] as const,
  },
  versions: {
    all: (noteId: number) => ["versions", noteId] as const,
    lists: (noteId: number) => [...queryKeys.versions.all(noteId), "list"] as const,
    list: (noteId: number, page: number, perPage: number) =>
      [...queryKeys.versions.lists(noteId), { page, perPage }] as const,
    details: (noteId: number) => [...queryKeys.versions.all(noteId), "detail"] as const,
    detail: (noteId: number, id: number) =>
      [...queryKeys.versions.details(noteId), id] as const,
  },
  collaborators: {
    all: (noteId: number) => ["collaborators", noteId] as const,
    list: (noteId: number) => [...queryKeys.collaborators.all(noteId), "list"] as const,
  },
  diffs: {
    all: (noteId: number) => ["diffs", noteId] as const,
    diff: (noteId: number, versionId: number, compareToId: number, options?: { mode?: string; context?: number }) =>
      [...queryKeys.diffs.all(noteId), "diff", versionId, compareToId, options] as const,
    mergePreview: (noteId: number, localVersionId: number, baseVersionId: number, headVersionId: number) =>
      [...queryKeys.diffs.all(noteId), "merge-preview", localVersionId, baseVersionId, headVersionId] as const,
    revertPreview: (noteId: number, versionId: number) =>
      [...queryKeys.diffs.all(noteId), "revert-preview", versionId] as const,
  },
  search: {
    all: ["search"] as const,
    queries: () => [...queryKeys.search.all, "query"] as const,
    query: (q: string, top: number, skip: number, noteId?: number) =>
      [...queryKeys.search.queries(), { q, top, skip, noteId }] as const,
    suggests: () => [...queryKeys.search.all, "suggest"] as const,
    suggest: (q: string) =>
      [...queryKeys.search.suggests(), q] as const,
  },
};
