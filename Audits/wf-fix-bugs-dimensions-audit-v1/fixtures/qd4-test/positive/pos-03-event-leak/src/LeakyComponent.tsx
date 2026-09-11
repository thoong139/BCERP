// QD4 pos-03 — Event listener leak fixture
// Probe: P-QD4-memory-leak-scan (Check 1: add_count > remove_count)
// Expected signal: event_listener_leak HIGH
// IS_FRONTEND=true (package.json has "react")
// add_count=3, remove_count=0 => 3 > 0 => HIGH signal

import React, { useEffect, useState } from 'react';

interface LeakyComponentProps {
  title: string;
}

// BAD: event listeners attached but never removed — memory leak on unmount
export default function LeakyComponent({ title }: LeakyComponentProps) {
  const [clicks, setClicks] = useState(0);
  const [scrollPos, setScrollPos] = useState(0);

  useEffect(() => {
    document.addEventListener('click', () => {
      setClicks(c => c + 1);
    });

    document.addEventListener('scroll', () => {
      setScrollPos(window.scrollY);
    });

    window.addEventListener('resize', () => {
      console.log('resized');
    });

    // No cleanup returned — all 3 listeners leak on unmount
  }, []);

  return (
    <div>
      <h1>{title}</h1>
      <p>Clicks: {clicks}</p>
      <p>Scroll: {scrollPos}px</p>
    </div>
  );
}
