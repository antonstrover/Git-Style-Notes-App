"use client";

import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { FileText, Clock } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import type { SearchResult } from "@/lib/api/schemas";
import Link from "next/link";

export interface SearchResultCardProps {
  result: SearchResult;
  onNavigate?: () => void;
}

export function SearchResultCard({ result, onNavigate }: SearchResultCardProps) {
  const formattedDate = formatDistanceToNow(new Date(result.updated_at), {
    addSuffix: true,
  });

  return (
    <Link
      href={`/notes/${result.note_id}`}
      onClick={onNavigate}
      className="block focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-lg"
    >
      <Card className="p-4 hover:shadow-md transition-shadow cursor-pointer">
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1 min-w-0">
            {/* Title */}
            <div className="flex items-center gap-2 mb-2">
              <FileText className="h-4 w-4 text-muted-foreground flex-shrink-0" />
              <h3 className="font-semibold text-lg truncate">{result.title}</h3>
            </div>

            {/* Snippet with semantic highlighting */}
            <div
              className="text-sm text-muted-foreground line-clamp-3 mb-3"
              dangerouslySetInnerHTML={{
                __html: result.snippet.replace(
                  /<em>(.*?)<\/em>/g,
                  '<mark class="bg-yellow-200 dark:bg-yellow-900 px-0.5 rounded">$1</mark>'
                ),
              }}
            />

            {/* Metadata */}
            <div className="flex items-center gap-3 text-xs text-muted-foreground">
              <div className="flex items-center gap-1">
                <Clock className="h-3 w-3" />
                <span>{formattedDate}</span>
              </div>
              {result.score && (
                <Badge variant="outline" className="text-xs">
                  Score: {result.score.toFixed(2)}
                </Badge>
              )}
            </div>
          </div>
        </div>
      </Card>
    </Link>
  );
}
