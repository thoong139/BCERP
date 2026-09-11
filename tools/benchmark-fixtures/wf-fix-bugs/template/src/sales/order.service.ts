// REQ-ID: REQ-SALES-001, REQ-SALES-002, REQ-SALES-003
// FEAT-ID: FEAT-SALES-ORDER-001
// Module: sales · Feature: Order Management

import { Customer } from '../crm/customer.service';

export type OrderStatus = 'PENDING' | 'CONFIRMED' | 'SHIPPED' | 'CANCELLED';

export interface OrderItem {
  productId: string;
  quantity: number;
  price: number;
}

export interface Order {
  orderId: string;
  customer: Customer;
  items: OrderItem[];
  status: OrderStatus;
  createdAt: Date;
}

export class OrderService {
  /**
   * REQ-SALES-001: Calculate total with customer tax rate.
   * BUG-S01 [CRITICAL][static-scan][QD1]: Null reference — không check customer trước khi access taxRate.
   *   Khi customer=null hoặc undefined → throws TypeError tại runtime.
   *   Expected fix: add null guard hoặc default tax rate.
   */
  calculateTotal(order: Order): number {
    const taxRate = order.customer.taxRate;
    return order.items.reduce(
      (sum, item) => sum + item.price * item.quantity * (1 + taxRate),
      0
    );
  }

  /**
   * REQ-SALES-002: Apply percentage discount.
   * BUG-S02 [HIGH][llm-scan][QD2]: Discount calculated wrong — subtract pct as raw number.
   *   discount=10 (meaning 10%) → result = total - 10 (wrong, should be total * 0.9).
   *   Expected fix: total * (1 - discountPct / 100).
   */
  applyDiscount(total: number, discountPct: number): number {
    return total - discountPct;
  }

  /**
   * REQ-SALES-003: Cancel order (only when PENDING).
   * BUG-S03 [HIGH][llm-scan][QD2,QD11]: Missing business rule validation.
   *   Should check: order.status === 'PENDING' trước khi cho cancel.
   *   Currently: cancel any order regardless of status.
   */
  cancelOrder(order: Order): Order {
    return { ...order, status: 'CANCELLED' };
  }

  /**
   * BUG-S04 [MEDIUM][static-scan][QD1]: Missing type annotation on parameter.
   *   Should be: price: number.
   */
  formatPrice(price: any): string {
    return `$${price.toFixed(2)}`;
  }

  /**
   * BUG-S05 [LOW][static-scan][QD5]: Unused variable (lint warning).
   */
  generateOrderId(): string {
    const timestamp = Date.now();
    const random = Math.random();
    return `ORD-${timestamp}`;
  }
}
