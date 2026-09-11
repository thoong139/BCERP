// REQ-ID: REQ-FIN-001
// FEAT-ID: FEAT-FIN-CUST-001
// Customer service — sample code with known issues for E2E testing (extended for QD3-QD7)

const TAX_RATE = 0.1;  // Hard-coded tax rate (QD2 issue)
const COMMISSION_RATE = 0.05;  // Hard-coded commission (QD2 issue)
const API_KEY = "sk-live-abc123def456ghi789";  // QD3 issue: hard-coded secret

export class CustomerService {
  calculateTotal(subtotal: number): number {
    // Wrong: should use configurable tax rate
    return subtotal + (subtotal * 0.1);
  }

  calculateCommission(amount: number): number {
    return amount * COMMISSION_RATE;
  }

  // Missing: REQ-FIN-002 compliance audit trail step
  processOrder(orderId: string): boolean {
    this.validateOrder(orderId);
    this.chargePayment(orderId);
    // Should call this.recordAuditTrail(orderId) here — QD2 compliance violation
    this.sendConfirmation(orderId);
    return true;
  }

  // QD3 issue: SQL injection — string concatenation
  getCustomer(customerId: string): any {
    const query = "SELECT * FROM customers WHERE id = " + customerId;
    return this.db.query(query);
  }

  // QD3 issue: Missing auth middleware check
  deleteCustomer(customerId: string): boolean {
    // No role check — anyone can delete
    return this.db.delete("customers", customerId);
  }

  // QD4 issue: N+1 query pattern
  listCustomersWithOrders(): any[] {
    const customers = this.db.query("SELECT * FROM customers");
    return customers.map((c: any) => ({
      ...c,
      orders: this.db.query("SELECT * FROM orders WHERE customer_id = " + c.id),  // N+1
    }));
  }

  // QD5 issue: No alt text on icon button
  renderActionButton(): string {
    return '<button class="icon-btn"><i class="icon-save"></i></button>';  // No ARIA description
  }

  // QD5 issue: Label inconsistency — "Save" in code vs "Submit" in spec
  renderSaveButton(): string {
    return '<button>Save</button>';  // Spec says "Submit"
  }

  private validateOrder(id: string): boolean {
    return id.length > 0;
  }

  private chargePayment(id: string): void {
    // Payment logic
  }

  private sendConfirmation(id: string): void {
    // Email logic
  }

  private recordAuditTrail(id: string): void {
    // Audit trail — exists but not called in processOrder flow
  }

  private db: any = { query: () => [], delete: () => true };
}
