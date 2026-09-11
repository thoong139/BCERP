// REQ-ID: REQ-SALES-004, REQ-SALES-005
// FEAT-ID: FEAT-SALES-QUOT-001
// Module: sales · Feature: Quotation Management

import { Customer } from '../crm/customer.service';
import { Order, OrderItem } from './order.service';

export interface Quotation {
  quotationId: string;
  customer: Customer;
  items: OrderItem[];
  validUntil: Date;
  status: 'DRAFT' | 'SENT' | 'ACCEPTED' | 'REJECTED' | 'EXPIRED';
}

export class QuotationService {
  /**
   * REQ-SALES-004: Create quotation referencing customer.
   * Healthy — no bugs in this method.
   */
  createQuotation(
    customer: Customer,
    items: OrderItem[],
    validDays: number = 30
  ): Quotation {
    return {
      quotationId: `QUO-${Date.now()}`,
      customer,
      items,
      validUntil: new Date(Date.now() + validDays * 24 * 60 * 60 * 1000),
      status: 'DRAFT',
    };
  }

  /**
   * REQ-SALES-005: Convert accepted quotation → order.
   * No bugs intentional. This method exists to test cross-feature traceability.
   */
  convertToOrder(quotation: Quotation): Omit<Order, 'orderId' | 'createdAt'> {
    if (quotation.status !== 'ACCEPTED') {
      throw new Error('Only ACCEPTED quotations can be converted');
    }
    return {
      customer: quotation.customer,
      items: quotation.items,
      status: 'PENDING',
    };
  }
}
