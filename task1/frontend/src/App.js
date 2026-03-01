import React, { useState, useEffect, useCallback } from 'react';

const API_BASE = process.env.REACT_APP_API_URL || '/api';

function App() {
    const [transactions, setTransactions] = useState([]);
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [showForm, setShowForm] = useState(false);
    const [apiStatus, setApiStatus] = useState('checking');

    // ── Fetch Transactions ────────────────────────────────────────
    const fetchTransactions = useCallback(async () => {
        try {
            const res = await fetch(`${API_BASE}/transactions`);
            if (!res.ok) throw new Error('Failed to fetch transactions');
            const data = await res.json();
            setTransactions(data);
            setError(null);
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    }, []);

    // ── Fetch Stats ───────────────────────────────────────────────
    const fetchStats = useCallback(async () => {
        try {
            const res = await fetch(`${API_BASE}/transactions/stats/summary`);
            if (!res.ok) return;
            const data = await res.json();
            setStats(data);
        } catch {
            // Stats are non-critical
        }
    }, []);

    // ── Health Check ──────────────────────────────────────────────
    const checkHealth = useCallback(async () => {
        try {
            const res = await fetch(`${API_BASE}/health`);
            const data = await res.json();
            setApiStatus(data.status === 'healthy' ? 'connected' : 'error');
        } catch {
            setApiStatus('disconnected');
        }
    }, []);

    useEffect(() => {
        checkHealth();
        fetchTransactions();
        fetchStats();
        const interval = setInterval(() => {
            fetchTransactions();
            fetchStats();
        }, 15000);
        return () => clearInterval(interval);
    }, [checkHealth, fetchTransactions, fetchStats]);

    // ── Create Transaction ────────────────────────────────────────
    const handleCreate = async (formData) => {
        try {
            const res = await fetch(`${API_BASE}/transactions`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(formData),
            });
            if (!res.ok) throw new Error('Failed to create transaction');
            setShowForm(false);
            fetchTransactions();
            fetchStats();
        } catch (err) {
            alert(err.message);
        }
    };

    return (
        <div className="app">
            {/* ── Header ────────────────────────────────────────────── */}
            <header className="header">
                <h1>💳 Dodo Payments</h1>
                <div className="status-badge">
                    <span className="dot"></span>
                    API: {apiStatus}
                </div>
            </header>

            {/* ── Stats Grid ────────────────────────────────────────── */}
            <div className="stats-grid">
                <div className="stat-card">
                    <div className="label">Total Transactions</div>
                    <div className="value blue">{stats?.total_transactions ?? '—'}</div>
                </div>
                <div className="stat-card">
                    <div className="label">Total Volume</div>
                    <div className="value">₹{stats?.total_amount?.toLocaleString('en-IN') ?? '—'}</div>
                </div>
                <div className="stat-card">
                    <div className="label">Completed</div>
                    <div className="value green">{stats?.completed_count ?? '—'}</div>
                </div>
                <div className="stat-card">
                    <div className="label">Failed</div>
                    <div className="value red">{stats?.failed_count ?? '—'}</div>
                </div>
            </div>

            {/* ── Transactions Table ────────────────────────────────── */}
            <div className="section-header">
                <h2>Recent Transactions</h2>
                <button className="btn btn-primary" onClick={() => setShowForm(true)}>
                    + New Transaction
                </button>
            </div>

            <div className="table-container">
                {loading ? (
                    <div className="loading">
                        <div className="spinner"></div> Loading transactions...
                    </div>
                ) : error ? (
                    <div className="error">⚠️ {error}</div>
                ) : transactions.length === 0 ? (
                    <div className="loading">No transactions yet. Create one to get started!</div>
                ) : (
                    <table>
                        <thead>
                            <tr>
                                <th>Transaction ID</th>
                                <th>Customer</th>
                                <th>Amount</th>
                                <th>Status</th>
                                <th>Date</th>
                            </tr>
                        </thead>
                        <tbody>
                            {transactions.map((txn) => (
                                <tr key={txn.id}>
                                    <td className="txn-id">{txn.transaction_id.slice(0, 8)}...</td>
                                    <td>
                                        <div>{txn.customer_name}</div>
                                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                                            {txn.customer_email}
                                        </div>
                                    </td>
                                    <td className="amount">
                                        {txn.currency === 'INR' ? '₹' : '$'}
                                        {txn.amount.toLocaleString('en-IN')}
                                    </td>
                                    <td>
                                        <span className={`status ${txn.status}`}>{txn.status}</span>
                                    </td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                                        {new Date(txn.created_at).toLocaleDateString('en-IN', {
                                            day: '2-digit',
                                            month: 'short',
                                            year: 'numeric',
                                        })}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>

            {/* ── Create Transaction Modal ──────────────────────────── */}
            {showForm && (
                <TransactionForm
                    onSubmit={handleCreate}
                    onClose={() => setShowForm(false)}
                />
            )}
        </div>
    );
}

/* ── Transaction Form Component ──────────────────────────────────── */
function TransactionForm({ onSubmit, onClose }) {
    const [form, setForm] = useState({
        customer_name: '',
        customer_email: '',
        amount: '',
        currency: 'INR',
        description: '',
    });

    const handleSubmit = (e) => {
        e.preventDefault();
        onSubmit({ ...form, amount: parseFloat(form.amount) });
    };

    const update = (field) => (e) =>
        setForm((f) => ({ ...f, [field]: e.target.value }));

    return (
        <div className="modal-overlay" onClick={onClose}>
            <div className="modal" onClick={(e) => e.stopPropagation()}>
                <h3>New Transaction</h3>
                <form onSubmit={handleSubmit}>
                    <div className="form-group">
                        <label>Customer Name</label>
                        <input
                            required
                            value={form.customer_name}
                            onChange={update('customer_name')}
                            placeholder="John Doe"
                        />
                    </div>
                    <div className="form-group">
                        <label>Email</label>
                        <input
                            type="email"
                            required
                            value={form.customer_email}
                            onChange={update('customer_email')}
                            placeholder="john@example.com"
                        />
                    </div>
                    <div className="form-group">
                        <label>Amount (INR)</label>
                        <input
                            type="number"
                            step="0.01"
                            min="0.01"
                            required
                            value={form.amount}
                            onChange={update('amount')}
                            placeholder="1000.00"
                        />
                    </div>
                    <div className="form-group">
                        <label>Description</label>
                        <input
                            value={form.description}
                            onChange={update('description')}
                            placeholder="Payment for..."
                        />
                    </div>
                    <div className="modal-actions">
                        <button type="button" className="btn btn-secondary" onClick={onClose}>
                            Cancel
                        </button>
                        <button type="submit" className="btn btn-primary">
                            Create Payment
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
}

export default App;
