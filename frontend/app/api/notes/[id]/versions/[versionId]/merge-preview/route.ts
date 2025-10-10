import { NextRequest, NextResponse } from "next/server";
import { getMergePreview } from "@/lib/api/notes.server";
import { isAuthenticated } from "@/lib/auth/session";

export async function POST(
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
    const localVersionId = parseInt(params.versionId, 10);

    const body = await request.json();
    const { base_version_id, head_version_id } = body;

    if (!base_version_id || !head_version_id) {
      return NextResponse.json(
        {
          error: {
            code: "validation_failed",
            message: "base_version_id and head_version_id are required"
          }
        },
        { status: 400 }
      );
    }

    const mergePreview = await getMergePreview(
      noteId,
      localVersionId,
      base_version_id,
      head_version_id
    );

    return NextResponse.json(mergePreview);
  } catch (error) {
    console.error("Merge preview error:", error);
    return NextResponse.json(
      {
        error: {
          code: "internal_error",
          message: error instanceof Error ? error.message : "Failed to get merge preview",
        },
      },
      { status: 500 }
    );
  }
}
