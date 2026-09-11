// REQ-ID: REQ-ORD-001
// FEAT-ID: FEAT-ORD-CREATE-001
export class OrderService {
  private TAX_RATE = 0.1;
  private COMMISSION_RATE = 0.05;

  calculateTotal(items: any[]): number {
    // Business logic: tax calculation
    const subtotal = items.reduce((sum, item) => sum + item.price * item.qty, 0);
    return subtotal * (1 + this.TAX_RATE);
  }

  // Deprecated: use OrderServiceV2 instead
  processOrder(orderId: string) {
    console.log(`Processing order ${orderId}`);
  }
}

// Unversioned endpoint
app.post('/api/orders', (req, res) => {
  res.json({ status: 'created' });
});
