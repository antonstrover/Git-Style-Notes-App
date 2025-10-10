"use client";

import { Button, ButtonProps } from "@/components/ui/button";
import { forwardRef } from "react";
import Link from "next/link";

interface GradientButtonProps extends Omit<ButtonProps, "asChild"> {
  href?: string;
}

export const GradientButton = forwardRef<HTMLButtonElement, GradientButtonProps>(
  ({ className = "", children, href, ...props }, ref) => {
    if (href) {
      return (
        <Button
          ref={ref}
          asChild
          className={`hover-lift ${className}`}
          {...props}
        >
          <Link href={href}>{children}</Link>
        </Button>
      );
    }

    return (
      <Button
        ref={ref}
        className={`hover-lift ${className}`}
        {...props}
      >
        {children}
      </Button>
    );
  }
);

GradientButton.displayName = "GradientButton";
