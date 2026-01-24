"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

declare global {
  interface Window {
    workbox?: any;
  }
}

export function PwaUpdateToast() {
  const [show, setShow] = useState(false);

  useEffect(() => {
    // next-pwa uses Workbox in production
    if (typeof window === "undefined") return;

    const wb = window.workbox;
    if (!wb) return;

    const onWaiting = () => {
      // A new SW is installed and waiting to activate
      setShow(true);
    };

    wb.addEventListener("waiting", onWaiting);

    // Also catch some cases where SW updates but goes into waiting quickly
    wb.addEventListener("installed", (event: any) => {
      if (event?.isUpdate) setShow(true);
    });

    return () => {
      try {
        wb.removeEventListener("waiting", onWaiting);
      } catch {}
    };
  }, []);

  const refreshToUpdate = async () => {
    const wb = window.workbox;
    if (!wb) {
      // fallback
      window.location.reload();
      return;
    }

    // Tell SW to skip waiting and take control, then reload
    setShow(false);
    try {
      await wb.messageSkipWaiting();
    } finally {
      window.location.reload();
    }
  };

  if (!show) return null;

  return (
    <div
      className={cn(
        "fixed left-1/2 z-[100] w-[calc(100%-24px)] max-w-md -translate-x-1/2",
        "bottom-4 sm:bottom-6",
      )}
      role="status"
      aria-live="polite"
    >
      <div className="rounded-2xl border bg-background shadow-lg px-4 py-3 flex items-center justify-between gap-3">
        <div className="min-w-0">
          <p className="text-sm font-semibold">Update available</p>
          <p className="text-xs text-muted-foreground truncate">
            A newer version of Money Master is ready.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Button size="sm" variant="outline" onClick={() => setShow(false)}>
            Later
          </Button>
          <Button size="sm" onClick={refreshToUpdate}>
            Refresh
          </Button>
        </div>
      </div>
    </div>
  );
}
