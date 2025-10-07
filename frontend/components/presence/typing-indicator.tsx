"use client";

import { PresenceUser } from "@/lib/realtime/types";

interface TypingIndicatorProps {
  typingUserIds: Set<number>;
  allUsers: PresenceUser[];
  currentUserEmail?: string;
}

export function TypingIndicator({
  typingUserIds,
  allUsers,
  currentUserEmail,
}: TypingIndicatorProps) {
  // Filter out current user and get typing users
  const typingUsers = allUsers.filter(
    (user) => typingUserIds.has(user.id) && user.email !== currentUserEmail
  );

  if (typingUsers.length === 0) return null;

  const names = typingUsers.map((u) => u.email.split("@")[0]).join(", ");

  return (
    <div className="text-sm text-muted-foreground italic">
      {names} {typingUsers.length === 1 ? "is" : "are"} typing...
    </div>
  );
}
