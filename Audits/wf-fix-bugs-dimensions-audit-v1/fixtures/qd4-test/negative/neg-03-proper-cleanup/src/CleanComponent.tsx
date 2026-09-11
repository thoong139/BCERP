// QD4 neg-03 — Proper event listener cleanup (no leak)
// Probe: P-QD4-memory-leak-scan (Check 1: addEventListener vs removeEventListener)
// Expected: NO signal — addEventListener count == removeEventListener count
// Check 3: has `return.*removeEventListener` => skip => no signal

import React, { useEffect, useState } from 'react';

interface CleanComponentProps {
  onResize?: (width: number) => void;
}

// GOOD: addEventListener and removeEventListener are balanced (1:1)
// useEffect returns cleanup function with removeEventListener
export default function CleanComponent({ onResize }: CleanComponentProps) {
  const [windowWidth, setWindowWidth] = useState(
    typeof window !== 'undefined' ? window.innerWidth : 1024
  );

  useEffect(() => {
    const handleResize = () => {
      const width = window.innerWidth;
      setWindowWidth(width);
      onResize?.(width);
    };

    window.addEventListener('resize', handleResize);

    // Proper cleanup — removeEventListener called on unmount
    return () => {
      window.removeEventListener('resize', handleResize);
    };
  }, [onResize]);

  return (
    <div>
      <p>Window width: {windowWidth}px</p>
    </div>
  );
}
