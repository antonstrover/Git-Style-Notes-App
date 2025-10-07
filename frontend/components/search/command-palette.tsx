"use client";

import { useState, useEffect, useCallback } from "react";
import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { SearchInput } from "./search-input";
import { suggestNotes } from "@/lib/api/search";
import { queryKeys } from "@/lib/api/keys";
import { FileText, Search, Loader2 } from "lucide-react";
import { Skeleton } from "@/components/ui/skeleton";

export interface CommandPaletteProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function CommandPalette({ open, onOpenChange }: CommandPaletteProps) {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [selectedIndex, setSelectedIndex] = useState(0);

  // Reset state when dialog opens/closes
  useEffect(() => {
    if (!open) {
      setQuery("");
      setSelectedIndex(0);
    }
  }, [open]);

  // Fetch suggestions
  const {
    data: suggestions,
    isLoading,
  } = useQuery({
    queryKey: queryKeys.search.suggest(query),
    queryFn: () => suggestNotes({ query, top: 8 }),
    enabled: open && query.length > 0,
    staleTime: 30000,
  });

  const suggestionsList = suggestions?.suggestions || [];

  // Handle keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (!open) return;

      if (e.key === "ArrowDown") {
        e.preventDefault();
        setSelectedIndex((prev) =>
          prev < suggestionsList.length - 1 ? prev + 1 : prev
        );
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setSelectedIndex((prev) => (prev > 0 ? prev - 1 : prev));
      } else if (e.key === "Enter") {
        e.preventDefault();
        if (suggestionsList.length > 0 && selectedIndex < suggestionsList.length) {
          // Navigate to selected suggestion
          const suggestion = suggestionsList[selectedIndex];
          router.push(`/notes/${suggestion.note_id}`);
          onOpenChange(false);
        } else if (query.trim()) {
          // Navigate to search page with query
          router.push(`/search?q=${encodeURIComponent(query)}`);
          onOpenChange(false);
        }
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [open, suggestionsList, selectedIndex, query, router, onOpenChange]);

  // Reset selected index when suggestions change
  useEffect(() => {
    setSelectedIndex(0);
  }, [suggestionsList.length]);

  const handleSuggestionClick = (noteId: number) => {
    router.push(`/notes/${noteId}`);
    onOpenChange(false);
  };

  const handleFullSearch = () => {
    if (query.trim()) {
      router.push(`/search?q=${encodeURIComponent(query)}`);
      onOpenChange(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[600px] p-0 gap-0">
        {/* Search Input */}
        <div className="p-4 border-b">
          <SearchInput
            value={query}
            onChange={setQuery}
            onSubmit={handleFullSearch}
            placeholder="Search notes or press Enter for full search..."
            debounceMs={200}
          />
        </div>

        {/* Results */}
        <div className="max-h-[400px] overflow-y-auto">
          {!query && (
            <div className="p-8 text-center text-muted-foreground">
              <Search className="h-12 w-12 mx-auto mb-3 opacity-50" />
              <p>Type to search your notes</p>
              <p className="text-xs mt-2">Press Enter to see all results</p>
            </div>
          )}

          {query && isLoading && (
            <div className="p-4 space-y-2">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="flex items-center gap-3 p-2">
                  <Skeleton className="h-5 w-5 rounded" />
                  <Skeleton className="h-4 flex-1" />
                </div>
              ))}
            </div>
          )}

          {query && !isLoading && suggestionsList.length === 0 && (
            <div className="p-8 text-center text-muted-foreground">
              <p>No suggestions found</p>
              <button
                onClick={handleFullSearch}
                className="text-sm text-primary hover:underline mt-2"
              >
                Press Enter for full search
              </button>
            </div>
          )}

          {query && !isLoading && suggestionsList.length > 0 && (
            <div className="p-2">
              {suggestionsList.map((suggestion, index) => (
                <button
                  key={`${suggestion.note_id}-${index}`}
                  onClick={() => handleSuggestionClick(suggestion.note_id)}
                  className={`w-full flex items-center gap-3 p-3 rounded-md text-left transition-colors ${
                    index === selectedIndex
                      ? "bg-accent text-accent-foreground"
                      : "hover:bg-accent/50"
                  }`}
                  onMouseEnter={() => setSelectedIndex(index)}
                >
                  <FileText className="h-4 w-4 flex-shrink-0" />
                  <span className="flex-1 truncate">{suggestion.text}</span>
                </button>
              ))}

              {/* Full search option */}
              <div className="mt-2 pt-2 border-t">
                <button
                  onClick={handleFullSearch}
                  className="w-full flex items-center gap-3 p-3 rounded-md text-left text-sm text-muted-foreground hover:bg-accent/50 transition-colors"
                >
                  <Search className="h-4 w-4 flex-shrink-0" />
                  <span>
                    Search all results for &quot;{query}&quot;
                  </span>
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Footer hint */}
        <div className="p-2 border-t bg-muted/50 text-xs text-muted-foreground flex items-center justify-center gap-4">
          <span>↑↓ Navigate</span>
          <span>Enter Select</span>
          <span>Esc Close</span>
        </div>
      </DialogContent>
    </Dialog>
  );
}
