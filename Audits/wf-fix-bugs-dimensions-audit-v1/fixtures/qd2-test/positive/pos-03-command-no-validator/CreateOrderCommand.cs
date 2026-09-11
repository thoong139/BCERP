using MediatR;

namespace Commerce.Orders.Commands;

// Fixture QD2-pos-03: CHECK 3 (deep+) — *Command.cs without adjacent *CommandValidator.cs
// Expected signal: "Command thieu Validator" severity=medium
// Trigger: find *Command.cs → base=CreateOrderCommand (ends "Command", not Handler/Validator/etc)
//           → checks ./pos-03-command-no-validator/CreateOrderCommandValidator.cs → ABSENT → signal
// Note: validator intentionally omitted from this directory
public record CreateOrderCommand(
    Guid CustomerId,
    List<OrderItem> Items,
    string DeliveryAddress
) : IRequest<Result<Guid>>;
