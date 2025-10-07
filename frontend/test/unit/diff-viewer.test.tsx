import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { DiffViewer } from "@/components/diff/diff-viewer";
import type { DiffResult } from "@/lib/api/schemas";

describe("DiffViewer", () => {
  it("renders empty state when no hunks", () => {
    const emptyDiff: DiffResult = {
      hunks: [],
      stats: {
        additions: 0,
        deletions: 0,
        modifications: 0,
        unchanged: 10,
      },
      truncated: false,
      mode: "line",
    };

    render(<DiffViewer diff={emptyDiff} />);
    expect(screen.getByText(/no changes between versions/i)).toBeInTheDocument();
  });

  it("renders stats when hunks exist", () => {
    const diffWithChanges: DiffResult = {
      hunks: [
        {
          old_start: 1,
          old_lines: 3,
          new_start: 1,
          new_lines: 3,
          context_before: [],
          changes: [
            {
              type: "add",
              new_line: 2,
              new_text: "Added line",
            },
          ],
          context_after: [],
        },
      ],
      stats: {
        additions: 1,
        deletions: 0,
        modifications: 0,
        unchanged: 5,
      },
      truncated: false,
      mode: "line",
    };

    render(<DiffViewer diff={diffWithChanges} />);
    expect(screen.getByText(/1 addition/i)).toBeInTheDocument();
  });

  it("shows truncation warning when truncated", () => {
    const truncatedDiff: DiffResult = {
      hunks: [],
      stats: {
        additions: 0,
        deletions: 0,
        modifications: 0,
        unchanged: 0,
      },
      truncated: true,
      mode: "line",
    };

    render(<DiffViewer diff={truncatedDiff} />);
    expect(screen.getByText(/truncated/i)).toBeInTheDocument();
  });

  it("displays correct mode badge", () => {
    const wordModeDiff: DiffResult = {
      hunks: [],
      stats: {
        additions: 0,
        deletions: 0,
        modifications: 0,
        unchanged: 0,
      },
      truncated: false,
      mode: "word",
    };

    render(<DiffViewer diff={wordModeDiff} />);
    expect(screen.getByText("word")).toBeInTheDocument();
  });
});
