// QD4 pos-04 — Unbounded query fixture
// Probe: P-QD4-db-query-analysis (Check 2: findMany/findAll without take/limit)
// Expected signal: unbounded_query HIGH

const prisma = {
  user: {
    async findMany(args?: object): Promise<any[]> { return []; },
    async findAll(args?: object): Promise<any[]> { return []; },
    async find(args?: object): Promise<any[]> { return []; },
  },
  order: {
    async findMany(args?: object): Promise<any[]> { return []; },
  },
};

// BAD: loads entire users table into memory
export async function getAllUsers(): Promise<any[]> {
  return await prisma.user.findMany();
}

// BAD: another unbounded pattern
export async function getAllOrders(): Promise<any[]> {
  const orders = await prisma.order.findMany();
  return orders;
}

// BAD: findAll without any limit constraint
export async function listAllUsers(): Promise<any[]> {
  return await prisma.user.findAll();
}
