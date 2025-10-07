"use client";

import { use, useState, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { DiffViewer } from "@/components/diff/diff-viewer";
import { DiffToolbar } from "@/components/diff/diff-toolbar";
import { LoadingState } from "@/components/feedback/loading-state";
import { ErrorState } from "@/components/feedback/error-state";
import { getDiff, getNote } from "@/lib/api/notes";
import { queryKeys } from "@/lib/api/keys";

interface DiffPageProps {
  params: Promise<{ id: string }>;
}

export default function DiffPage({ params }: DiffPageProps) {
  const resolvedParams = use(params);
  const router = useRouter();
  const searchParams = useSearchParams();

  const noteId = parseInt(resolvedParams.id, 10);
  const leftId = searchParams.get("left") ? parseInt(searchParams.get("left")!, 10) : null;
  const rightId = searchParams.get("right") ? parseInt(searchParams.get("right")!, 10) : null;
  const initialView = searchParams.get("view") as "inline" | "side-by-side" | null;

  const [viewMode, setViewMode] = useState<"inline" | "side-by-side">(initialView || "inline");
  const [contextLines, setContextLines] = useState(3);
  const [currentHunk, setCurrentHunk] = useState(0);

  // Fetch note details
  const { data: note } = useQuery({
    queryKey: queryKeys.notes.detail(noteId),
    queryFn: () => getNote(noteId),
    enabled: !isNaN(noteId),
  });

  // Fetch diff
  const {
    data: diffData,
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: queryKeys.diffs.diff(noteId, leftId!, rightId!, {
      mode: "line",
      context: contextLines,
    }),
    queryFn: () =>
      getDiff(noteId, leftId!, rightId!, {
        mode: "line",
        context: contextLines,
      }),
    enabled: !isNaN(noteId) && leftId !== null && rightId !== null,
  });

  // Update URL when view mode changes
  useEffect(() => {
    if (leftId && rightId) {
      const params = new URLSearchParams();
      params.set("left", leftId.toString());
      params.set("right", rightId.toString());
      params.set("view", viewMode);
      router.replace(`?${params.toString()}`, { scroll: false });
    }
  }, [viewMode, leftId, rightId, router]);

  const handleNavigateHunk = (direction: "prev" | "next") => {
    const totalHunks = diffData?.diff.hunks.length || 0;
    if (direction === "prev" && currentHunk > 0) {
      setCurrentHunk(currentHunk - 1);
    } else if (direction === "next" && currentHunk < totalHunks - 1) {
      setCurrentHunk(currentHunk + 1);
    }
  };

  const handleContextLinesChange = (lines: number) => {
    setContextLines(lines);
    // Query will automatically refetch due to key change
  };

  if (!leftId || !rightId) {
    return (
      <div className="container max-w-5xl py-8">
        <ErrorState
          title="Missing comparison parameters"
          message="Both 'left' and 'right' version IDs are required to compare."
          onRetry={() => router.back()}
        />
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="container max-w-5xl py-8">
        <LoadingState />
      </div>
    );
  }

  if (error || !diffData) {
    return (
      <div className="container max-w-5xl py-8">
        <ErrorState
          title="Failed to load diff"
          message={error instanceof Error ? error.message : "An error occurred while loading the diff."}
          onRetry={() => refetch()}
        />
      </div>
    );
  }

  return (
    <div className="container max-w-7xl py-8">
      {/* Header */}
      <div className="mb-6">
        <div className="flex items-center gap-4 mb-4">
          <Button variant="ghost" size="sm" asChild>
            <Link href={`/notes/${noteId}`}>
              <ArrowLeft className="h-4 w-4 mr-2" />
              Back to Note
            </Link>
          </Button>
        </div>

        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Diff Comparison</h1>
            {note && (
              <p className="text-muted-foreground mt-1">{note.title}</p>
            )}
          </div>
        </div>

        {/* Version info */}
        <div className="mt-4 flex items-center gap-4 text-sm">
          <div className="flex items-center gap-2">
            <span className="font-medium">Left:</span>
            <span className="text-muted-foreground">
              Version #{diffData.left_version.id} - {diffData.left_version.summary}
            </span>
          </div>
          <span className="text-muted-foreground">→</span>
          <div className="flex items-center gap-2">
            <span className="font-medium">Right:</span>
            <span className="text-muted-foreground">
              Version #{diffData.right_version.id} - {diffData.right_version.summary}
            </span>
          </div>
        </div>
      </div>

      {/* Toolbar */}
      <div className="mb-6">
        <DiffToolbar
          viewMode={viewMode}
          onViewModeChange={setViewMode}
          contextLines={contextLines}
          onContextLinesChange={handleContextLinesChange}
          currentHunk={currentHunk}
          totalHunks={diffData.diff.hunks.length}
          onNavigateHunk={handleNavigateHunk}
          canRevert={false}
          canFork={false}
        />
      </div>

      {/* Diff viewer */}
      <Card>
        <CardHeader>
          <CardTitle>Changes</CardTitle>
        </CardHeader>
        <CardContent>
          <DiffViewer
            diff={diffData.diff}
            viewMode={viewMode}
            onHunkNavigate={setCurrentHunk}
          />
        </CardContent>
      </Card>
    </div>
  );
}
