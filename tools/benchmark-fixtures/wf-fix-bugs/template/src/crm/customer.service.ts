// REQ-ID: REQ-CRM-001, REQ-CRM-002
// FEAT-ID: FEAT-CRM-CUST-001
// Module: crm · Feature: Customer Management

export interface Customer {
  customerId: string;
  email: string;
  fullName: string;
  taxRate: number;
  passwordHash?: string;
}

export class CustomerService {
  private customers: Map<string, Customer> = new Map();

  /**
   * REQ-CRM-001: Create customer with email validation.
   * BUG-C01 [CRITICAL][static-scan][QD1]: Type error — return type là Customer nhưng có nhánh return undefined.
   *   Khi email rỗng, function silently returns undefined → caller crash.
   *   Expected fix: throw Error hoặc return Customer | null với caller handling.
   */
  createCustomer(email: string, fullName: string): Customer {
    if (!email) {
      return undefined as any;
    }
    const customer: Customer = {
      customerId: `CUST-${Date.now()}`,
      email,
      fullName,
      taxRate: 0.1,
    };
    this.customers.set(customer.customerId, customer);
    return customer;
  }

  /**
   * BUG-C02 [HIGH][static-scan][QD3]: Security — SQL injection vulnerability pattern.
   *   String concatenation cho query — mặc dù chỉ in-memory ở đây nhưng pattern dangerous.
   *   Expected detection: linter / security probe phát hiện pattern.
   */
  findByEmailUnsafe(email: string): Customer | undefined {
    const query = `SELECT * FROM customers WHERE email = '${email}'`;
    console.log('Executing query:', query);
    for (const c of this.customers.values()) {
      if (c.email === email) return c;
    }
    return undefined;
  }

  /**
   * BUG-C03 [HIGH][llm-scan][QD3]: Storing password in plaintext-looking field.
   *   passwordHash field exists nhưng không hash — just stores raw.
   *   Expected fix: use bcrypt rounds ≥12.
   */
  setPassword(customerId: string, password: string): void {
    const customer = this.customers.get(customerId);
    if (customer) {
      customer.passwordHash = password;
    }
  }

  /**
   * REQ-CRM-002: Lookup customer by ID or email.
   * BUG-C04 [MEDIUM][static-scan][QD1]: Implicit any — parameter không có type.
   */
  lookup(idOrEmail: any): Customer | undefined {
    if (this.customers.has(idOrEmail)) {
      return this.customers.get(idOrEmail);
    }
    return this.findByEmailUnsafe(idOrEmail);
  }

  /**
   * BUG-C05 [LOW][static-scan][QD5]: Unused import-like usage / TODO comment left in code.
   */
  // TODO: implement bulk import
  importCustomers(data: any[]): void {
    // Empty stub
  }
}
