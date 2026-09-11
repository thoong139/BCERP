// Production file that happens to have .test. in name (integration spec embedded in prod)
// REQ-ID: REQ-NAV-001
import React from 'react';

// A11y issue: img without alt attribute
export const NavLogo = () => (
  <div>
    <img src="/logo.png" />
    <nav>Home</nav>
  </div>
);
