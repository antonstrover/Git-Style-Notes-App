"use client";

import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

interface ConflictDialogProps {
  open: boolean;
  headVersionId?: number;
  onClose: () => void;
  onRefresh: () => void;
  onFork?: () => void;
}

export function ConflictDialog({
  open,
  headVersionId,
  onClose,
  onRefresh,
  onFork
}: ConflictDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent>
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
        <div className="py-4">
          <p className="text-sm">You have two options:</p>
          <ul className="mt-2 list-disc list-inside text-sm space-y-1">
            <li>
              <strong>Refresh:</strong> Discard your changes and load the latest version
            </li>
            {onFork && (
              <li>
                <strong>Fork:</strong> Create a separate copy with your changes
              </li>
            )}
          </ul>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          {onFork && (
            <Button variant="secondary" onClick={onFork}>
              Fork Note
            </Button>
          )}
          <Button onClick={onRefresh}>Refresh Content</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
