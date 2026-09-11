// QD7 Fixture neg-02 — negative case (0 signals expected)
// Demonstrates: functional component with hooks — modern React data-fetching pattern

import React, { useEffect, useState } from 'react';

interface DataState {
  data: string;
  loading: boolean;
  error: string | null;
}

export function ModernDataFetcher() {
  const [state, setState] = useState<DataState>({
    data: '',
    loading: false,
    error: null,
  });

  useEffect(() => {
    setState(s => ({ ...s, loading: true }));
    fetch('/api/data')
      .then(r => r.json())
      .then(d => setState({ data: d.value, loading: false, error: null }))
      .catch(err => setState(s => ({ ...s, loading: false, error: err.message })));
  }, []);

  if (state.loading) return <div>Loading...</div>;
  if (state.error) return <div>Error: {state.error}</div>;
  return <div>{state.data}</div>;
}

export default ModernDataFetcher;
