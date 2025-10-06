import { Badge } from "@/components/ui/badge";
import { Lock, Link2, Globe } from "lucide-react";
import type { VisibilityType } from "@/lib/types";

interface VisibilityBadgeProps {
  visibility: VisibilityType;
}

export function VisibilityBadge({ visibility }: VisibilityBadgeProps) {
  const config = {
    private: {
      icon: Lock,
      label: "Private",
      variant: "secondary" as const,
    },
    link: {
      icon: Link2,
      label: "Link",
      variant: "outline" as const,
    },
    public: {
      icon: Globe,
      label: "Public",
      variant: "default" as const,
    },
  };

  const { icon: Icon, label, variant } = config[visibility];

  return (
    <Badge variant={variant} className="gap-1">
      <Icon className="h-3 w-3" />
      {label}
    </Badge>
  );
}
