import { useEffect, useState, useCallback, useRef } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { subscribeToNote, sendTypingIndicator } from "@/lib/realtime/notes";
import {
  PresenceUser,
  VersionCreatedEvent,
  TypingEvent,
  ConflictNoticeEvent,
} from "@/lib/realtime/types";
import { useToast } from "@/lib/hooks/use-toast";
import { debounce } from "@/lib/utils";
import { queryKeys } from "@/lib/api/keys";

export interface UseRealtimeNoteOptions {
  noteId: number;
  onConflict?: (headVersionId: number) => void;
}

export function useRealtimeNote({ noteId, onConflict }: UseRealtimeNoteOptions) {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [presenceUsers, setPresenceUsers] = useState<PresenceUser[]>([]);
  const [typingUsers, setTypingUsers] = useState<Set<number>>(new Set());
  const [isConnected, setIsConnected] = useState(false);
  const typingTimeouts = useRef<Map<number, NodeJS.Timeout>>(new Map());

  // Debounced query invalidation (250ms) to batch rapid updates
  const invalidateQueries = useCallback(
    debounce(() => {
      queryClient.invalidateQueries({ queryKey: queryKeys.notes.detail(noteId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.versions.all(noteId) });
    }, 250),
    [queryClient, noteId]
  );

  useEffect(() => {
    let unsubscribe: (() => void) | null = null;

    const connect = async () => {
      unsubscribe = await subscribeToNote(noteId, {
        onVersionCreated: (event: VersionCreatedEvent) => {
          console.log("[useRealtimeNote] Version created:", event);
          // Invalidate queries to refetch data
          invalidateQueries();

          // Show toast notification
          toast({
            title: "Note updated",
            description: `${event.author.email} saved: ${event.summary}`,
          });
        },

        onPresence: (event) => {
          console.log("[useRealtimeNote] Presence update:", event);
          setPresenceUsers(event.users);
          setIsConnected(true);
        },

        onTyping: (event: TypingEvent) => {
          const userId = event.user.id;

          // Add user to typing set
          setTypingUsers((prev) => new Set(prev).add(userId));

          // Clear existing timeout
          const existingTimeout = typingTimeouts.current.get(userId);
          if (existingTimeout) {
            clearTimeout(existingTimeout);
          }

          // Remove after 3 seconds
          const timeout = setTimeout(() => {
            setTypingUsers((prev) => {
              const next = new Set(prev);
              next.delete(userId);
              return next;
            });
            typingTimeouts.current.delete(userId);
          }, 3000);

          typingTimeouts.current.set(userId, timeout);
        },

        onConflictNotice: (event: ConflictNoticeEvent) => {
          console.warn("[useRealtimeNote] Conflict notice:", event);
          onConflict?.(event.head_version_id);

          toast({
            variant: "destructive",
            title: "Conflict detected",
            description: event.message,
          });
        },

        onError: (error) => {
          console.error("[useRealtimeNote] Realtime error:", error);
          setIsConnected(false);
        },
      });
    };

    connect();

    return () => {
      unsubscribe?.();
      // Clear all typing timeouts
      typingTimeouts.current.forEach((timeout) => clearTimeout(timeout));
      typingTimeouts.current.clear();
    };
  }, [noteId, invalidateQueries, onConflict, toast]);

  // Debounced typing indicator (1s)
  const notifyTyping = useCallback(
    debounce(() => {
      sendTypingIndicator(noteId);
    }, 1000),
    [noteId]
  );

  return {
    presenceUsers,
    typingUsers,
    isConnected,
    notifyTyping,
  };
}
