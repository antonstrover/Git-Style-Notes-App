import { NextRequest, NextResponse } from "next/server";
import { apiFetch } from "@/lib/api/http";
import { searchResponseSchema, type SearchResponse } from "@/lib/api/schemas";

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const query = searchParams.get("q");

    if (!query) {
      return NextResponse.json(
        { error: { code: "missing_query", message: "Query parameter 'q' is required" } },
        { status: 400 }
      );
    }

    const top = searchParams.get("top") || "20";
    const skip = searchParams.get("skip") || "0";
    const noteId = searchParams.get("note_id");
    const captions = searchParams.get("captions") !== "false";

    const params = new URLSearchParams({
      q: query,
      top,
      skip,
      captions: captions.toString(),
    });

    if (noteId) {
      params.append("note_id", noteId);
    }

    const data = await apiFetch<SearchResponse>(`/search?${params.toString()}`);
    const validated = searchResponseSchema.parse(data);

    return NextResponse.json(validated);
  } catch (error: any) {
    console.error("Search API error:", error);
    return NextResponse.json(
      {
        error: {
          code: error.code || "search_error",
          message: error.message || "Failed to perform search",
        },
      },
      { status: error.status || 500 }
    );
  }
}
