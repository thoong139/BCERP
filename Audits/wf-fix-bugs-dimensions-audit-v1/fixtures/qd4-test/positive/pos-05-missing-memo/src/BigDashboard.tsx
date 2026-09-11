// QD4 pos-05 — Large component without memoization fixture
// Probe: P-QD4-render-perf-check (Check 1: >300 lines, no React memoization wrapper)
// Expected signal: missing_memo MEDIUM
// 384 lines, export default function, no memoization applied

import React, { useState } from 'react';

interface User {
  id: string;
  name: string;
  email: string;
  role: string;
  department: string;
  createdAt: string;
  status: 'active' | 'inactive' | 'suspended';
}

interface Order {
  id: string;
  userId: string;
  total: number;
  status: 'pending' | 'shipped' | 'delivered' | 'cancelled';
  items: OrderItem[];
  createdAt: string;
}

interface OrderItem {
  productId: string;
  name: string;
  quantity: number;
  price: number;
}

interface DashboardStats {
  totalUsers: number;
  activeUsers: number;
  totalRevenue: number;
  pendingOrders: number;
  deliveredOrders: number;
  averageOrderValue: number;
}

interface DashboardProps {
  userId: string;
  title: string;
  initialTab?: TabType;
}

type TabType = 'overview' | 'users' | 'orders' | 'settings';
type SortDir = 'asc' | 'desc';

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);
}

function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric', month: 'short', day: 'numeric',
  });
}

function getStatusColor(status: Order['status']): string {
  const colors: Record<Order['status'], string> = {
    pending: '#f59e0b',
    shipped: '#3b82f6',
    delivered: '#10b981',
    cancelled: '#ef4444',
  };
  return colors[status] ?? '#6b7280';
}

function getUserStatusBadgeClass(status: User['status']): string {
  const classes: Record<User['status'], string> = {
    active: 'badge-green',
    inactive: 'badge-gray',
    suspended: 'badge-red',
  };
  return classes[status] ?? 'badge-gray';
}

function computeStats(users: User[], orders: Order[]): DashboardStats {
  const totalRevenue = orders.reduce((sum, o) => sum + o.total, 0);
  const pending = orders.filter(o => o.status === 'pending').length;
  const delivered = orders.filter(o => o.status === 'delivered').length;
  const active = users.filter(u => u.status === 'active').length;
  return {
    totalUsers: users.length,
    activeUsers: active,
    totalRevenue,
    pendingOrders: pending,
    deliveredOrders: delivered,
    averageOrderValue: orders.length > 0 ? totalRevenue / orders.length : 0,
  };
}

