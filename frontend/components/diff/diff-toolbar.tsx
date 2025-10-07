"use client";

import { Columns, List, ChevronUp, ChevronDown, GitFork, Undo2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

interface DiffToolbarProps {
  viewMode: "inline" | "side-by-side";
  onViewModeChange: (mode: "inline" | "side-by-side") => void;
  contextLines: number;
  onContextLinesChange: (lines: number) => void;
  currentHunk: number;
  totalHunks: number;
  onNavigateHunk: (direction: "prev" | "next") => void;
  onRevert?: () => void;
  onFork?: () => void;
  canRevert?: boolean;
  canFork?: boolean;
}

export function DiffToolbar({
  viewMode,
  onViewModeChange,
  contextLines,
  onContextLinesChange,
  currentHunk,
  totalHunks,
  onNavigateHunk,
  onRevert,
  onFork,
  canRevert = false,
  canFork = false,
}: DiffToolbarProps) {
  const hasPrevHunk = currentHunk > 0;
  const hasNextHunk = currentHunk < totalHunks - 1;

  return (
    <div className="flex items-center justify-between gap-4 rounded-lg border bg-card p-3">
      {/* Left: View controls */}
      <div className="flex items-center gap-3">
        <TooltipProvider>
          <ToggleGroup
            type="single"
            value={viewMode}
            onValueChange={(value) => value && onViewModeChange(value as "inline" | "side-by-side")}
          >
            <Tooltip>
              <TooltipTrigger asChild>
                <ToggleGroupItem value="inline" aria-label="Inline view">
                  <List className="h-4 w-4" />
                </ToggleGroupItem>
              </TooltipTrigger>
              <TooltipContent>
                <p>Inline view</p>
              </TooltipContent>
            </Tooltip>

            <Tooltip>
              <TooltipTrigger asChild>
                <ToggleGroupItem value="side-by-side" aria-label="Side-by-side view">
                  <Columns className="h-4 w-4" />
                </ToggleGroupItem>
              </TooltipTrigger>
              <TooltipContent>
                <p>Side-by-side view</p>
              </TooltipContent>
            </Tooltip>
          </ToggleGroup>
        </TooltipProvider>

        <Separator orientation="vertical" className="h-6" />

        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">Context:</span>
          <Select
            value={contextLines.toString()}
            onValueChange={(value) => onContextLinesChange(parseInt(value, 10))}
          >
            <SelectTrigger className="w-16 h-8">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="0">0</SelectItem>
              <SelectItem value="1">1</SelectItem>
              <SelectItem value="3">3</SelectItem>
              <SelectItem value="5">5</SelectItem>
              <SelectItem value="10">10</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Center: Hunk navigation */}
      {totalHunks > 0 && (
        <div className="flex items-center gap-2">
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => onNavigateHunk("prev")}
                  disabled={!hasPrevHunk}
                  aria-label="Previous hunk"
                >
                  <ChevronUp className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                <p>Previous hunk</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>

          <span className="text-sm text-muted-foreground font-mono min-w-[4rem] text-center">
            {currentHunk + 1} / {totalHunks}
          </span>

          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => onNavigateHunk("next")}
                  disabled={!hasNextHunk}
                  aria-label="Next hunk"
                >
                  <ChevronDown className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                <p>Next hunk</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
      )}

      {/* Right: Actions */}
      <div className="flex items-center gap-2">
        {canFork && onFork && (
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="outline" size="sm" onClick={onFork}>
                  <GitFork className="h-4 w-4 mr-2" />
                  Fork
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                <p>Create a separate copy with your changes</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        )}

        {canRevert && onRevert && (
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="outline" size="sm" onClick={onRevert}>
                  <Undo2 className="h-4 w-4 mr-2" />
                  Revert
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                <p>Revert to this version</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        )}
      </div>
    </div>
  );
}
