// QD7 Fixture pos-02 — positive case (HIGH signal expected)
// Demonstrates: class component with unsafe legacy lifecycle method

import React from 'react';

interface State {
  data: string;
  loading: boolean;
}

class LegacyDataFetcher extends React.Component<{}, State> {
  state: State = { data: '', loading: false };

  componentWillMount() {
    this.setState({ loading: true });
    fetch('/api/data')
      .then(r => r.json())
      .then(d => this.setState({ data: d.value, loading: false }));
  }

  render() {
    return <div>{this.state.loading ? 'Loading...' : this.state.data}</div>;
  }
}

export default LegacyDataFetcher;
