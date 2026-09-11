// REQ-ID: REQ-ORD-ORD-001, REQ-ORD-ORD-003, REQ-ORD-ORD-004
// FEAT-ID: FEAT-ORD-CORE-001
// Module: MOD-ORDERS
// Cross-module dependency: CustomerId → MOD-CRM.Customer.Id

using System;
using System.Collections.Generic;

namespace Eureka.Modules.Orders.Domain.Entities;

public enum OrderStatus
{
    Draft,
    Confirmed,
    Shipped,
    Completed,
    Cancelled
}

public class Order
{
    public Guid Id { get; private set; }
    public string OrderNumber { get; private set; } = string.Empty;
    public Guid CustomerId { get; private set; }      // FK → CRM.Customer.Id
    public Guid? QuotationId { get; private set; }    // Optional FK → Orders.Quotation.Id
    public OrderStatus Status { get; private set; } = OrderStatus.Draft;
    public decimal TotalAmount { get; private set; }
    public DateTime CreatedAt { get; private set; }

    public ICollection<OrderLine> Lines { get; private set; } = new List<OrderLine>();

    private Order() { }

    public static Order Create(Guid customerId, string orderNumber, Guid? quotationId = null)
    {
        if (customerId == Guid.Empty)
            throw new ArgumentException("Customer required", nameof(customerId));

        return new Order
        {
            Id = Guid.NewGuid(),
            CustomerId = customerId,
            OrderNumber = orderNumber,
            QuotationId = quotationId,
            Status = OrderStatus.Draft,
            CreatedAt = DateTime.UtcNow
        };
    }

    public void Confirm()
    {
        if (Status != OrderStatus.Draft)
            throw new InvalidOperationException("Chỉ Draft mới có thể confirm");
        Status = OrderStatus.Confirmed;
        // Phát sự kiện OrderConfirmed → Finance module consume tạo Invoice
    }
}
