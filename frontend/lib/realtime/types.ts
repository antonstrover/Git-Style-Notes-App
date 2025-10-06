/**
 * Realtime event types from Action Cable
 */

export interface PresenceUser {
  id: number;
  email: string;
  initials: string;
}

export interface VersionCreatedEvent {
  type: "version_created";
  note_id: number;
  version_id: number;
  head_version_id: number;
  author: {
    id: number;
    email: string;
  };
  created_at: string;
  summary: string;
}

export interface PresenceEvent {
  type: "presence";
  note_id: number;
  users: PresenceUser[];
}

export interface TypingEvent {
  type: "typing";
  note_id: number;
  user: {
    id: number;
    email: string;
  };
  at: string;
}

export interface ConflictNoticeEvent {
  type: "conflict_notice";
  note_id: number;
  head_version_id: number;
  message: string;
}

export type RealtimeEvent =
  | VersionCreatedEvent
  | PresenceEvent
  | TypingEvent
  | ConflictNoticeEvent;

export interface RealtimeHandlers {
  onVersionCreated?: (event: VersionCreatedEvent) => void;
  onPresence?: (event: PresenceEvent) => void;
  onTyping?: (event: TypingEvent) => void;
  onConflictNotice?: (event: ConflictNoticeEvent) => void;
  onError?: (error: Error) => void;
}
