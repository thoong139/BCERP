// QD4 neg-04 — Parameterized SQL (no unbounded query)
// Probe: P-QD4-db-query-analysis (Check 2: ORM unbounded pattern)
// Expected: NO signal — uses rawQuery with $1 param and LIMIT clause

interface QueryResult<T> {
  rows: T[];
  rowCount: number;
}

const db = {
  async rawQuery<T>(sql: string, params: any[]): Promise<QueryResult<T>> {
    return { rows: [], rowCount: 0 };
  },
};

// GOOD: Parameterized query with LIMIT — no unbounded result set
export async function findUserById(userId: string): Promise<any | null> {
  const result = await db.rawQuery<any>(
    'SELECT id, name, email, role FROM users WHERE id = $1 LIMIT 1',
    [userId]
  );
  return result.rows[0] ?? null;
}

// GOOD: Multiple params + ORDER BY LIMIT
export async function findUsersByDepartment(dept: string, limit: number): Promise<any[]> {
  const result = await db.rawQuery<any>(
    'SELECT id, name, email FROM users WHERE department = $1 ORDER BY name LIMIT $2',
    [dept, limit]
  );
  return result.rows;
}

// GOOD: Paginated query with explicit LIMIT and OFFSET
export async function listUsers(offset: number, limit: number): Promise<any[]> {
  const result = await db.rawQuery<any>(
    'SELECT id, name, email, status FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2',
    [limit, offset]
  );
  return result.rows;
}
