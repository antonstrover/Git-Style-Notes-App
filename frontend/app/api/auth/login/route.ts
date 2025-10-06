import { NextRequest, NextResponse } from "next/server";
import { createSession } from "@/lib/auth/session";
import { z } from "zod";

const loginSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(1, "Password is required"),
});

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const parsed = loginSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json(
        {
          error: {
            code: "validation_failed",
            message: "Invalid input",
            details: parsed.error.flatten().fieldErrors,
          },
        },
        { status: 400 }
      );
    }

    const { email, password } = parsed.data;

    // Create session by storing credentials in HttpOnly cookie
    await createSession(email, password);

    // Validate credentials against Rails backend by making a test request
    const token = Buffer.from(`${email}:${password}`).toString("base64");
    const backendUrl = process.env.BACKEND_BASE_URL || "http://localhost:3000/api/v1";

    const response = await fetch(`${backendUrl}/notes?page=1&per_page=1`, {
      headers: {
        Authorization: `Basic ${token}`,
      },
    });

    if (!response.ok) {
      // Invalid credentials - destroy the session we just created
      const { destroySession } = await import("@/lib/auth/session");
      await destroySession();

      return NextResponse.json(
        {
          error: {
            code: "unauthorized",
            message: "Invalid email or password",
          },
        },
        { status: 401 }
      );
    }

    return NextResponse.json({ success: true, email });
  } catch (error) {
    console.error("Login error:", error);
    return NextResponse.json(
      {
        error: {
          code: "internal_error",
          message: "An unexpected error occurred",
        },
      },
      { status: 500 }
    );
  }
}
