"use client";

import { useState } from "react";
import { ChevronDown, ChevronUp } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { DiffHunk, DiffChange, WordToken } from "@/lib/api/schemas";

interface DiffHunkProps {
  hunk: DiffHunk;
  viewMode: "inline" | "side-by-side";
  isConflicted?: boolean;
}

export function DiffHunkComponent({ hunk, viewMode, isConflicted = false }: DiffHunkProps) {
  const [isCollapsed, setIsCollapsed] = useState(false);

  const hasContext = hunk.context_before.length > 0 || hunk.context_after.length > 0;

  return (
    <div className={cn(
      "border rounded-lg overflow-hidden",
      isConflicted && "border-destructive"
    )}>
      {/* Hunk header */}
      <div className="flex items-center justify-between bg-muted px-4 py-2 text-xs font-mono text-muted-foreground">
        <span>
          @@ -{hunk.old_start},{hunk.old_lines} +{hunk.new_start},{hunk.new_lines} @@
        </span>
        {hasContext && (
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setIsCollapsed(!isCollapsed)}
            className="h-6 px-2"
          >
            {isCollapsed ? (
              <>
                <ChevronDown className="h-3 w-3 mr-1" />
                Expand
              </>
            ) : (
              <>
                <ChevronUp className="h-3 w-3 mr-1" />
                Collapse
              </>
            )}
          </Button>
        )}
      </div>

      {/* Hunk content */}
      {!isCollapsed && (
        <div className="bg-background">
          {viewMode === "inline" ? (
            <InlineView hunk={hunk} />
          ) : (
            <SideBySideView hunk={hunk} />
          )}
        </div>
      )}

      {hunk.truncated && (
        <div className="bg-yellow-50 dark:bg-yellow-950 px-4 py-2 text-xs text-yellow-800 dark:text-yellow-200">
          This hunk has been truncated due to size. Some changes are not shown.
        </div>
      )}
    </div>
  );
}

function InlineView({ hunk }: { hunk: DiffHunk }) {
  return (
    <div className="font-mono text-sm">
      {/* Context before */}
      {hunk.context_before.map((line, idx) => (
        <div
          key={`ctx-before-${idx}`}
          className="flex hover:bg-muted/50"
        >
          <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none">
            {line.old_line}
          </span>
          <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none border-r">
            {line.new_line}
          </span>
          <span className="flex-1 px-4 py-0.5 text-muted-foreground">{line.text}</span>
        </div>
      ))}

      {/* Changes */}
      {hunk.changes.map((change, idx) => {
        // For modify type, render as two lines: deletion + addition
        if (change.type === "modify") {
          return (
            <div key={`change-${idx}`}>
              <ChangeLineInline
                change={{
                  ...change,
                  type: "delete",
                  new_line: null,
                  new_text: undefined,
                  word_diff: undefined,
                }}
              />
              <ChangeLineInline
                change={{
                  ...change,
                  type: "add",
                  old_line: null,
                  old_text: undefined,
                }}
              />
            </div>
          );
        }

        return <ChangeLineInline key={`change-${idx}`} change={change} />;
      })}

      {/* Context after */}
      {hunk.context_after.map((line, idx) => (
        <div
          key={`ctx-after-${idx}`}
          className="flex hover:bg-muted/50"
        >
          <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none">
            {line.old_line}
          </span>
          <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none border-r">
            {line.new_line}
          </span>
          <span className="flex-1 px-4 py-0.5 text-muted-foreground">{line.text}</span>
        </div>
      ))}
    </div>
  );
}

function ChangeLineInline({ change }: { change: DiffChange }) {
  const bgClass = {
    add: "bg-green-50 dark:bg-green-950/30",
    delete: "bg-red-50 dark:bg-red-950/30",
    modify: "bg-yellow-50 dark:bg-yellow-950/30",
    context: "",
  }[change.type];

  const marker = {
    add: "+",
    delete: "-",
    modify: "~",
    context: " ",
  }[change.type];

  const textClass = {
    add: "text-green-700 dark:text-green-300",
    delete: "text-red-700 dark:text-red-300",
    modify: "text-yellow-700 dark:text-yellow-300",
    context: "text-muted-foreground",
  }[change.type];

  return (
    <div className={cn("flex hover:bg-muted/50", bgClass)}>
      <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none">
        {change.old_line ?? ""}
      </span>
      <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none border-r">
        {change.new_line ?? ""}
      </span>
      <span className={cn("inline-block w-6 px-2 py-0.5 font-bold select-none", textClass)}>
        {marker}
      </span>
      <span className={cn("flex-1 py-0.5", textClass)}>
        {change.type === "modify" && change.word_diff ? (
          <WordDiffLine tokens={change.word_diff.new_tokens} />
        ) : (
          change.new_text || change.old_text || ""
        )}
      </span>
    </div>
  );
}

