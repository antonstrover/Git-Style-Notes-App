"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Plus, Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { VisibilityBadge } from "@/components/ui/visibility-badge";
import { LoadingState } from "@/components/feedback/loading-state";
import { ErrorState } from "@/components/feedback/error-state";
import { EmptyState } from "@/components/feedback/empty-state";
import { formatRelativeTime } from "@/lib/utils";
import { queryKeys } from "@/lib/api/keys";
import type { Note } from "@/lib/api/schemas";

export default function DashboardPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const perPage = 25;

  const {
    data: notesData,
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: queryKeys.notes.list(page, perPage),
    queryFn: async () => {
      const response = await fetch(`/api/notes?page=${page}&per_page=${perPage}`);
      if (!response.ok) {
        throw new Error("Failed to fetch notes");
      }
      return response.json();
    },
  });

  const createNoteMutation = useMutation({
    mutationFn: async () => {
      const response = await fetch("/api/notes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          note: {
            title: "Untitled Note",
            visibility: "private",
          },
        }),
      });
      if (!response.ok) {
        throw new Error("Failed to create note");
      }
      return response.json();
    },
    onSuccess: (note: Note) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.notes.lists() });
      router.push(`/notes/${note.id}`);
    },
  });

  if (isLoading) {
    return (
      <div className="container max-w-screen-xl py-8">
        <LoadingState />
      </div>
    );
  }

  if (error) {
    return (
      <div className="container max-w-screen-xl py-8">
        <ErrorState
          message={error instanceof Error ? error.message : "Failed to load notes"}
          retry={() => refetch()}
        />
      </div>
    );
  }

  const notes = notesData?.data || [];
  const total = notesData?.total || 0;
  const totalPages = Math.ceil(total / perPage);

  return (
    <div className="container max-w-screen-xl py-8">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">My Notes</h1>
          <p className="text-muted-foreground">
            {total} {total === 1 ? "note" : "notes"} total
          </p>
        </div>
        <Button
          onClick={() => createNoteMutation.mutate()}
          disabled={createNoteMutation.isPending}
        >
          <Plus className="mr-2 h-4 w-4" />
          New Note
        </Button>
      </div>

      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search notes... (coming soon)"
            className="pl-9"
            disabled
          />
        </div>
      </div>

      {notes.length === 0 ? (
        <EmptyState
          title="No notes yet"
          description="Create your first note to get started"
          action={
            <Button onClick={() => createNoteMutation.mutate()}>
              <Plus className="mr-2 h-4 w-4" />
              Create Note
            </Button>
          }
        />
      ) : (
        <>
          <div className="space-y-4">
            {notes.map((note: Note) => (
              <Card
                key={note.id}
                className="cursor-pointer transition-colors hover:bg-accent"
                onClick={() => router.push(`/notes/${note.id}`)}
              >
                <CardHeader>
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <CardTitle className="line-clamp-1">{note.title}</CardTitle>
                      <CardDescription className="mt-1">
                        Updated {formatRelativeTime(note.updated_at)}
                        {note.owner && ` by ${note.owner.email}`}
                      </CardDescription>
                    </div>
                    <VisibilityBadge visibility={note.visibility} />
                  </div>
                </CardHeader>
                {note.head_version && (
                  <CardContent>
                    <p className="line-clamp-2 text-sm text-muted-foreground">
                      {note.head_version.content.slice(0, 200)}
                      {note.head_version.content.length > 200 ? "..." : ""}
                    </p>
                  </CardContent>
                )}
              </Card>
            ))}
          </div>

          {totalPages > 1 && (
            <div className="mt-8 flex items-center justify-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page === 1}
              >
                Previous
              </Button>
              <div className="text-sm text-muted-foreground">
                Page {page} of {totalPages}
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                disabled={page === totalPages}
              >
                Next
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
