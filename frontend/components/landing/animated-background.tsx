"use client";

export function AnimatedBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {/* Subtle gradient background - minimal and calm */}
      <div className="absolute inset-0 bg-gradient-to-br from-primary/5 via-background to-background" />
    </div>
  );
}
