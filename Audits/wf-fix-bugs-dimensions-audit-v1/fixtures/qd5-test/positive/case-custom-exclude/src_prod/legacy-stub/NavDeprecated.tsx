// Legacy nav component - being phased out
// REQ-ID: REQ-NAV-LEGACY-001
import React from 'react';

// A11y issue: img without alt attribute
export const LegacyNavLogo = () => (
  <div>
    <img src="/legacy-logo.png" />
    <span>Legacy Nav</span>
  </div>
);
