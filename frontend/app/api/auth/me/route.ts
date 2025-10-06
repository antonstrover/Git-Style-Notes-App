import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth/session";

export async function GET() {
  try {
    const session = await getSession();

    if (!session) {
      return NextResponse.json(
        {
          error: {
            code: "unauthorized",
            message: "Not authenticated",
          },
        },
        { status: 401 }
      );
    }

    // Optionally validate the session with Rails backend
    const backendUrl = process.env.BACKEND_BASE_URL || "http://localhost:3000/api/v1";

    const response = await fetch(`${backendUrl}/notes?page=1&per_page=1`, {
      headers: {
        Authorization: `Basic ${session.token}`,
      },
    });

    if (!response.ok) {
      // Session is invalid
      const { destroySession } = await import("@/lib/auth/session");
      await destroySession();

      return NextResponse.json(
        {
          error: {
            code: "unauthorized",
            message: "Session expired or invalid",
          },
        },
        { status: 401 }
      );
    }

    return NextResponse.json({
      authenticated: true,
      email: session.email,
    });
  } catch (error) {
    console.error("Auth check error:", error);
    return NextResponse.json(
      {
        error: {
          code: "internal_error",
          message: "Failed to check authentication",
        },
      },
      { status: 500 }
    );
  }
}
