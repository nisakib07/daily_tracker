"use client";

import * as React from "react";
import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";

export function ThemeToggle() {
  const { theme, setTheme, resolvedTheme } = useTheme();
  const [mounted, setMounted] = React.useState(false);

  React.useEffect(() => {
    setMounted(true);
  }, []);

  const toggleTheme = () => {
    setTheme(resolvedTheme === "dark" ? "light" : "dark");
  };

  if (!mounted) {
    return (
      <Button
        variant="outline"
        size="icon"
        className="h-9 w-9 sm:h-10 sm:w-10 bg-transparent border-slate-200 dark:border-slate-700"
      >
        <span className="h-4 w-4 sm:h-5 sm:w-5" />
      </Button>
    );
  }

  return (
    <Button
      variant="outline"
      size="icon"
      onClick={toggleTheme}
      className="relative h-9 w-9 sm:h-10 sm:w-10 bg-transparent border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 hover:border-slate-300 dark:hover:border-slate-600 overflow-hidden"
    >
      <Sun
        className={`h-4 w-4 sm:h-5 sm:w-5 absolute transition-all duration-500 ease-in-out ${
          resolvedTheme === "dark"
            ? "rotate-90 scale-0 opacity-0"
            : "rotate-0 scale-100 opacity-100"
        }`}
      />
      <Moon
        className={`h-4 w-4 sm:h-5 sm:w-5 absolute transition-all duration-500 ease-in-out ${
          resolvedTheme === "dark"
            ? "rotate-0 scale-100 opacity-100"
            : "-rotate-90 scale-0 opacity-0"
        }`}
      />
      <span className="sr-only">Toggle theme</span>
    </Button>
  );
}
