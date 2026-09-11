// REQ-ID: REQ-UI-001
import React from 'react';

export function Dashboard() {
  return (
    <div className="dashboard">
      <h1>Dashboard</h1>
      {/* Missing aria-label on icon buttons */}
      <button className="icon-btn" onClick={handleRefresh}>
        <svg>...</svg>
      </button>
      <button className="icon-btn iconButton" onClick={handleSettings}>
        <svg>...</svg>
      </button>
      <nav aria-label="Main navigation">
        <a href="/home">Home</a>
        <a href="/settings">Settings</a>
      </nav>
    </div>
  );
}
