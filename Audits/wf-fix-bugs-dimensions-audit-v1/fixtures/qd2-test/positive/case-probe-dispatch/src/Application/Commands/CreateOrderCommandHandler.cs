// REQ-ID: REQ-ORDER-001
namespace App.Application.Commands;

public class CreateOrderCommandHandler : IRequestHandler<CreateOrderCommand, Result<OrderId>>
{
    public async Task<Result<OrderId>> Handle(CreateOrderCommand cmd, CancellationToken ct)
    {
        // Missing Result.Failure check — throws instead
        if (cmd.CustomerId == Guid.Empty)
            throw new InvalidOperationException("CustomerId required");

        var order = Order.Create(cmd.CustomerId, cmd.Items);
        return Result<OrderId>.Success(order.Id);
    }
}
