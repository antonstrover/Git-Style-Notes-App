"use client";

import { motion } from "framer-motion";
import { Button, ButtonProps } from "@/components/ui/button";
import { forwardRef } from "react";

interface GradientButtonProps extends Omit<ButtonProps, "asChild"> {
  href?: string;
}

export const GradientButton = forwardRef<HTMLButtonElement, GradientButtonProps>(
  ({ className = "", children, href, ...props }, ref) => {
    const MotionButton = motion(Button);

    if (href) {
      return (
        <a href={href}>
          <MotionButton
            ref={ref}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            className={`neon-glow-hover relative overflow-hidden bg-primary transition-all duration-300 ${className}`}
            {...props}
          >
            <span className="relative z-10">{children}</span>
            <div className="absolute inset-0 bg-gradient-to-r from-primary via-blue-500 to-purple-600 opacity-0 transition-opacity duration-300 hover:opacity-100" />
          </MotionButton>
        </a>
      );
    }

    return (
      <MotionButton
        ref={ref}
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        className={`neon-glow-hover relative overflow-hidden bg-primary transition-all duration-300 ${className}`}
        {...props}
      >
        <span className="relative z-10">{children}</span>
        <div className="absolute inset-0 bg-gradient-to-r from-primary via-blue-500 to-purple-600 opacity-0 transition-opacity duration-300 hover:opacity-100" />
      </MotionButton>
    );
  }
);

GradientButton.displayName = "GradientButton";
