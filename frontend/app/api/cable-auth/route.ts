import { getSession } from "@/lib/auth/session";
import { NextResponse } from "next/server";

/**
 * Provides WebSocket connection parameters including auth token
 * This allows client-side code to connect to Action Cable with credentials
 */
export async function GET() {
  const session = await getSession();

  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const backendWsUrl = process.env.BACKEND_WS_URL || "ws://localhost:3000/cable";

  return NextResponse.json({
    url: backendWsUrl,
    authToken: session.token,
  });
}
