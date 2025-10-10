import { NextRequest, NextResponse } from "next/server";
import { getDiff } from "@/lib/api/notes.server";
import { isAuthenticated } from "@/lib/auth/session";

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ id: string; versionId: string }> }
) {
  try {
    const authenticated = await isAuthenticated();
    if (!authenticated) {
      return NextResponse.json(
        { error: { code: "unauthorized", message: "Not authenticated" } },
        { status: 401 }
      );
    }

    const params = await context.params;
    const noteId = parseInt(params.id, 10);
    const versionId = parseInt(params.versionId, 10);

    const searchParams = request.nextUrl.searchParams;
    const compareToId = searchParams.get("compare_to");

    if (!compareToId) {
      return NextResponse.json(
        {
          error: {
            code: "validation_failed",
            message: "compare_to query parameter is required"
          }
        },
        { status: 400 }
      );
    }

    const mode = searchParams.get("mode") as "line" | "word" | null;
    const contextParam = searchParams.get("context");

    const options: { mode?: "line" | "word"; context?: number } = {};
    if (mode) options.mode = mode;
    if (contextParam) options.context = parseInt(contextParam, 10);

    const diff = await getDiff(
      noteId,
      versionId,
      parseInt(compareToId, 10),
      options
    );

    return NextResponse.json(diff);
  } catch (error) {
    console.error("Diff error:", error);
    return NextResponse.json(
      {
        error: {
          code: "internal_error",
          message: error instanceof Error ? error.message : "Failed to get diff",
        },
      },
      { status: 500 }
    );
  }
}
