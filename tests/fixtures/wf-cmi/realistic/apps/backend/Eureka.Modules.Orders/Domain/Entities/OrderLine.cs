// REQ-ID: REQ-ORD-ORD-002
// FEAT-ID: FEAT-ORD-CORE-001
// Module: MOD-ORDERS

using System;

namespace Eureka.Modules.Orders.Domain.Entities;

public class OrderLine
{
    public Guid Id { get; private set; }
    public Guid OrderId { get; private set; }
    public string Sku { get; private set; } = string.Empty;
    public int Quantity { get; private set; }
    public decimal UnitPrice { get; private set; }
    public decimal LineTotal => Quantity * UnitPrice;

    public Order? Order { get; private set; }

    private OrderLine() { }

    public static OrderLine Create(Guid orderId, string sku, int quantity, decimal unitPrice)
        => new() { Id = Guid.NewGuid(), OrderId = orderId, Sku = sku, Quantity = quantity, UnitPrice = unitPrice };
}
