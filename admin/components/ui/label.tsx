import * as React from "react";
import { cn } from "@/lib/utils";

export function Label({ className, ...props }: React.LabelHTMLAttributes<HTMLLabelElement>): React.JSX.Element {
  return <label className={cn("text-xs font-semibold uppercase tracking-wide text-muted-foreground", className)} {...props} />;
}
