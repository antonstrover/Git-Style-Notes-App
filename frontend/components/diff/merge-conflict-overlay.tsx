"use client";

import { AlertTriangle, Check } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Card, CardContent } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { DiffHunkComponent } from "./diff-hunk";
import type { MergePreviewResult } from "@/lib/api/schemas";

interface MergeConflictOverlayProps {
  mergePreview: MergePreviewResult;
}

export function MergeConflictOverlay({ mergePreview }: MergeConflictOverlayProps) {
  const conflictedHunks = mergePreview.hunks.filter((h) => h.status === "conflict");
  const cleanHunks = mergePreview.hunks.filter((h) => h.status === "clean");

  return (
    <div className="space-y-6">
      {/* Summary */}
      <Alert variant={mergePreview.status === "conflicted" ? "destructive" : "default"}>
        {mergePreview.status === "conflicted" ? (
          <AlertTriangle className="h-4 w-4" />
        ) : (
          <Check className="h-4 w-4" />
        )}
        <AlertTitle>
          {mergePreview.status === "conflicted" ? "Conflicts Detected" : "Clean Merge"}
        </AlertTitle>
        <AlertDescription>
          {mergePreview.status === "conflicted" ? (
            <>
              <strong>{mergePreview.summary.conflict_count}</strong>{" "}
              {mergePreview.summary.conflict_count === 1 ? "conflict" : "conflicts"} require attention.
              {" "}<strong>{mergePreview.summary.clean_count}</strong>{" "}
              {mergePreview.summary.clean_count === 1 ? "change" : "changes"} can be merged automatically.
            </>
          ) : (
            <>
              All <strong>{mergePreview.summary.clean_count}</strong>{" "}
              {mergePreview.summary.clean_count === 1 ? "change" : "changes"} can be merged automatically.
            </>
          )}
        </AlertDescription>
      </Alert>

      {/* Tabs for filtered view */}
      <Tabs defaultValue="conflicts" className="w-full">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="conflicts">
            Conflicts ({conflictedHunks.length})
          </TabsTrigger>
          <TabsTrigger value="clean">
            Clean ({cleanHunks.length})
          </TabsTrigger>
          <TabsTrigger value="all">
            All ({mergePreview.hunks.length})
          </TabsTrigger>
        </TabsList>

        <TabsContent value="conflicts" className="space-y-4 mt-4">
          {conflictedHunks.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-8">
              No conflicts found.
            </p>
          ) : (
            conflictedHunks.map((hunk, idx) => (
              <ConflictHunkDisplay key={idx} hunk={hunk} />
            ))
          )}
        </TabsContent>

        <TabsContent value="clean" className="space-y-4 mt-4">
          {cleanHunks.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-8">
              No clean changes found.
            </p>
          ) : (
            cleanHunks.map((hunk, idx) => (
              <CleanHunkDisplay key={idx} hunk={hunk} />
            ))
          )}
        </TabsContent>

        <TabsContent value="all" className="space-y-4 mt-4">
          {mergePreview.hunks.map((hunk, idx) => (
            hunk.status === "conflict" ? (
              <ConflictHunkDisplay key={idx} hunk={hunk} />
            ) : (
              <CleanHunkDisplay key={idx} hunk={hunk} />
            )
          ))}
        </TabsContent>
      </Tabs>
    </div>
  );
}

function ConflictHunkDisplay({ hunk }: { hunk: any }) {
  return (
    <Card className="border-destructive">
      <CardContent className="p-4">
        <div className="flex items-center gap-2 mb-4">
          <AlertTriangle className="h-4 w-4 text-destructive" />
          <span className="font-semibold text-destructive">Conflict</span>
          <Badge variant="outline" className="ml-auto">{hunk.type}</Badge>
        </div>

        {hunk.conflict_region && (
          <p className="text-sm text-muted-foreground mb-4">
            Lines {hunk.conflict_region.start}–{hunk.conflict_region.end}
          </p>
        )}

        <div className="grid md:grid-cols-2 gap-4">
          {/* Local changes */}
          {hunk.local_hunk && (
            <div>
              <h4 className="text-sm font-medium mb-2">Your Changes</h4>
              <DiffHunkComponent
                hunk={hunk.local_hunk}
                viewMode="inline"
                isConflicted={true}
              />
            </div>
          )}

          {/* Head changes */}
          {hunk.head_hunk && (
            <div>
              <h4 className="text-sm font-medium mb-2">Remote Changes</h4>
              <DiffHunkComponent
                hunk={hunk.head_hunk}
                viewMode="inline"
                isConflicted={true}
              />
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}

function CleanHunkDisplay({ hunk }: { hunk: any }) {
  const title = {
    local_only: "Your changes only",
    head_only: "Remote changes only",
    identical: "Identical changes",
    overlapping: "Clean merge",
  }[hunk.type];

  const hunkToDisplay = hunk.local_hunk || hunk.head_hunk;

  if (!hunkToDisplay) {
    return null;
  }

  return (
    <Card>
      <CardContent className="p-4">
        <div className="flex items-center gap-2 mb-4">
          <Check className="h-4 w-4 text-green-600" />
          <span className="font-semibold text-green-600">Clean</span>
          <Badge variant="outline" className="ml-auto">{title}</Badge>
        </div>

        <DiffHunkComponent
          hunk={hunkToDisplay}
          viewMode="inline"
          isConflicted={false}
        />
      </CardContent>
    </Card>
  );
}
