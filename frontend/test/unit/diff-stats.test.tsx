import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { DiffStatsComponent } from "@/components/diff/diff-stats";
import type { DiffStats } from "@/lib/api/schemas";

describe("DiffStatsComponent", () => {
  it("renders no changes message when all stats are zero", () => {
    const emptyStats: DiffStats = {
      additions: 0,
      deletions: 0,
      modifications: 0,
      unchanged: 10,
    };

    render(<DiffStatsComponent stats={emptyStats} />);
    expect(screen.getByText(/no changes/i)).toBeInTheDocument();
  });

  it("renders additions correctly", () => {
    const stats: DiffStats = {
      additions: 5,
      deletions: 0,
      modifications: 0,
      unchanged: 10,
    };

    render(<DiffStatsComponent stats={stats} />);
    expect(screen.getByText(/5 additions/i)).toBeInTheDocument();
  });

  it("renders deletions correctly", () => {
    const stats: DiffStats = {
      additions: 0,
      deletions: 3,
      modifications: 0,
      unchanged: 10,
    };

    render(<DiffStatsComponent stats={stats} />);
    expect(screen.getByText(/3 deletions/i)).toBeInTheDocument();
  });

  it("renders modifications correctly", () => {
    const stats: DiffStats = {
      additions: 0,
      deletions: 0,
      modifications: 2,
      unchanged: 10,
    };

    render(<DiffStatsComponent stats={stats} />);
    expect(screen.getByText(/2 modifications/i)).toBeInTheDocument();
  });

  it("renders multiple stats together", () => {
    const stats: DiffStats = {
      additions: 5,
      deletions: 3,
      modifications: 2,
      unchanged: 10,
    };

    render(<DiffStatsComponent stats={stats} />);
    expect(screen.getByText(/5 additions/i)).toBeInTheDocument();
    expect(screen.getByText(/3 deletions/i)).toBeInTheDocument();
    expect(screen.getByText(/2 modifications/i)).toBeInTheDocument();
  });

  it("renders compact mode", () => {
    const stats: DiffStats = {
      additions: 5,
      deletions: 3,
      modifications: 2,
      unchanged: 10,
    };

    render(<DiffStatsComponent stats={stats} compact={true} />);
    expect(screen.getByText("+5")).toBeInTheDocument();
    expect(screen.getByText("-3")).toBeInTheDocument();
    expect(screen.getByText("~2")).toBeInTheDocument();
  });

  it("uses singular form for single change", () => {
    const stats: DiffStats = {
      additions: 1,
      deletions: 0,
      modifications: 0,
      unchanged: 10,
    };

    render(<DiffStatsComponent stats={stats} />);
    expect(screen.getByText(/1 addition$/i)).toBeInTheDocument();
  });
});
