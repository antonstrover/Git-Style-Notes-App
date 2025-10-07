import { apiFetch } from "./http";
import {
  searchResponseSchema,
  suggestResponseSchema,
  type SearchResponse,
  type SuggestResponse,
} from "./schemas";

/**
 * Search API functions
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

  const data = await apiFetch<SearchResponse>(`/search?${params.toString()}`);
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

  const data = await apiFetch<SuggestResponse>(`/search/suggest?${params.toString()}`);
  return suggestResponseSchema.parse(data);
}
