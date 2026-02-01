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
  const [showUpdate, setShowUpdate] = useState(false);
  const [showInstall, setShowInstall] = useState(false);
  const [deferredPrompt, setDeferredPrompt] = useState<any>(null);

  useEffect(() => {
    // Handle SW updates
    if (typeof window !== "undefined" && window.workbox) {
      const wb = window.workbox;
      const onWaiting = () => setShowUpdate(true);
      wb.addEventListener("waiting", onWaiting);
      wb.addEventListener("installed", (event: any) => {
        if (event?.isUpdate) setShowUpdate(true);
      });
    }

    // Handle PWA Install Prompt
    const handleBeforeInstallPrompt = (e: Event) => {
      e.preventDefault();
      setDeferredPrompt(e);
      setShowInstall(true);
    };

    window.addEventListener("beforeinstallprompt", handleBeforeInstallPrompt);

    return () => {
      window.removeEventListener("beforeinstallprompt", handleBeforeInstallPrompt);
    };
  }, []);

  const refreshToUpdate = async () => {
    const wb = window.workbox;
    if (wb) {
      setShowUpdate(false);
      await wb.messageSkipWaiting();
    }
    window.location.reload();
  };

  const handleInstallClick = async () => {
    if (!deferredPrompt) return;
    deferredPrompt.prompt();
    const { outcome } = await deferredPrompt.userChoice;
    if (outcome === "accepted") {
      setDeferredPrompt(null);
      setShowInstall(false);
    }
  };

  if (!showUpdate && !showInstall) return null;

  return (
    <div
      className={cn(
        "fixed left-1/2 z-[100] w-[calc(100%-24px)] max-w-md -translate-x-1/2",
        "bottom-4 sm:bottom-6",
      )}
      role="status"
      aria-live="polite"
    >
      {/* Update Available Toast */}
      {showUpdate && (
        <div className="rounded-2xl border bg-background shadow-lg px-4 py-3 flex items-center justify-between gap-3 mb-2">
          <div className="min-w-0">
            <p className="text-sm font-semibold">Update available</p>
            <p className="text-xs text-muted-foreground truncate">
              A newer version is ready.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Button size="sm" variant="outline" onClick={() => setShowUpdate(false)}>
              Later
            </Button>
            <Button size="sm" onClick={refreshToUpdate}>
              Refresh
            </Button>
          </div>
        </div>
      )}

      {/* Install App Toast */}
      {showInstall && !showUpdate && (
        <div className="rounded-2xl border bg-background shadow-lg px-4 py-3 flex items-center justify-between gap-3">
          <div className="min-w-0">
            <p className="text-sm font-semibold">Install App</p>
            <p className="text-xs text-muted-foreground truncate">
              Add to home screen for better experience
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Button size="sm" variant="outline" onClick={() => setShowInstall(false)}>
              Close
            </Button>
            <Button size="sm" onClick={handleInstallClick} className="bg-emerald-600 hover:bg-emerald-700 text-white">
              Install
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