// Large component without memoization wrapper — triggers P-QD4-render-perf-check
export default function BigDashboard({ userId, title, initialTab = 'overview' }: DashboardProps) {
  const [activeTab, setActiveTab] = useState<TabType>(initialTab);
  const [users, setUsers] = useState<User[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [sortField, setSortField] = useState<keyof User>('name');
  const [sortDir, setSortDir] = useState<SortDir>('asc');
  const [page, setPage] = useState(1);
  const [pageSize] = useState(20);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [filterDept, setFilterDept] = useState('');
  const [filterStatus, setFilterStatus] = useState<User['status'] | ''>('');
  const [dateStart, setDateStart] = useState('');
  const [dateEnd, setDateEnd] = useState('');
  const [showExportModal, setShowExportModal] = useState(false);

  const stats = computeStats(users, orders);

  const filteredUsers = users.filter(u => {
    const matchSearch = u.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      u.email.toLowerCase().includes(searchQuery.toLowerCase());
    const matchDept = filterDept === '' || u.department === filterDept;
    const matchStatus = filterStatus === '' || u.status === filterStatus;
    return matchSearch && matchDept && matchStatus;
  });

  const sortedUsers = [...filteredUsers].sort((a, b) => {
    const aVal = String(a[sortField]);
    const bVal = String(b[sortField]);
    const dir = sortDir === 'asc' ? 1 : -1;
    return aVal < bVal ? -dir : aVal > bVal ? dir : 0;
  });

  const paginatedUsers = sortedUsers.slice((page - 1) * pageSize, page * pageSize);
  const totalPages = Math.max(1, Math.ceil(filteredUsers.length / pageSize));
  const departments = Array.from(new Set(users.map(u => u.department))).sort();

  const handleTabChange = (tab: TabType) => { setActiveTab(tab); setPage(1); };
  const handleSearch = (e: React.ChangeEvent<HTMLInputElement>) => { setSearchQuery(e.target.value); setPage(1); };
  const handleSort = (field: keyof User) => {
    if (sortField === field) {
      setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDir('asc');
    }
  };
  const handleUserSelect = (id: string) => setSelectedUserId(prev => prev === id ? null : id);
  const handleClearFilters = () => {
    setSearchQuery('');
    setFilterDept('');
    setFilterStatus('');
    setPage(1);
  };
  const handleExport = () => {
    const header = ['Name', 'Email', 'Role', 'Department', 'Status', 'Created'];
    const rows = filteredUsers.map(u => [
      u.name, u.email, u.role, u.department, u.status, formatDate(u.createdAt)
    ]);
    const csv = [header, ...rows].map(r => r.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `users-export-${Date.now()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
    setShowExportModal(false);
  };

  const renderOverview = () => (
    <div className="overview-grid">
      <div className="stat-card stat-primary">
        <span className="stat-icon">👥</span>
        <div className="stat-content">
          <span className="stat-label">Total Users</span>
          <span className="stat-value">{stats.totalUsers.toLocaleString()}</span>
          <span className="stat-sub">{stats.activeUsers} active</span>
        </div>
      </div>
      <div className="stat-card stat-success">
        <span className="stat-icon">💰</span>
        <div className="stat-content">
          <span className="stat-label">Total Revenue</span>
          <span className="stat-value">{formatCurrency(stats.totalRevenue)}</span>
          <span className="stat-sub">avg {formatCurrency(stats.averageOrderValue)}/order</span>
        </div>
      </div>
      <div className="stat-card stat-warning">
        <span className="stat-icon">⏳</span>
        <div className="stat-content">
          <span className="stat-label">Pending Orders</span>
          <span className="stat-value">{stats.pendingOrders}</span>
          <span className="stat-sub">awaiting processing</span>
        </div>
      </div>
      <div className="stat-card stat-info">
        <span className="stat-icon">✅</span>
        <div className="stat-content">
          <span className="stat-label">Delivered</span>
          <span className="stat-value">{stats.deliveredOrders}</span>
          <span className="stat-sub">completed orders</span>
        </div>
      </div>
    </div>
  );

  const renderUserTable = () => (
    <div className="table-container">
      <div className="table-toolbar">
        <div className="toolbar-filters">
          <input
            type="text" placeholder="Search by name or email..."
            value={searchQuery} onChange={handleSearch} className="search-input"
          />
          <select value={filterDept} onChange={e => { setFilterDept(e.target.value); setPage(1); }} className="filter-select">
            <option value="">All Departments</option>
            {departments.map(d => <option key={d} value={d}>{d}</option>)}
          </select>
          <select value={filterStatus} onChange={e => { setFilterStatus(e.target.value as User['status'] | ''); setPage(1); }} className="filter-select">
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="suspended">Suspended</option>
          </select>
          {(searchQuery || filterDept || filterStatus) && (
            <button onClick={handleClearFilters} className="btn-secondary">Clear Filters</button>
          )}
        </div>
        <div className="toolbar-actions">
          <span className="result-count">{filteredUsers.length} users</span>
          <button onClick={() => setShowExportModal(true)} className="btn-primary">Export CSV</button>
        </div>
      </div>
      <table className="data-table">
        <thead>
          <tr>
            {(['name', 'email', 'role', 'department', 'status', 'createdAt'] as const).map(field => (
              <th key={field} onClick={() => handleSort(field)} className="th-sortable">
                {field === 'createdAt' ? 'Created' : field.charAt(0).toUpperCase() + field.slice(1)}
                {sortField === field && <span className="sort-indicator">{sortDir === 'asc' ? ' ↑' : ' ↓'}</span>}
              </th>
            ))}
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {paginatedUsers.length === 0 ? (
            <tr><td colSpan={7} className="empty-row">No users found</td></tr>
          ) : paginatedUsers.map(user => (
            <tr key={user.id} className={selectedUserId === user.id ? 'row-selected' : ''} onClick={() => handleUserSelect(user.id)}>
              <td className="td-name">{user.name}</td>
              <td className="td-email">{user.email}</td>
              <td><span className="role-badge">{user.role}</span></td>
              <td>{user.department}</td>
              <td><span className={`status-badge ${getUserStatusBadgeClass(user.status)}`}>{user.status}</span></td>
              <td>{formatDate(user.createdAt)}</td>
              <td className="td-actions">
                <button className="btn-link" onClick={e => { e.stopPropagation(); handleUserSelect(user.id); }}>
                  {selectedUserId === user.id ? 'Deselect' : 'Select'}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className="pagination-bar">
        <button className="btn-page" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>← Prev</button>
        <span className="page-info">Page {page} of {totalPages} ({filteredUsers.length} total)</span>
        <button className="btn-page" disabled={page >= totalPages} onClick={() => setPage(p => p + 1)}>Next →</button>
      </div>
    </div>
  );

  const renderOrders = () => (
    <div className="orders-panel">
      <div className="orders-header">
        <h3>Orders {selectedUserId ? `(filtered: user ${selectedUserId})` : '(all users)'}</h3>
        <span className="orders-count">{orders.length} total</span>
      </div>
      <div className="orders-list">
        {orders
          .filter(o => !selectedUserId || o.userId === selectedUserId)
          .map(order => (
            <div key={order.id} className="order-card">
              <div className="order-card-header">
                <span className="order-id">#{order.id.slice(0, 8)}</span>
                <span className="order-status" style={{ color: getStatusColor(order.status) }}>
                  {order.status.toUpperCase()}
                </span>
                <span className="order-total">{formatCurrency(order.total)}</span>
                <span className="order-date">{formatDate(order.createdAt)}</span>
              </div>
              <div className="order-items-list">
                {order.items.map(item => (
                  <div key={item.productId} className="order-item-row">
                    <span className="item-name">{item.name}</span>
                    <span className="item-qty">×{item.quantity}</span>
                    <span className="item-price">{formatCurrency(item.price)}</span>
                    <span className="item-subtotal">{formatCurrency(item.price * item.quantity)}</span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        {orders.filter(o => !selectedUserId || o.userId === selectedUserId).length === 0 && (
          <div className="orders-empty">No orders found</div>
        )}
      </div>
    </div>
  );

  const renderSettings = () => (
    <div className="settings-panel">
      <div className="settings-section">
        <h3>Date Range</h3>
        <label className="settings-label">
          Start:
          <input type="date" value={dateStart} onChange={e => setDateStart(e.target.value)} className="date-input" />
        </label>
        <label className="settings-label">
          End:
          <input type="date" value={dateEnd} onChange={e => setDateEnd(e.target.value)} className="date-input" />
        </label>
      </div>
      <div className="settings-section">
        <h3>Pagination</h3>
        <p>Items per page: {pageSize}</p>
        <p>Current page: {page} of {totalPages}</p>
      </div>
      <div className="settings-section">
        <h3>Session Info</h3>
        <p>Logged in as: {userId}</p>
        <p>Viewing: {title}</p>
      </div>
    </div>
  );

  if (loading) return <div className="loading-spinner">Loading {title}...</div>;
  if (error) return <div className="error-banner">Error: {error} <button onClick={() => setError(null)}>Dismiss</button></div>;

  return (
    <div className="dashboard-root">
      <header className="dashboard-header">
        <h1 className="dashboard-title">{title}</h1>
        <div className="header-meta">
          <span>User: {userId}</span>
          <span>{new Date().toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}</span>
        </div>
      </header>

      <nav className="dashboard-nav" aria-label="Dashboard navigation">
        {(['overview', 'users', 'orders', 'settings'] as TabType[]).map(tab => (
          <button
            key={tab}
            className={`nav-tab ${activeTab === tab ? 'nav-tab-active' : ''}`}
            onClick={() => handleTabChange(tab)}
            aria-current={activeTab === tab ? 'page' : undefined}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </nav>

      <main className="dashboard-main">
        {activeTab === 'overview' && renderOverview()}
        {activeTab === 'users' && renderUserTable()}
        {activeTab === 'orders' && renderOrders()}
        {activeTab === 'settings' && renderSettings()}
      </main>

      {showExportModal && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-box">
            <h2>Export Users</h2>
            <p>Export {filteredUsers.length} filtered users as CSV?</p>
            <div className="modal-actions">
              <button className="btn-primary" onClick={handleExport}>Download CSV</button>
              <button className="btn-secondary" onClick={() => setShowExportModal(false)}>Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
