"use client";

import { useEffect } from "react";

const RESET_KEY = "money-master-dev-sw-reset-v1";

export function DevServiceWorkerReset() {
  useEffect(() => {
    if (process.env.NODE_ENV !== "development") return;
    if (sessionStorage.getItem(RESET_KEY)) return;

    sessionStorage.setItem(RESET_KEY, "1");

    const resetServiceWorker = async () => {
      const registrations =
        "serviceWorker" in navigator
          ? await navigator.serviceWorker.getRegistrations()
          : [];
      const cacheKeys = "caches" in window ? await caches.keys() : [];

      await Promise.all([
        ...registrations.map((registration) => registration.unregister()),
        ...cacheKeys.map((key) => caches.delete(key)),
      ]);

      if (registrations.length > 0 || cacheKeys.length > 0) {
        window.location.reload();
      }
    };

    resetServiceWorker().catch((error) => {
      console.warn("[dev] Unable to reset service worker caches:", error);
    });
  }, []);

  return null;
}
