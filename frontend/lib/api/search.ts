import {
  searchResponseSchema,
  suggestResponseSchema,
  type SearchResponse,
  type SuggestResponse,
} from "./schemas";

/**
 * Search API functions (client-side)
 * These call Next.js API routes which handle auth server-side
 */

export interface SearchOptions {
  query: string;
  top?: number;
  skip?: number;
  noteId?: number;
  captions?: boolean;
}

export async function searchNotes(options: SearchOptions): Promise<SearchResponse> {
  const {
    query,
    top = 20,
    skip = 0,
    noteId,
    captions = true,
  } = options;

  const params = new URLSearchParams({
    q: query,
    top: top.toString(),
    skip: skip.toString(),
    captions: captions.toString(),
  });

  if (noteId !== undefined) {
    params.append("note_id", noteId.toString());
  }

  // Call Next.js API route instead of backend directly
  const response = await fetch(`/api/search?${params.toString()}`);

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error?.message || "Search failed");
  }

  const data = await response.json();
  return searchResponseSchema.parse(data);
}

export interface SuggestOptions {
  query: string;
  top?: number;
}

export async function suggestNotes(options: SuggestOptions): Promise<SuggestResponse> {
  const { query, top = 5 } = options;

  const params = new URLSearchParams({
    q: query,
    top: top.toString(),
  });

  // Call Next.js API route instead of backend directly
  const response = await fetch(`/api/search/suggest?${params.toString()}`);

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error?.message || "Suggest failed");
  }

  const data = await response.json();
  return suggestResponseSchema.parse(data);
}
