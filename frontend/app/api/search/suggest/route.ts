import { NextRequest, NextResponse } from "next/server";
import { apiFetch } from "@/lib/api/http";
import { suggestResponseSchema, type SuggestResponse } from "@/lib/api/schemas";

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const query = searchParams.get("q");

    if (!query) {
      return NextResponse.json({ suggestions: [] });
    }

    const top = searchParams.get("top") || "5";

    const params = new URLSearchParams({
      q: query,
      top,
    });

    const data = await apiFetch<SuggestResponse>(`/search/suggest?${params.toString()}`);
    const validated = suggestResponseSchema.parse(data);

    return NextResponse.json(validated);
  } catch (error: any) {
    console.error("Suggest API error:", error);
    return NextResponse.json(
      {
        error: {
          code: error.code || "suggest_error",
          message: error.message || "Failed to get suggestions",
        },
      },
      { status: error.status || 500 }
    );
  }
}
