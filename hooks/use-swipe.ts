"use client";

import { useRef, useState, useCallback, TouchEvent } from "react";

interface SwipeHandlers {
  onSwipeLeft?: () => void;
  onSwipeRight?: () => void;
  onSwipeUp?: () => void;
  onSwipeDown?: () => void;
}

interface SwipeState {
  isSwiping: boolean;
  direction: "left" | "right" | "up" | "down" | null;
  deltaX: number;
  deltaY: number;
}

interface UseSwipeOptions {
  threshold?: number; // Minimum distance to trigger swipe
  preventDefaultOnSwipe?: boolean;
}

export function useSwipe(
  handlers: SwipeHandlers,
  options: UseSwipeOptions = {}
) {
  const { threshold = 50, preventDefaultOnSwipe = false } = options;
  
  const touchStart = useRef<{ x: number; y: number } | null>(null);
  const touchEnd = useRef<{ x: number; y: number } | null>(null);
  
  const [swipeState, setSwipeState] = useState<SwipeState>({
    isSwiping: false,
    direction: null,
    deltaX: 0,
    deltaY: 0,
  });

  const onTouchStart = useCallback((e: TouchEvent) => {
    touchEnd.current = null;
    touchStart.current = {
      x: e.targetTouches[0].clientX,
      y: e.targetTouches[0].clientY,
    };
    setSwipeState({
      isSwiping: true,
      direction: null,
      deltaX: 0,
      deltaY: 0,
    });
  }, []);

  const onTouchMove = useCallback((e: TouchEvent) => {
    if (!touchStart.current) return;
    
    const currentX = e.targetTouches[0].clientX;
    const currentY = e.targetTouches[0].clientY;
    
    touchEnd.current = { x: currentX, y: currentY };
    
    const deltaX = currentX - touchStart.current.x;
    const deltaY = currentY - touchStart.current.y;
    
    // Determine swipe direction based on which axis has more movement
    let direction: "left" | "right" | "up" | "down" | null = null;
    
    if (Math.abs(deltaX) > Math.abs(deltaY)) {
      direction = deltaX > 0 ? "right" : "left";
    } else {
      direction = deltaY > 0 ? "down" : "up";
    }
    
    setSwipeState({
      isSwiping: true,
      direction,
      deltaX,
      deltaY,
    });
    
    // Prevent default scrolling if swiping horizontally
    if (preventDefaultOnSwipe && Math.abs(deltaX) > Math.abs(deltaY)) {
      e.preventDefault();
    }
  }, [preventDefaultOnSwipe]);

  const onTouchEnd = useCallback(() => {
    if (!touchStart.current || !touchEnd.current) {
      setSwipeState({
        isSwiping: false,
        direction: null,
        deltaX: 0,
        deltaY: 0,
      });
      return;
    }
    
    const deltaX = touchEnd.current.x - touchStart.current.x;
    const deltaY = touchEnd.current.y - touchStart.current.y;
    const absX = Math.abs(deltaX);
    const absY = Math.abs(deltaY);
    
    // Only trigger if movement exceeds threshold
    if (absX > threshold || absY > threshold) {
      if (absX > absY) {
        // Horizontal swipe
        if (deltaX > 0) {
          handlers.onSwipeRight?.();
        } else {
          handlers.onSwipeLeft?.();
        }
      } else {
        // Vertical swipe
        if (deltaY > 0) {
          handlers.onSwipeDown?.();
        } else {
          handlers.onSwipeUp?.();
        }
      }
    }
    
    touchStart.current = null;
    touchEnd.current = null;
    
    setSwipeState({
      isSwiping: false,
      direction: null,
      deltaX: 0,
      deltaY: 0,
    });
  }, [handlers, threshold]);

  return {
    handlers: {
      onTouchStart,
      onTouchMove,
      onTouchEnd,
    },
    swipeState,
  };
}
