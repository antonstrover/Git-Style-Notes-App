import { NextRequest, NextResponse } from "next/server";
import { listVersions, createVersion } from "@/lib/api/notes.server";
import { isAuthenticated } from "@/lib/auth/session";
import { ApiError } from "@/lib/api/http";

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
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
    const searchParams = request.nextUrl.searchParams;
    const page = parseInt(searchParams.get("page") || "1", 10);
    const perPage = parseInt(searchParams.get("per_page") || "10", 10);

    const data = await listVersions(noteId, page, perPage);
    return NextResponse.json(data);
  } catch (error) {
    console.error("List versions error:", error);
    return NextResponse.json(
      {
        error: {
          code: "internal_error",
          message: error instanceof Error ? error.message : "Failed to fetch versions",
        },
      },
      { status: 500 }
    );
  }
}

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
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
    const body = await request.json();
    const { version } = body;

    if (!version || !version.content) {
      return NextResponse.json(
        { error: { code: "validation_failed", message: "Content is required" } },
        { status: 400 }
      );
    }

    const newVersion = await createVersion(noteId, {
      content: version.content,
      summary: version.summary || "",
      base_version_id: version.base_version_id,
    });

    return NextResponse.json(newVersion, { status: 201 });
  } catch (error) {
    console.error("Create version error:", error);

    if (error instanceof ApiError && error.code === "version_conflict") {
      return NextResponse.json(
        {
          error: {
            code: "version_conflict",
            message: error.message,
          },
        },
        { status: 409 }
      );
    }

    return NextResponse.json(
      {
        error: {
          code: "internal_error",
          message: error instanceof Error ? error.message : "Failed to create version",
        },
      },
      { status: 500 }
    );
  }
}
