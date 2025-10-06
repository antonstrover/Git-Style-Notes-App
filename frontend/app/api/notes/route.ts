import { NextRequest, NextResponse } from "next/server";
import { listNotes, createNote } from "@/lib/api/notes";
import { isAuthenticated } from "@/lib/auth/session";

export async function GET(request: NextRequest) {
  try {
    const authenticated = await isAuthenticated();
    if (!authenticated) {
      return NextResponse.json(
        { error: { code: "unauthorized", message: "Not authenticated" } },
        { status: 401 }
      );
    }

    const searchParams = request.nextUrl.searchParams;
    const page = parseInt(searchParams.get("page") || "1", 10);
    const perPage = parseInt(searchParams.get("per_page") || "25", 10);

    const data = await listNotes(page, perPage);
    return NextResponse.json(data);
  } catch (error) {
    console.error("List notes error:", error);
    return NextResponse.json(
      {
        error: {
          code: "internal_error",
          message: error instanceof Error ? error.message : "Failed to fetch notes",
        },
      },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const authenticated = await isAuthenticated();
    if (!authenticated) {
      return NextResponse.json(
        { error: { code: "unauthorized", message: "Not authenticated" } },
        { status: 401 }
      );
    }

    const body = await request.json();
    const { note } = body;

    if (!note || !note.title || !note.visibility) {
      return NextResponse.json(
        { error: { code: "validation_failed", message: "Missing required fields" } },
        { status: 400 }
      );
    }

    const newNote = await createNote({
      title: note.title,
      visibility: note.visibility,
    });

    return NextResponse.json(newNote, { status: 201 });
  } catch (error) {
    console.error("Create note error:", error);
    return NextResponse.json(
      {
        error: {
          code: "internal_error",
          message: error instanceof Error ? error.message : "Failed to create note",
        },
      },
      { status: 500 }
    );
  }
}
