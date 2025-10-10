"use client";

export function AnimatedBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {/* Gradient mesh background */}
      <div className="gradient-mesh absolute inset-0" />

      {/* Animated particles */}
      <div className="absolute inset-0">
        {[...Array(5)].map((_, i) => (
          <div
            key={i}
            className="absolute h-1 w-1 rounded-full bg-primary/20 animate-float"
            style={{
              left: `${20 + i * 20}%`,
              top: `${30 + (i % 3) * 20}%`,
              animationDelay: `${i * 0.5}s`,
              animationDuration: `${6 + i}s`,
            }}
          />
        ))}
      </div>

      {/* Radial gradients for depth */}
      <div
        className="absolute -left-40 -top-40 h-80 w-80 rounded-full bg-primary/10 blur-3xl"
        style={{ animation: "float 8s ease-in-out infinite" }}
      />
      <div
        className="absolute -bottom-40 -right-40 h-80 w-80 rounded-full bg-purple-500/10 blur-3xl"
        style={{ animation: "float 10s ease-in-out infinite", animationDelay: "2s" }}
      />
    </div>
  );
}
