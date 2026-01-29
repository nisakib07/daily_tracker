"use client";

import { cn } from "@/lib/utils";

interface SkeletonProps {
  className?: string;
}

function Skeleton({ className }: SkeletonProps) {
  return (
    <div className={cn("skeleton rounded-md", className)} />
  );
}

export function DashboardSkeleton() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 via-white to-slate-50 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950">
      {/* Header Skeleton */}
      <header className="sticky top-0 z-20 border-b bg-white/90 dark:bg-slate-900/90 backdrop-blur-md">
        <div className="mx-auto max-w-2xl px-3 sm:px-4 py-3 sm:py-4">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2 sm:gap-3">
              <Skeleton className="h-9 w-9 sm:h-10 sm:w-10 rounded-xl" />
              <div className="space-y-1.5">
                <Skeleton className="h-4 w-24 sm:w-28" />
                <Skeleton className="h-3 w-16 hidden sm:block" />
              </div>
            </div>
            <div className="flex items-center gap-2 sm:gap-3">
              <Skeleton className="h-9 w-9 sm:h-10 sm:w-10 rounded-lg" />
              <Skeleton className="h-9 w-9 sm:h-10 sm:w-10 rounded-lg" />
              <div className="text-right">
                <Skeleton className="h-3 w-12 mb-1.5" />
                <Skeleton className="h-6 sm:h-8 w-20 sm:w-28" />
              </div>
              <Skeleton className="h-9 w-9 sm:h-10 sm:w-10 rounded-lg" />
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-2xl px-3 sm:px-4 py-4 sm:py-6 space-y-4 sm:space-y-6">
        {/* Account Cards Skeleton */}
        <section>
          <div className="grid grid-cols-3 gap-2 sm:gap-3">
            {[1, 2, 3].map((i) => (
              <div 
                key={i} 
                className={cn(
                  "rounded-xl border bg-card p-3 sm:p-4 space-y-3 opacity-0 animate-fade-in-up",
                  `animation-delay-${i * 100}`
                )}
                style={{ animationFillMode: "forwards" }}
              >
                <div className="flex items-center gap-2 sm:gap-3">
                  <Skeleton className="h-8 w-8 sm:h-10 sm:w-10 rounded-lg" />
                  <Skeleton className="h-4 w-16 sm:w-20" />
                </div>
                <div>
                  <Skeleton className="h-3 w-10 mb-1.5" />
                  <Skeleton className="h-6 sm:h-8 w-full" />
                </div>
                <div className="pt-2 border-t border-border/50">
                  <Skeleton className="h-3 w-full mb-1" />
                  <Skeleton className="h-2.5 w-16" />
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* Action Buttons Skeleton */}
        <section className="hidden sm:flex flex-row gap-2">
          {[1, 2, 3].map((i) => (
            <Skeleton 
              key={i} 
              className={cn(
                "flex-1 h-12 rounded-lg opacity-0 animate-fade-in-up",
                `animation-delay-${(i + 3) * 100}`
              )}
              style={{ animationFillMode: "forwards" }}
            />
          ))}
        </section>

        {/* Monthly Stats Skeleton */}
        <section 
          className="rounded-xl border bg-card p-4 sm:p-6 space-y-4 opacity-0 animate-fade-in-up animation-delay-400"
          style={{ animationFillMode: "forwards" }}
        >
          <div className="flex items-center justify-between">
            <Skeleton className="h-4 w-28" />
            <div className="flex items-center gap-2">
              <Skeleton className="h-8 w-8 rounded-lg" />
              <Skeleton className="h-8 w-24" />
              <Skeleton className="h-8 w-8 rounded-lg" />
            </div>
          </div>
          <div className="grid grid-cols-3 gap-2 sm:gap-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="rounded-lg bg-muted/50 p-3 sm:p-4 space-y-2">
                <div className="flex items-center justify-between">
                  <Skeleton className="h-3 w-12" />
                  <Skeleton className="h-4 w-4" />
                </div>
                <Skeleton className="h-6 sm:h-8 w-full" />
                <Skeleton className="h-3 w-12" />
              </div>
            ))}
          </div>
          <div className="pt-4 border-t border-border space-y-3">
            <Skeleton className="h-4 w-36" />
            {[1, 2, 3].map((i) => (
              <div key={i} className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <Skeleton className="h-3 w-20" />
                  <Skeleton className="h-3 w-16" />
                </div>
                <Skeleton className="h-2 w-full rounded-full" />
              </div>
            ))}
          </div>
        </section>

        {/* Tabs Skeleton */}
        <section 
          className="space-y-4 opacity-0 animate-fade-in-up animation-delay-500"
          style={{ animationFillMode: "forwards" }}
        >
          <Skeleton className="h-10 w-full rounded-lg" />
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div 
                key={i} 
                className="rounded-xl border bg-card p-3 sm:p-4"
              >
                <div className="flex items-start gap-3">
                  <Skeleton className="h-10 w-10 sm:h-11 sm:w-11 rounded-xl flex-shrink-0" />
                  <div className="flex-1 space-y-2">
                    <Skeleton className="h-4 w-32" />
                    <Skeleton className="h-3 w-24" />
                  </div>
                  <div className="text-right space-y-1.5">
                    <Skeleton className="h-5 w-20 ml-auto" />
                    <Skeleton className="h-3 w-14 ml-auto" />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}

