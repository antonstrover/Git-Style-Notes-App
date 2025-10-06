import { getCableConsumer } from "./cable";
import { RealtimeEvent, RealtimeHandlers } from "./types";
import { Subscription } from "@rails/actioncable";

/**
 * Subscribe to real-time updates for a note
 * Returns an unsubscribe function
 */
export async function subscribeToNote(
  noteId: number,
  handlers: RealtimeHandlers
): Promise<() => void> {
  try {
    const consumer = await getCableConsumer();

    const subscription: Subscription = consumer.subscriptions.create(
      {
        channel: "NotesChannel",
        note_id: noteId,
      },
      {
        connected() {
          console.log(`[NotesChannel] Subscribed to note ${noteId}`);
        },

        disconnected() {
          console.log(`[NotesChannel] Disconnected from note ${noteId}`);
        },

        received(data: RealtimeEvent) {
          console.log(`[NotesChannel] Received event:`, data);

          try {
            switch (data.type) {
              case "version_created":
                handlers.onVersionCreated?.(data);
                break;
              case "presence":
                handlers.onPresence?.(data);
                break;
              case "typing":
                handlers.onTyping?.(data);
                break;
              case "conflict_notice":
                handlers.onConflictNotice?.(data);
                break;
              default:
                console.warn("[NotesChannel] Unknown event type:", data);
            }
          } catch (error) {
            console.error("[NotesChannel] Error handling event:", error);
            handlers.onError?.(
              error instanceof Error ? error : new Error(String(error))
            );
          }
        },
      }
    );

    // Return unsubscribe function
    return () => {
      console.log(`[NotesChannel] Unsubscribing from note ${noteId}`);
      subscription.unsubscribe();
    };
  } catch (error) {
    console.error("[NotesChannel] Failed to subscribe:", error);
    handlers.onError?.(
      error instanceof Error ? error : new Error(String(error))
    );
    // Return no-op unsubscribe
    return () => {};
  }
}

/**
 * Send typing indicator to other collaborators
 */
export async function sendTypingIndicator(noteId: number): Promise<void> {
  try {
    const consumer = await getCableConsumer();
    const subscription = consumer.subscriptions.subscriptions.find(
      (sub: any) =>
        sub.identifier === JSON.stringify({ channel: "NotesChannel", note_id: noteId })
    );

    if (subscription) {
      subscription.perform("typing", {});
    }
  } catch (error) {
    console.error("[NotesChannel] Failed to send typing indicator:", error);
  }
}
