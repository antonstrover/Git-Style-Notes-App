"use client";

import { PresenceUser } from "@/lib/realtime/types";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

interface PresenceBarProps {
  users: PresenceUser[];
  currentUserEmail?: string;
}

export function PresenceBar({ users, currentUserEmail }: PresenceBarProps) {
  if (users.length === 0) return null;

  return (
    <TooltipProvider>
      <div className="flex items-center gap-2">
        <span className="text-sm text-muted-foreground">Active:</span>
        <div className="flex -space-x-2">
          {users.map((user) => {
            const isCurrentUser = user.email === currentUserEmail;
            return (
              <Tooltip key={user.id}>
                <TooltipTrigger>
                  <div
                    className={`flex h-8 w-8 items-center justify-center rounded-full border-2 bg-primary text-xs font-medium text-primary-foreground ${
                      isCurrentUser ? "border-green-500" : "border-background"
                    }`}
                  >
                    {user.initials}
                  </div>
                </TooltipTrigger>
                <TooltipContent>
                  {user.email} {isCurrentUser && "(You)"}
                </TooltipContent>
              </Tooltip>
            );
          })}
        </div>
        <span className="text-sm text-muted-foreground">({users.length})</span>
      </div>
    </TooltipProvider>
  );
}
