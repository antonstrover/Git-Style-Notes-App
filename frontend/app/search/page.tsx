"use client";

import { useState, Suspense } from "react";
import { useQuery } from "@tanstack/react-query";
import { useSearchParams, useRouter } from "next/navigation";
import { searchNotes } from "@/lib/api/search";
import { queryKeys } from "@/lib/api/keys";
import { SearchInput } from "@/components/search/search-input";
import { SearchResultCard } from "@/components/search/search-result-card";
import { LoadingState } from "@/components/feedback/loading-state";
import { ErrorState } from "@/components/feedback/error-state";
import { EmptyState } from "@/components/feedback/empty-state";
import { Button } from "@/components/ui/button";
import { ChevronLeft, ChevronRight, Search as SearchIcon } from "lucide-react";
import { Skeleton } from "@/components/ui/skeleton";

const PAGE_SIZE = parseInt(process.env.NEXT_PUBLIC_SEARCH_PAGE_SIZE || "20");

function SearchPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const initialQuery = searchParams.get("q") || "";
  const initialPage = parseInt(searchParams.get("page") || "1");

  const [query, setQuery] = useState(initialQuery);
  const [page, setPage] = useState(initialPage);

  // Update URL when query or page changes
  const updateUrl = (newQuery: string, newPage: number) => {
    const params = new URLSearchParams();
    if (newQuery) params.set("q", newQuery);
    if (newPage > 1) params.set("page", newPage.toString());

    const url = params.toString() ? `/search?${params.toString()}` : "/search";
    router.push(url, { scroll: false });
  };

  const handleQueryChange = (newQuery: string) => {
    setQuery(newQuery);
    setPage(1);
    updateUrl(newQuery, 1);
  };

  const handlePageChange = (newPage: number) => {
    setPage(newPage);
    updateUrl(query, newPage);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const skip = (page - 1) * PAGE_SIZE;

  const {
    data: searchResponse,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: queryKeys.search.query(query, PAGE_SIZE, skip),
    queryFn: () =>
      searchNotes({
        query,
        top: PAGE_SIZE,
        skip,
      }),
    enabled: query.length > 0,
    staleTime: 30000, // Cache for 30 seconds
  });

  const totalPages = searchResponse?.total_count
    ? Math.ceil(searchResponse.total_count / PAGE_SIZE)
    : 0;

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Search Notes</h1>
        <p className="text-muted-foreground">
          Search across all your notes using semantic and keyword search
        </p>
      </div>

      {/* Search Input */}
      <div className="mb-8">
        <SearchInput
          value={query}
          onChange={handleQueryChange}
          placeholder="Search for notes, topics, or keywords..."
          className="w-full"
        />
      </div>

      {/* Results */}
      <div className="min-h-[400px]">
        {!query && (
          <EmptyState
            icon={SearchIcon}
            title="Start searching"
            description="Enter keywords or phrases to search across your notes"
          />
        )}

        {query && isLoading && (
          <div className="space-y-4">
            {[...Array(5)].map((_, i) => (
              <div key={i} className="p-4 border rounded-lg">
                <Skeleton className="h-6 w-3/4 mb-3" />
                <Skeleton className="h-4 w-full mb-2" />
                <Skeleton className="h-4 w-5/6 mb-3" />
                <Skeleton className="h-3 w-1/4" />
              </div>
            ))}
          </div>
        )}

        {query && isError && (
          <ErrorState
            title="Search failed"
            description={
              error instanceof Error
                ? error.message
                : "An error occurred while searching. Please try again."
            }
            action={{
              label: "Retry",
              onClick: () => refetch(),
            }}
          />
        )}

        {query && !isLoading && !isError && searchResponse && (
          <>
            {/* Results count */}
            {searchResponse.total_count !== undefined && (
              <div className="mb-4 text-sm text-muted-foreground">
                Found {searchResponse.total_count} result
                {searchResponse.total_count !== 1 ? "s" : ""} for &quot;{query}
                &quot;
              </div>
            )}

            {/* Results list */}
            {searchResponse.results.length === 0 ? (
              <EmptyState
                icon={SearchIcon}
                title="No results found"
                description="Try different keywords or check your spelling"
              />
            ) : (
              <div className="space-y-4 mb-8">
                {searchResponse.results.map((result) => (
                  <SearchResultCard key={result.chunk_id} result={result} />
                ))}
              </div>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handlePageChange(page - 1)}
                  disabled={page === 1}
                >
                  <ChevronLeft className="h-4 w-4 mr-1" />
                  Previous
                </Button>

                <div className="flex items-center gap-1">
                  {[...Array(Math.min(totalPages, 5))].map((_, i) => {
                    let pageNum: number;
                    if (totalPages <= 5) {
                      pageNum = i + 1;
                    } else if (page <= 3) {
                      pageNum = i + 1;
                    } else if (page >= totalPages - 2) {
                      pageNum = totalPages - 4 + i;
                    } else {
                      pageNum = page - 2 + i;
                    }

                    return (
                      <Button
                        key={pageNum}
                        variant={page === pageNum ? "default" : "outline"}
                        size="sm"
                        onClick={() => handlePageChange(pageNum)}
                        className="w-10"
                      >
                        {pageNum}
                      </Button>
                    );
                  })}
                </div>

                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handlePageChange(page + 1)}
                  disabled={page === totalPages}
                >
                  Next
                  <ChevronRight className="h-4 w-4 ml-1" />
                </Button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <SearchPageContent />
    </Suspense>
  );
}
