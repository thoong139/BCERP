using MediatR;
using Commerce.Orders.Domain;

namespace Commerce.Orders.Commands;

// Fixture QD2-pos-01: CHECK 1 — railway pattern violation
// Expected signal: "Anti-pattern: throw in CommandHandler" severity=high
// Trigger: grep for exception-throw keyword in *.cs, filter file ending CommandHandler.cs
public class OrderCommandHandler : IRequestHandler<PlaceOrderCommand, Result<Guid>>
{
    private readonly IOrderRepository _repo;

    public OrderCommandHandler(IOrderRepository repo) => _repo = repo;

    public async Task<Result<Guid>> Handle(PlaceOrderCommand request, CancellationToken ct)
    {
        if (request.CustomerId == Guid.Empty)
            throw new InvalidOperationException("CustomerId must be provided.");

        var order = new Order(request.CustomerId, request.Items);
        await _repo.SaveAsync(order, ct);
        return Result<Guid>.Success(order.Id);
    }
}
