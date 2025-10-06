import { cookies } from "next/headers";
import { apiErrorSchema } from "./schemas";

const BACKEND_BASE_URL = process.env.BACKEND_BASE_URL || "http://localhost:3000/api/v1";
const SESSION_COOKIE_NAME = process.env.SESSION_COOKIE_NAME || "vn_auth";

export class ApiError extends Error {
  constructor(
    public code: string,
    message: string,
    public status: number,
    public details?: Record<string, unknown>
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/**
 * Server-side fetch helper that automatically includes auth headers
 * from the session cookie.
 */
export async function apiFetch<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const cookieStore = await cookies();
  const authToken = cookieStore.get(SESSION_COOKIE_NAME)?.value;

  const headers: HeadersInit = {
    "Content-Type": "application/json",
    ...options.headers,
  };

  if (authToken) {
    headers["Authorization"] = `Basic ${authToken}`;
  }

  const url = `${BACKEND_BASE_URL}${endpoint}`;

  const response = await fetch(url, {
    ...options,
    headers,
  });

  // Handle error responses
  if (!response.ok) {
    const contentType = response.headers.get("content-type");
    if (contentType?.includes("application/json")) {
      try {
        const errorData = await response.json();
        const parsed = apiErrorSchema.safeParse(errorData);

        if (parsed.success) {
          throw new ApiError(
            parsed.data.error.code,
            parsed.data.error.message,
            response.status,
            parsed.data.error.details
          );
        }
      } catch (e) {
        if (e instanceof ApiError) throw e;
      }
    }

    // Fallback error
    throw new ApiError(
      "unknown_error",
      `HTTP ${response.status}: ${response.statusText}`,
      response.status
    );
  }

  // Handle 204 No Content
  if (response.status === 204) {
    return null as T;
  }

  // Parse JSON response
  const data = await response.json();
  return data as T;
}

/**
 * Helper to construct paginated responses from Rails API
 * Rails returns X-Total-Count header + array of items
 */
export async function apiFetchPaginated<T>(
  endpoint: string,
  page: number = 1,
  perPage: number = 25
): Promise<{ data: T[]; total: number; page: number; per_page: number }> {
  const cookieStore = await cookies();
  const authToken = cookieStore.get(SESSION_COOKIE_NAME)?.value;

  const headers: HeadersInit = {
    "Content-Type": "application/json",
  };

  if (authToken) {
    headers["Authorization"] = `Basic ${authToken}`;
  }

  const url = `${BACKEND_BASE_URL}${endpoint}?page=${page}&per_page=${perPage}`;

  const response = await fetch(url, { headers });

  if (!response.ok) {
    const contentType = response.headers.get("content-type");
    if (contentType?.includes("application/json")) {
      try {
        const errorData = await response.json();
        const parsed = apiErrorSchema.safeParse(errorData);

        if (parsed.success) {
          throw new ApiError(
            parsed.data.error.code,
            parsed.data.error.message,
            response.status,
            parsed.data.error.details
          );
        }
      } catch (e) {
        if (e instanceof ApiError) throw e;
      }
    }

    throw new ApiError(
      "unknown_error",
      `HTTP ${response.status}: ${response.statusText}`,
      response.status
    );
  }

  const data = (await response.json()) as T[];
  const totalCount = response.headers.get("X-Total-Count");
  const total = totalCount ? parseInt(totalCount, 10) : data.length;

  return {
    data,
    total,
    page,
    per_page: perPage,
  };
}