export function AnalyticsSkeleton() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 via-white to-slate-50 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950">
      {/* Header */}
      <header className="sticky top-0 z-20 border-b bg-white/90 dark:bg-slate-900/90 backdrop-blur-md">
        <div className="mx-auto max-w-4xl px-3 sm:px-4 py-3 sm:py-4">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2 sm:gap-3">
              <Skeleton className="h-9 w-9 sm:h-10 sm:w-10 rounded-lg" />
              <Skeleton className="h-9 w-9 sm:h-10 sm:w-10 rounded-xl" />
              <div className="space-y-1.5">
                <Skeleton className="h-4 w-20" />
                <Skeleton className="h-3 w-28 hidden sm:block" />
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Skeleton className="h-9 w-9 rounded-lg" />
              <Skeleton className="h-9 sm:h-10 w-20 sm:w-24 rounded-lg" />
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-4xl px-3 sm:px-4 py-4 sm:py-6 space-y-4 sm:space-y-6">
        {/* Mode Toggle + Month Selector */}
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-2">
            <Skeleton className="h-9 w-24 rounded-lg" />
            <Skeleton className="h-9 w-20 rounded-lg" />
          </div>
          <div className="flex items-center gap-2">
            <Skeleton className="h-9 w-9 rounded-lg" />
            <Skeleton className="h-9 w-32 rounded-lg" />
            <Skeleton className="h-9 w-24 rounded-lg" />
            <Skeleton className="h-9 w-9 rounded-lg" />
          </div>
        </div>

        {/* Summary Cards */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-3">
          {[1, 2, 3, 4].map((i) => (
            <div 
              key={i} 
              className={cn(
                "rounded-xl border bg-card p-3 sm:p-4 space-y-2 opacity-0 animate-fade-in-up",
                `animation-delay-${i * 100}`
              )}
              style={{ animationFillMode: "forwards" }}
            >
              <div className="flex items-center gap-2">
                <Skeleton className="h-4 w-4" />
                <Skeleton className="h-3 w-14" />
              </div>
              <Skeleton className="h-6 sm:h-8 w-full" />
              <Skeleton className="h-3 w-20" />
            </div>
          ))}
        </div>

        {/* Charts Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {[1, 2].map((i) => (
            <div 
              key={i} 
              className={cn(
                "rounded-xl border bg-card p-4 sm:p-6 opacity-0 animate-fade-in-up",
                `animation-delay-${(i + 4) * 100}`
              )}
              style={{ animationFillMode: "forwards" }}
            >
              <div className="space-y-2 mb-4">
                <Skeleton className="h-5 w-36" />
                <Skeleton className="h-3 w-48" />
              </div>
              <Skeleton className="h-[250px] sm:h-[300px] w-full rounded-lg" />
            </div>
          ))}
        </div>

        {/* Trend Chart */}
        <div 
          className="rounded-xl border bg-card p-4 sm:p-6 opacity-0 animate-fade-in-up animation-delay-500"
          style={{ animationFillMode: "forwards" }}
        >
          <div className="space-y-2 mb-4">
            <Skeleton className="h-5 w-32" />
            <Skeleton className="h-3 w-44" />
          </div>
          <Skeleton className="h-[250px] sm:h-[300px] w-full rounded-lg" />
        </div>
      </main>
    </div>
  );
}
