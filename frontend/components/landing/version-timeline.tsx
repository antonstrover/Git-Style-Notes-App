"use client";

import { motion } from "framer-motion";
import { GitCommit } from "lucide-react";

export function VersionTimeline() {
  const commits = [
    { id: 1, message: "Initial draft", time: "2h ago" },
    { id: 2, message: "Added research section", time: "1h ago" },
    { id: 3, message: "Fixed typos and formatting", time: "30m ago" },
    { id: 4, message: "Current version", time: "now", active: true },
  ];

  return (
    <div className="relative">
      {/* Timeline line */}
      <div className="absolute left-4 top-4 bottom-4 w-px bg-gradient-to-b from-primary/50 via-primary/30 to-transparent" />

      <div className="space-y-6">
        {commits.map((commit, index) => (
          <motion.div
            key={commit.id}
            initial={{ opacity: 0, x: -20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.4, delay: index * 0.1 }}
            className="relative flex items-start gap-4"
          >
            {/* Commit dot */}
            <div
              className={`relative z-10 flex h-8 w-8 items-center justify-center rounded-full border-2 ${
                commit.active
                  ? "border-primary bg-primary/20 shadow-lg shadow-primary/50"
                  : "border-primary/50 bg-background"
              }`}
            >
              <GitCommit className={`h-4 w-4 ${commit.active ? "text-primary" : "text-muted-foreground"}`} />
              {commit.active && (
                <span className="absolute inset-0 animate-glow-pulse rounded-full" />
              )}
            </div>

            {/* Commit message */}
            <div className="glass-panel flex-1 rounded-lg p-4">
              <p className={`font-medium ${commit.active ? "text-foreground" : "text-muted-foreground"}`}>
                {commit.message}
              </p>
              <p className="mt-1 text-xs text-muted-foreground">{commit.time}</p>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
