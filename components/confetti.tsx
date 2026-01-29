"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";

interface ConfettiPiece {
  id: number;
  left: number;
  color: string;
  delay: number;
  rotation: number;
}

const CONFETTI_COLORS = [
  "#10b981", // emerald
  "#06b6d4", // cyan
  "#3b82f6", // blue
  "#8b5cf6", // violet
  "#f59e0b", // amber
  "#ef4444", // red
  "#ec4899", // pink
];

export function Confetti({ duration = 3000 }: { duration?: number }) {
  const [pieces, setPieces] = useState<ConfettiPiece[]>([]);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    
    // Generate confetti pieces
    const newPieces: ConfettiPiece[] = [];
    for (let i = 0; i < 50; i++) {
      newPieces.push({
        id: i,
        left: Math.random() * 100,
        color: CONFETTI_COLORS[Math.floor(Math.random() * CONFETTI_COLORS.length)],
        delay: Math.random() * 500,
        rotation: Math.random() * 360,
      });
    }
    setPieces(newPieces);

    // Clear confetti after duration
    const timer = setTimeout(() => {
      setPieces([]);
    }, duration);

    return () => clearTimeout(timer);
  }, [duration]);

  if (!mounted || pieces.length === 0) return null;

  return createPortal(
    <div className="fixed inset-0 pointer-events-none overflow-hidden z-[9999]">
      {pieces.map((piece) => (
        <div
          key={piece.id}
          className="confetti-piece"
          style={{
            left: `${piece.left}%`,
            backgroundColor: piece.color,
            animationDelay: `${piece.delay}ms`,
            transform: `rotate(${piece.rotation}deg)`,
            borderRadius: Math.random() > 0.5 ? "50%" : "2px",
          }}
        />
      ))}
    </div>,
    document.body
  );
}

export function useConfetti() {
  const [showConfetti, setShowConfetti] = useState(false);

  const triggerConfetti = () => {
    setShowConfetti(true);
    setTimeout(() => setShowConfetti(false), 3000);
  };

  return { showConfetti, triggerConfetti, ConfettiComponent: showConfetti ? Confetti : null };
}
