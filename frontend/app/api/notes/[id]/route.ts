import { NextRequest, NextResponse } from "next/server";
import { getNote } from "@/lib/api/notes";
import { isAuthenticated } from "@/lib/auth/session";

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
    const id = parseInt(params.id, 10);

    const note = await getNote(id);
    return NextResponse.json(note);
  } catch (error) {
    console.error("Get note error:", error);
    return NextResponse.json(
      {
        error: {
          code: "internal_error",
          message: error instanceof Error ? error.message : "Failed to fetch note",
        },
      },
      { status: 500 }
    );
  }
}
