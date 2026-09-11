// REQ-ID: REQ-ORD-QUO-001, REQ-ORD-QUO-002
// FEAT-ID: FEAT-ORD-QUO-001
// Module: MOD-ORDERS
// Cross-module dependency: CustomerId → MOD-CRM.Customer.Id

using System;

namespace Eureka.Modules.Orders.Domain.Entities;

public enum QuotationStatus
{
    Draft,
    Sent,
    Accepted,
    Rejected,
    Expired,
    ConvertedToOrder
}

public class Quotation
{
    public Guid Id { get; private set; }
    public string QuoteNumber { get; private set; } = string.Empty;
    public Guid CustomerId { get; private set; }  // FK → CRM.Customer.Id
    public QuotationStatus Status { get; private set; } = QuotationStatus.Draft;
    public DateTime ExpiresAt { get; private set; }
    public decimal TotalAmount { get; private set; }

    private Quotation() { }

    public static Quotation Create(Guid customerId, string quoteNumber, DateTime expiresAt)
    {
        if (customerId == Guid.Empty)
            throw new ArgumentException(nameof(customerId));
        return new Quotation
        {
            Id = Guid.NewGuid(),
            CustomerId = customerId,
            QuoteNumber = quoteNumber,
            ExpiresAt = expiresAt,
            Status = QuotationStatus.Draft
        };
    }
}
