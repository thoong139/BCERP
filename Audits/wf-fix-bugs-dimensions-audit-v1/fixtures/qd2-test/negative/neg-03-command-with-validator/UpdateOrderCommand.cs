using MediatR;

namespace Commerce.Orders.Commands;

// Fixture QD2-neg-03: Command WITH adjacent Validator — CHECK 3 should NOT trigger
// Expected: 0 signals
// Why: find *Command.cs → base=UpdateOrderCommand → checks UpdateOrderCommandValidator.cs
//       in same dir → EXISTS → [ ! -f ] false → no signal
public record UpdateOrderCommand(
    Guid OrderId,
    string Status,
    string? Note
) : IRequest<Result<bool>>;