function SideBySideView({ hunk }: { hunk: DiffHunk }) {
  return (
    <div className="grid grid-cols-2 divide-x font-mono text-sm">
      {/* Left side (old) */}
      <div>
        {hunk.context_before.map((line, idx) => (
          <div key={`ctx-before-left-${idx}`} className="flex hover:bg-muted/50">
            <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none">
              {line.old_line}
            </span>
            <span className="flex-1 px-4 py-0.5 text-muted-foreground">{line.text}</span>
          </div>
        ))}

        {hunk.changes.map((change, idx) => (
          <ChangeLineSide key={`change-left-${idx}`} change={change} side="left" />
        ))}

        {hunk.context_after.map((line, idx) => (
          <div key={`ctx-after-left-${idx}`} className="flex hover:bg-muted/50">
            <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none">
              {line.old_line}
            </span>
            <span className="flex-1 px-4 py-0.5 text-muted-foreground">{line.text}</span>
          </div>
        ))}
      </div>

      {/* Right side (new) */}
      <div>
        {hunk.context_before.map((line, idx) => (
          <div key={`ctx-before-right-${idx}`} className="flex hover:bg-muted/50">
            <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none">
              {line.new_line}
            </span>
            <span className="flex-1 px-4 py-0.5 text-muted-foreground">{line.text}</span>
          </div>
        ))}

        {hunk.changes.map((change, idx) => (
          <ChangeLineSide key={`change-right-${idx}`} change={change} side="right" />
        ))}

        {hunk.context_after.map((line, idx) => (
          <div key={`ctx-after-right-${idx}`} className="flex hover:bg-muted/50">
            <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none">
              {line.new_line}
            </span>
            <span className="flex-1 px-4 py-0.5 text-muted-foreground">{line.text}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function ChangeLineSide({ change, side }: { change: DiffChange; side: "left" | "right" }) {
  const showOnLeft = side === "left" && (change.type === "delete" || change.type === "modify");
  const showOnRight = side === "right" && (change.type === "add" || change.type === "modify");

  if (!showOnLeft && !showOnRight) {
    return <div className="h-6"></div>; // Empty placeholder
  }

  const bgClass = {
    add: "bg-green-50 dark:bg-green-950/30",
    delete: "bg-red-50 dark:bg-red-950/30",
    modify: "bg-yellow-50 dark:bg-yellow-950/30",
  }[change.type];

  const textClass = {
    add: "text-green-700 dark:text-green-300",
    delete: "text-red-700 dark:text-red-300",
    modify: "text-yellow-700 dark:text-yellow-300",
  }[change.type];

  const lineNumber = side === "left" ? change.old_line : change.new_line;
  const text = side === "left" ? change.old_text : change.new_text;

  return (
    <div className={cn("flex hover:bg-muted/50", bgClass)}>
      <span className="inline-block w-12 px-2 py-0.5 text-right text-muted-foreground select-none">
        {lineNumber ?? ""}
      </span>
      <span className={cn("flex-1 px-4 py-0.5", textClass)}>
        {change.type === "modify" && change.word_diff ? (
          <WordDiffLine
            tokens={side === "left" ? change.word_diff.old_tokens : change.word_diff.new_tokens}
          />
        ) : (
          text || ""
        )}
      </span>
    </div>
  );
}

function WordDiffLine({ tokens }: { tokens: WordToken[] }) {
  return (
    <>
      {tokens.map((token, idx) => {
        const className = {
          unchanged: "",
          added: "bg-green-200 dark:bg-green-800 font-semibold",
          deleted: "bg-red-200 dark:bg-red-800 font-semibold",
        }[token.type];

        return (
          <span key={idx} className={className}>
            {token.text}
          </span>
        );
      })}
    </>
  );
}
