// neg-01: InvoiceEntity — Create() WITH Result.Failure guard
// Expected: NO signal (CHECK 1 guard check passes: Result.Failure present)
// Guard pattern found: Result.Failure<InvoiceEntity>(...) satisfies grep -qE "Result\.Failure"
using System;
using MyApp.Domain.Common;

namespace MyApp.Domain.Entities
{
    public class InvoiceEntity
    {
        public Guid Id { get; private set; }
        public Guid OrderId { get; private set; }
        public decimal Amount { get; private set; }

        private InvoiceEntity() { }

        public static Result<InvoiceEntity> Create(Guid orderId, decimal amount)
        {
            if (orderId == Guid.Empty)
                return Result.Failure<InvoiceEntity>(new Error("Invoice.InvalidOrder", "Order ID cannot be empty"));
            if (amount <= 0)
                return Result.Failure<InvoiceEntity>(new Error("Invoice.InvalidAmount", "Amount must be positive"));

            return Result.Success(new InvoiceEntity
            {
                Id = Guid.NewGuid(),
                OrderId = orderId,
                Amount = amount
            });
        }
    }
}
