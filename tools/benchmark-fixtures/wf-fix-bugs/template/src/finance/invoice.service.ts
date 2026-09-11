// REQ-ID: REQ-FIN-001, REQ-FIN-002
// FEAT-ID: FEAT-FIN-INV-001
// Module: finance · Feature: Invoice Management

import { Order } from '../sales/order.service';

export interface Invoice {
  invoiceId: string;
  orderId: string;
  subtotal: number;
  vat: number;
  total: number;
  status: 'DRAFT' | 'ISSUED' | 'PAID' | 'CANCELLED';
  issuedAt?: Date;
}

const VAT_RATE = 0.1;

export class InvoiceService {
  private invoices: Map<string, Invoice> = new Map();

  /**
   * REQ-FIN-001: Generate invoice from order.
   * BUG-F01 [CRITICAL][static-scan][QD1]: Type assertion bypassing strict check.
   *   `as Order` cast — order could actually be null but TypeScript sees Order.
   *   Expected fix: proper guard, throw nếu null.
   */
  generateFromOrder(orderOrId: Order | null): Invoice {
    const order = orderOrId as Order;
    const subtotal = order.items.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0
    );
    return this.createInvoice(order.orderId, subtotal);
  }

  /**
   * REQ-FIN-002: Calculate VAT at 10%.
   * BUG-F02 [HIGH][llm-scan][QD2]: VAT rate hardcoded wrong — 0.1 (10%) is correct here,
   *   but business rule says VAT is region-dependent. Missing region parameter.
   *   Expected detection: business completeness probe (QD11).
   */
  calculateVAT(subtotal: number): number {
    return subtotal * VAT_RATE;
  }

  /**
   * BUG-F03 [MEDIUM][static-scan][QD1]: Function parameter mutated — anti-pattern.
   *   `invoice.status = 'ISSUED'` mutates input. Should return new object.
   */
  issueInvoice(invoice: Invoice): Invoice {
    invoice.status = 'ISSUED';
    invoice.issuedAt = new Date();
    return invoice;
  }

  /**
   * BUG-F04 [MEDIUM][static-scan][QD4]: Inefficient — Array.from(.values()) called repeatedly.
   *   Should cache results. Currently re-converts on every call.
   */
  listIssued(): Invoice[] {
    return Array.from(this.invoices.values()).filter(i => i.status === 'ISSUED');
  }

  private createInvoice(orderId: string, subtotal: number): Invoice {
    const vat = this.calculateVAT(subtotal);
    const invoice: Invoice = {
      invoiceId: `INV-${Date.now()}`,
      orderId,
      subtotal,
      vat,
      total: subtotal + vat,
      status: 'DRAFT',
    };
    this.invoices.set(invoice.invoiceId, invoice);
    return invoice;
  }
}
