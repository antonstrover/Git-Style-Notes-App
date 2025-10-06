import { cookies } from "next/headers";

const SESSION_COOKIE_NAME = process.env.SESSION_COOKIE_NAME || "vn_auth";
const SESSION_COOKIE_SECURE = process.env.SESSION_COOKIE_SECURE === "true";

export interface SessionData {
  email: string;
  token: string; // base64(email:password)
}

/**
 * Creates a session by storing the base64-encoded credentials in an HttpOnly cookie
 */
export async function createSession(email: string, password: string) {
  const token = Buffer.from(`${email}:${password}`).toString("base64");
  const cookieStore = await cookies();

  cookieStore.set(SESSION_COOKIE_NAME, token, {
    httpOnly: true,
    secure: SESSION_COOKIE_SECURE,
    sameSite: "lax",
    maxAge: 60 * 60 * 24 * 7, // 1 week
    path: "/",
  });

  return { email, token };
}

/**
 * Destroys the session by deleting the auth cookie
 */
export async function destroySession() {
  const cookieStore = await cookies();
  cookieStore.delete(SESSION_COOKIE_NAME);
}

/**
 * Gets the current session data from the cookie
 */
export async function getSession(): Promise<SessionData | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE_NAME)?.value;

  if (!token) {
    return null;
  }

  try {
    const decoded = Buffer.from(token, "base64").toString("utf-8");
    const [email] = decoded.split(":");

    if (!email) {
      return null;
    }

    return { email, token };
  } catch {
    return null;
  }
}

/**
 * Checks if a user is authenticated
 */
export async function isAuthenticated(): Promise<boolean> {
  const session = await getSession();
  return session !== null;
}
