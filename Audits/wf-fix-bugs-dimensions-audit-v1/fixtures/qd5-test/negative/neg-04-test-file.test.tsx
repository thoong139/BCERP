import React from 'react';

// File path contains .test. so probe EXCLUDE_PATTERN drops every check.
// The markup below would normally fire 5 signals; under exclusion it fires 0.
export function BadMarkupOnlyForTesting() {
  return (
    <div>
      <img src="/no-alt.png" />
      <input type="text" name="x" />
      <button tabindex="3">Z</button>
      <div role="buttonn">X</div>
      <a href="#">Y</a>
    </div>
  );
}
