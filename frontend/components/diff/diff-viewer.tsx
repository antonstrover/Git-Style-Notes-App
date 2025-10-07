"use client";

import { useRef, useCallback } from "react";
import { DiffHunkComponent } from "./diff-hunk";
import { DiffStatsComponent } from "./diff-stats";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { AlertTriangle } from "lucide-react";
import type { DiffResult, MergePreviewResult } from "@/lib/api/schemas";

interface DiffViewerProps {
  diff: DiffResult;
  viewMode?: "inline" | "side-by-side";
  mergePreview?: MergePreviewResult;
  onHunkNavigate?: (index: number) => void;
}

export function DiffViewer({
  diff,
  viewMode = "inline",
  mergePreview,
  onHunkNavigate,
}: DiffViewerProps) {
  const hunkRefs = useRef<(HTMLDivElement | null)[]>([]);

  const scrollToHunk = useCallback((index: number) => {
    const hunkEl = hunkRefs.current[index];
    if (hunkEl) {
      hunkEl.scrollIntoView({ behavior: "smooth", block: "center" });
      onHunkNavigate?.(index);
    }
  }, [onHunkNavigate]);

  if (diff.hunks.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-center">
        <p className="text-lg font-medium text-muted-foreground">
          No changes between versions
        </p>
        <p className="text-sm text-muted-foreground mt-1">
          The content is identical.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Stats summary */}
      <div className="flex items-center justify-between">
        <DiffStatsComponent stats={diff.stats} />
        <div className="flex items-center gap-2">
          <Badge variant="outline" className="font-mono text-xs">
            {diff.mode}
          </Badge>
          {diff.truncated && (
            <Badge variant="destructive" className="text-xs">
              Truncated
            </Badge>
          )}
        </div>
      </div>
      {/* Truncation warning */}
      {diff.truncated && (
        <Alert variant="destructive">
          <AlertTriangle className="h-4 w-4" />
          <AlertDescription>
            This diff has been truncated due to size. Only the first {diff.hunks.length} hunks are shown.
            Consider narrowing your comparison scope or viewing smaller sections.
          </AlertDescription>
        </Alert>
      )}
      {/* Conflict summary (if merge preview provided) */}
      {mergePreview && mergePreview.summary.conflict_count > 0 && (
        <Alert>
          <AlertTriangle className="h-4 w-4" />
          <AlertDescription>
            <strong>{mergePreview.summary.conflict_count}</strong> {mergePreview.summary.conflict_count === 1 ? "conflict" : "conflicts"} detected.
            {" "}{mergePreview.summary.clean_count} {mergePreview.summary.clean_count === 1 ? "change" : "changes"} can be merged cleanly.
          </AlertDescription>
        </Alert>
      )}
      {/* Hunks */}
      <div className="space-y-4">
        {diff.hunks.map((hunk, index) => {
          // Determine if this hunk is conflicted based on merge preview
          const isConflicted = mergePreview
            ? mergePreview.hunks.some(
                (mh) => mh.status === "conflict" && (
                  mh.local_hunk === hunk || mh.head_hunk === hunk
                )
              )
            : false;

          return (
            <div
              key={index}
              ref={el => {
                (hunkRefs.current[index] = el);
              }}
              data-hunk-index={index}
            >
              <DiffHunkComponent
                hunk={hunk}
                viewMode={viewMode}
                isConflicted={isConflicted}
              />
            </div>
          );
        })}
      </div>
      {/* Hunk count */}
      <div className="text-center text-sm text-muted-foreground">
        Showing {diff.hunks.length} {diff.hunks.length === 1 ? "hunk" : "hunks"}
      </div>
    </div>
  );
}
