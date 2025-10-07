import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider, useQuery } from "@tanstack/react-query";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { queryKeys } from "@/lib/api/keys";
import type { ReactNode } from "react";

// Mock fetch
global.fetch = vi.fn();

describe("API Hooks", () => {
  let queryClient: QueryClient;

  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: {
          retry: false,
        },
      },
    });
    vi.clearAllMocks();
  });

  it("fetches notes successfully", async () => {
    const mockNotes = {
      data: [
        {
          id: 1,
          title: "Test Note",
          visibility: "private",
          created_at: "2025-01-01T00:00:00Z",
          updated_at: "2025-01-01T00:00:00Z",
          owner_id: 1,
          head_version_id: 1,
        },
      ],
      total: 1,
      page: 1,
      per_page: 25,
    };

    (global.fetch as any).mockResolvedValueOnce({
      ok: true,
      json: async () => mockNotes,
    });

    const { result } = renderHook(
      () =>
        useQuery({
          queryKey: queryKeys.notes.list(1, 25),
          queryFn: async () => {
            const response = await fetch("/api/notes?page=1&per_page=25");
            return response.json();
          },
        }),
      { wrapper }
    );

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual(mockNotes);
  });

  it("handles fetch error", async () => {
    (global.fetch as any).mockResolvedValueOnce({
      ok: false,
      status: 500,
    });

    const { result } = renderHook(
      () =>
        useQuery({
          queryKey: queryKeys.notes.list(1, 25),
          queryFn: async () => {
            const response = await fetch("/api/notes?page=1&per_page=25");
            if (!response.ok) throw new Error("Failed to fetch");
            return response.json();
          },
        }),
      { wrapper }
    );

    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeTruthy();
  });

  it("uses correct query keys", () => {
    expect(queryKeys.notes.list(1, 25)).toEqual(["notes", "list", 1, 25]);
    expect(queryKeys.notes.detail(1)).toEqual(["notes", "detail", 1]);
    expect(queryKeys.versions.list(1, 1, 10)).toEqual(["notes", 1, "versions", "list", 1, 10]);
  });
});
