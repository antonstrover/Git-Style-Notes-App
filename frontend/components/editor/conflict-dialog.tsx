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
  onClose: () => void;
  onRefresh: () => void;
}

export function ConflictDialog({ open, onClose, onRefresh }: ConflictDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent>
        <DialogHeader>
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5 text-destructive" />
            <DialogTitle>Version Conflict</DialogTitle>
          </div>
          <DialogDescription>
            The note has been updated by someone else while you were editing. Your changes cannot be
            saved. Please refresh to see the latest version.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={onRefresh}>Refresh Content</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
