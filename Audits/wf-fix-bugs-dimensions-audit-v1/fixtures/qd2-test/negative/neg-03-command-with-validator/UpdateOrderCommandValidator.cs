using FluentValidation;

namespace Commerce.Orders.Commands;

// Adjacent validator satisfies CHECK 3 heuristic — no signal expected
public class UpdateOrderCommandValidator : AbstractValidator<UpdateOrderCommand>
{
    public UpdateOrderCommandValidator()
    {
        RuleFor(x => x.OrderId).NotEmpty().WithMessage("Order ID is required");
        RuleFor(x => x.Status).NotEmpty().MaximumLength(50);
    }
}
