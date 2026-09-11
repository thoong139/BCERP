// REQ-ID: REQ-FIN-INV-001, REQ-FIN-INV-002, REQ-FIN-INV-003
// FEAT-ID: FEAT-FIN-INV-001
// Module: MOD-FINANCE
// Cross-module dependencies:
//   - OrderId → MOD-ORDERS.Order.Id (FK)
//   - CustomerId → MOD-CRM.Customer.Id (FK denormalized)
//   - Event consumer: OrderConfirmed event từ MOD-ORDERS

using System;

namespace Eureka.Modules.Finance.Domain.Entities;

public enum InvoiceStatus
{
    Draft,
    Issued,
    PartiallyPaid,
    Paid,
    Cancelled
}

public class Invoice
{
    public Guid Id { get; private set; }
    public string InvoiceNumber { get; private set; } = string.Empty;  // REQ-FIN-INV-002: format VN-yyyy-NNNNNN
    public Guid OrderId { get; private set; }     // FK → Orders.Order.Id
    public Guid CustomerId { get; private set; }  // FK → CRM.Customer.Id (denormalized)
    public InvoiceStatus Status { get; private set; } = InvoiceStatus.Draft;
    public decimal SubTotal { get; private set; }
    public decimal VatAmount { get; private set; }  // REQ-FIN-INV-003: VAT calculation
    public decimal TotalAmount => SubTotal + VatAmount;
    public DateTime IssueDate { get; private set; }
    public DateTime DueDate { get; private set; }

    private Invoice() { }

    public static Invoice CreateFromOrder(Guid orderId, Guid customerId, decimal subTotal, decimal vatRate)
    {
        if (orderId == Guid.Empty)
            throw new ArgumentException(nameof(orderId));
        if (customerId == Guid.Empty)
            throw new ArgumentException(nameof(customerId));

        var year = DateTime.UtcNow.Year;
        return new Invoice
        {
            Id = Guid.NewGuid(),
            OrderId = orderId,
            CustomerId = customerId,
            InvoiceNumber = $"VN-{year}-{Guid.NewGuid().GetHashCode():D6}",
            SubTotal = subTotal,
            VatAmount = subTotal * vatRate,
            IssueDate = DateTime.UtcNow,
            DueDate = DateTime.UtcNow.AddDays(30),
            Status = InvoiceStatus.Issued
        };
    }
}
