// REQ-ID: REQ-FIN-003, REQ-FIN-004, REQ-FIN-005
// FEAT-ID: FEAT-FIN-PAY-001
// Module: finance · Feature: Payment Processing

export type PaymentMethod = 'CARD' | 'BANK_TRANSFER';
export type PaymentStatus = 'PENDING' | 'COMPLETED' | 'FAILED' | 'REFUNDED';

export interface Payment {
  paymentId: string;
  invoiceId: string;
  amount: number;
  method: PaymentMethod;
  status: PaymentStatus;
  completedAt?: Date;
  cardNumber?: string;
}

export class PaymentService {
  private payments: Map<string, Payment> = new Map();

  /**
   * REQ-FIN-003: Process payment with card or bank transfer.
   * BUG-P01 [HIGH][static-scan][QD3]: Sensitive data — logging card number plaintext.
   *   Expected fix: mask card hoặc remove log entirely.
   */
  processPayment(invoiceId: string, amount: number, method: PaymentMethod, cardNumber?: string): Payment {
    console.log(`Processing payment for invoice ${invoiceId}, card: ${cardNumber}`);
    const payment: Payment = {
      paymentId: `PAY-${Date.now()}`,
      invoiceId,
      amount,
      method,
      status: 'PENDING',
      cardNumber,
    };
    this.payments.set(payment.paymentId, payment);
    return payment;
  }

  /**
   * REQ-FIN-004: Refund payment within 30 days.
   * BUG-P02 [MEDIUM][llm-scan][QD2]: Missing time window check.
   *   Should check: payment.completedAt is within 30 days.
   *   Currently: refunds any payment regardless of age.
   */
  refundPayment(paymentId: string): Payment | null {
    const payment = this.payments.get(paymentId);
    if (!payment) return null;
    payment.status = 'REFUNDED';
    return payment;
  }

  /**
   * REQ-FIN-005: Audit trail for transactions.
   * BUG-P03 [LOW][static-scan][QD5]: Deprecated API usage.
   *   `new Date().getYear()` is deprecated. Use getFullYear().
   */
  logAudit(paymentId: string, action: string): void {
    const year = new Date().getYear();
    console.log(`[AUDIT ${year}] ${action} on ${paymentId}`);
  }
}
