"use client";

import { useState, useEffect, use } from "react";
import { useRouter } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Save, History, ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { TipTapEditor } from "@/components/editor/tiptap-editor";
import { LoadingState } from "@/components/feedback/loading-state";
import { ErrorState } from "@/components/feedback/error-state";
import { formatRelativeTime } from "@/lib/utils";
import { queryKeys } from "@/lib/api/keys";
import type { Note, Version } from "@/lib/api/schemas";

export default function NotePage({ params }: { params: Promise<{ id: string }> }) {
  const resolvedParams = use(params);
  const noteId = parseInt(resolvedParams.id, 10);
  const router = useRouter();
  const queryClient = useQueryClient();

  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");
  const [originalContent, setOriginalContent] = useState("");
  const [versionsPage, setVersionsPage] = useState(1);

  const {
    data: note,
    isLoading: noteLoading,
    error: noteError,
  } = useQuery({
    queryKey: queryKeys.notes.detail(noteId),
    queryFn: async () => {
      const response = await fetch(`/api/notes/${noteId}`);
      if (!response.ok) throw new Error("Failed to fetch note");
      return response.json() as Promise<Note>;
    },
  });

  const {
    data: versionsData,
    isLoading: versionsLoading,
  } = useQuery({
    queryKey: queryKeys.versions.list(noteId, versionsPage, 10),
    queryFn: async () => {
      const response = await fetch(
        `/api/notes/${noteId}/versions?page=${versionsPage}&per_page=10`
      );
      if (!response.ok) throw new Error("Failed to fetch versions");
      return response.json();
    },
    enabled: !!note,
  });

  useEffect(() => {
    if (note) {
      setTitle(note.title);
      if (note.head_version) {
        setContent(note.head_version.content);
        setOriginalContent(note.head_version.content);
      }
    }
  }, [note]);

  const createVersionMutation = useMutation({
    mutationFn: async () => {
      const response = await fetch(`/api/notes/${noteId}/versions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          version: {
            content,
            summary: "Updated content",
            base_version_id: note?.head_version_id,
          },
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        if (response.status === 409) {
          throw new Error("CONFLICT");
        }
        throw new Error(error.error?.message || "Failed to save version");
      }
      return response.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.notes.detail(noteId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.versions.all(noteId) });
      setOriginalContent(content);
    },
  });

  const hasChanges = content !== originalContent;

  const handleSave = () => {
    if (hasChanges) {
      createVersionMutation.mutate();
    }
  };

  // Keyboard shortcut for save
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "s") {
        e.preventDefault();
        handleSave();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [hasChanges, content]);

  if (noteLoading) {
    return (
      <div className="container max-w-screen-2xl py-8">
        <LoadingState />
      </div>
    );
  }

  if (noteError || !note) {
    return (
      <div className="container max-w-screen-2xl py-8">
        <ErrorState message="Failed to load note" retry={() => router.push("/")} />
      </div>
    );
  }

  const versions = versionsData?.data || [];
  const totalVersions = versionsData?.total || 0;

  return (
    <div className="container max-w-screen-2xl py-8">
      <div className="mb-6 flex items-center justify-between">
        <Button variant="ghost" onClick={() => router.push("/")}>
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to Notes
        </Button>
        <div className="flex items-center gap-2">
          <Button
            onClick={handleSave}
            disabled={!hasChanges || createVersionMutation.isPending}
          >
            <Save className="mr-2 h-4 w-4" />
            {createVersionMutation.isPending ? "Saving..." : "Save Version"}
          </Button>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-[1fr_400px]">
        <div className="space-y-4">
          <div>
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="text-2xl font-bold"
              placeholder="Note title"
            />
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Content</CardTitle>
              <CardDescription>
                {note.head_version_id
                  ? `Version #${note.head_version_id} • ${formatRelativeTime(note.updated_at)}`
                  : "No versions yet"}
              </CardDescription>
            </CardHeader>
            <CardContent>
              <TipTapEditor
                content={content}
                onContentChange={setContent}
                placeholder="Start writing your note..."
                className="min-h-[500px]"
              />
              {createVersionMutation.error && (
                <div className="mt-4 rounded-md bg-destructive/10 p-3 text-sm text-destructive">
                  {createVersionMutation.error.message === "CONFLICT"
                    ? "Conflict detected: The note has been updated by someone else. Please refresh to see the latest version."
                    : createVersionMutation.error.message}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        <div>
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <History className="h-5 w-5" />
                <CardTitle>Version History</CardTitle>
              </div>
              <CardDescription>{totalVersions} versions</CardDescription>
            </CardHeader>
            <CardContent>
              {versionsLoading ? (
                <div className="space-y-2">
                  {[...Array(3)].map((_, i) => (
                    <div key={i} className="h-16 animate-pulse rounded bg-muted" />
                  ))}
                </div>
              ) : versions.length === 0 ? (
                <p className="text-sm text-muted-foreground">No versions yet</p>
              ) : (
                <div className="space-y-2">
                  {versions.map((version: Version) => (
                    <div
                      key={version.id}
                      className="rounded-lg border p-3 text-sm"
                    >
                      <div className="font-medium">Version #{version.id}</div>
                      <div className="text-xs text-muted-foreground">
                        {version.author?.email} • {formatRelativeTime(version.created_at)}
                      </div>
                      {version.summary && (
                        <div className="mt-1 text-xs italic">{version.summary}</div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
