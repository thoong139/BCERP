// pos-01: OrderEntity — Create() method with NO validation guard
// Expected: CHECK 1 signal "Entity Create thieu validation guard" (medium)
// Pattern triggered: public static OrderEntity Create( — missing all validation (no failure return, no guard class, no exception)
using System;

namespace MyApp.Domain.Entities
{
    public class OrderEntity
    {
        public Guid Id { get; private set; }
        public Guid CustomerId { get; private set; }
        public string Description { get; private set; }
        public decimal TotalAmount { get; private set; }

        private OrderEntity() { }

        public static OrderEntity Create(Guid customerId, string description, decimal totalAmount)
        {
            return new OrderEntity
            {
                Id = Guid.NewGuid(),
                CustomerId = customerId,
                Description = description,
                TotalAmount = totalAmount
            };
        }
    }
}
