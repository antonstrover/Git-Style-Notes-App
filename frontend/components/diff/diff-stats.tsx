"use client";

import { Plus, Minus, Edit2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { DiffStats } from "@/lib/api/schemas";

interface DiffStatsProps {
  stats: DiffStats;
  compact?: boolean;
}

export function DiffStatsComponent({ stats, compact = false }: DiffStatsProps) {
  const total = stats.additions + stats.deletions + stats.modifications;

  if (total === 0) {
    return (
      <Badge variant="secondary" className="font-mono">
        No changes
      </Badge>
    );
  }

  if (compact) {
    return (
      <div className="flex items-center gap-2 text-sm font-mono">
        {stats.additions > 0 && (
          <span className="text-green-600 dark:text-green-400">+{stats.additions}</span>
        )}
        {stats.deletions > 0 && (
          <span className="text-red-600 dark:text-red-400">-{stats.deletions}</span>
        )}
        {stats.modifications > 0 && (
          <span className="text-yellow-600 dark:text-yellow-400">~{stats.modifications}</span>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-4">
        {stats.additions > 0 && (
          <div className="flex items-center gap-1.5">
            <Plus className="h-4 w-4 text-green-600 dark:text-green-400" />
            <span className="text-sm font-medium text-green-600 dark:text-green-400">
              {stats.additions} {stats.additions === 1 ? "addition" : "additions"}
            </span>
          </div>
        )}
        {stats.deletions > 0 && (
          <div className="flex items-center gap-1.5">
            <Minus className="h-4 w-4 text-red-600 dark:text-red-400" />
            <span className="text-sm font-medium text-red-600 dark:text-red-400">
              {stats.deletions} {stats.deletions === 1 ? "deletion" : "deletions"}
            </span>
          </div>
        )}
        {stats.modifications > 0 && (
          <div className="flex items-center gap-1.5">
            <Edit2 className="h-4 w-4 text-yellow-600 dark:text-yellow-400" />
            <span className="text-sm font-medium text-yellow-600 dark:text-yellow-400">
              {stats.modifications} {stats.modifications === 1 ? "modification" : "modifications"}
            </span>
          </div>
        )}
      </div>

      {/* Visual diff bar */}
      <div className="flex h-2 overflow-hidden rounded-full bg-muted">
        {stats.additions > 0 && (
          <div
            className="bg-green-500 dark:bg-green-600"
            style={{ width: `${(stats.additions / total) * 100}%` }}
            aria-label={`${stats.additions} additions`}
          />
        )}
        {stats.deletions > 0 && (
          <div
            className="bg-red-500 dark:bg-red-600"
            style={{ width: `${(stats.deletions / total) * 100}%` }}
            aria-label={`${stats.deletions} deletions`}
          />
        )}
        {stats.modifications > 0 && (
          <div
            className="bg-yellow-500 dark:bg-yellow-600"
            style={{ width: `${(stats.modifications / total) * 100}%` }}
            aria-label={`${stats.modifications} modifications`}
          />
        )}
      </div>
    </div>
  );
}
