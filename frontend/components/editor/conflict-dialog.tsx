"use client";

import { useEffect, useState } from "react";
import { AlertTriangle, ExternalLink } from "lucide-react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { getMergePreview } from "@/lib/api/notes";
import { queryKeys } from "@/lib/api/keys";

interface ConflictDialogProps {
  open: boolean;
  noteId?: number;
  baseVersionId?: number;
  localVersionId?: number;
  headVersionId?: number;
  onClose: () => void;
  onRefresh: () => void;
  onFork?: () => void;
}

export function ConflictDialog({
  open,
  noteId,
  baseVersionId,
  localVersionId,
  headVersionId,
  onClose,
  onRefresh,
  onFork
}: ConflictDialogProps) {
  const router = useRouter();
  const [showMergePreview, setShowMergePreview] = useState(false);

  // Fetch merge preview if we have all required IDs
  const canFetchMergePreview =
    open &&
    noteId !== undefined &&
    localVersionId !== undefined &&
    baseVersionId !== undefined &&
    headVersionId !== undefined &&
    showMergePreview;

  const { data: mergePreviewData, isLoading: mergePreviewLoading } = useQuery({
    queryKey: queryKeys.diffs.mergePreview(noteId!, localVersionId!, baseVersionId!, headVersionId!),
    queryFn: () => getMergePreview(noteId!, localVersionId!, baseVersionId!, headVersionId!),
    enabled: canFetchMergePreview,
  });

  // Auto-fetch merge preview when dialog opens
  useEffect(() => {
    if (open && noteId && localVersionId && baseVersionId && headVersionId) {
      setShowMergePreview(true);
    } else {
      setShowMergePreview(false);
    }
  }, [open, noteId, localVersionId, baseVersionId, headVersionId]);

  const handleViewDiff = () => {
    if (noteId && baseVersionId && headVersionId) {
      router.push(`/notes/${noteId}/diff?left=${baseVersionId}&right=${headVersionId}&view=inline`);
      onClose();
    }
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5 text-destructive" />
            <DialogTitle>Version Conflict</DialogTitle>
          </div>
          <DialogDescription>
            Another collaborator has updated this note while you were editing.
            {headVersionId && ` The note is now at version #${headVersionId}.`}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-4">
          {/* Merge preview summary */}
          {mergePreviewLoading && (
            <div className="text-sm text-muted-foreground">
              Analyzing changes...
            </div>
          )}

          {mergePreviewData && (
            <Alert variant={mergePreviewData.merge_preview.status === "conflicted" ? "destructive" : "default"}>
              <AlertDescription>
                <div className="space-y-2">
                  <div className="flex items-center gap-2">
                    {mergePreviewData.merge_preview.status === "conflicted" ? (
                      <>
                        <Badge variant="destructive">
                          {mergePreviewData.merge_preview.summary.conflict_count} {mergePreviewData.merge_preview.summary.conflict_count === 1 ? "conflict" : "conflicts"}
                        </Badge>
                        <span className="text-sm">detected in overlapping regions</span>
                      </>
                    ) : (
                      <>
                        <Badge variant="default" className="bg-green-600">
                          Clean merge
                        </Badge>
                        <span className="text-sm">No conflicts detected</span>
                      </>
                    )}
                  </div>
                  {mergePreviewData.merge_preview.summary.clean_count > 0 && (
                    <p className="text-sm">
                      {mergePreviewData.merge_preview.summary.clean_count} {mergePreviewData.merge_preview.summary.clean_count === 1 ? "change" : "changes"} can be merged automatically.
                    </p>
                  )}
                </div>
              </AlertDescription>
            </Alert>
          )}

          {/* Options */}
          <div>
            <p className="text-sm font-medium mb-2">Your options:</p>
            <ul className="space-y-2 text-sm">
              <li className="flex items-start gap-2">
                <span className="font-semibold min-w-[5rem]">View Diff:</span>
                <span className="text-muted-foreground">
                  Compare changes side-by-side to understand conflicts
                </span>
              </li>
              <li className="flex items-start gap-2">
                <span className="font-semibold min-w-[5rem]">Refresh:</span>
                <span className="text-muted-foreground">
                  Discard your changes and load the latest version
                </span>
              </li>
              {onFork && (
                <li className="flex items-start gap-2">
                  <span className="font-semibold min-w-[5rem]">Fork:</span>
                  <span className="text-muted-foreground">
                    Create a separate copy with your changes
                  </span>
                </li>
              )}
            </ul>
          </div>
        </div>

        <DialogFooter className="flex-col sm:flex-row gap-2">
          <Button variant="outline" onClick={onClose} className="w-full sm:w-auto">
            Cancel
          </Button>
          {baseVersionId && headVersionId && (
            <Button
              variant="secondary"
              onClick={handleViewDiff}
              className="w-full sm:w-auto"
            >
              <ExternalLink className="h-4 w-4 mr-2" />
              View Diff
            </Button>
          )}
          {onFork && (
            <Button
              variant="secondary"
              onClick={onFork}
              className="w-full sm:w-auto"
            >
              Fork Note
            </Button>
          )}
          <Button onClick={onRefresh} className="w-full sm:w-auto">
            Refresh Content
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
