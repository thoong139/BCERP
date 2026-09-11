using MediatR;

namespace Commerce.Products.Commands;

// Fixture QD2-neg-01: CORRECT railway pattern — Result<T>.Failure() instead of exception throw
// Expected: 0 signals from CHECK 1
// Why: uses Result<T>.Failure() pattern — no railway-pattern violation in this file
public class CreateProductCommandHandler : IRequestHandler<CreateProductCommand, Result<Guid>>
{
    private readonly IProductRepository _repo;

    public CreateProductCommandHandler(IProductRepository repo) => _repo = repo;

    public async Task<Result<Guid>> Handle(CreateProductCommand request, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(request.Name))
            return Result<Guid>.Failure(new Error("PROD001", "Product name is required"));

        if (request.Price <= 0)
            return Result<Guid>.Failure(new Error("PROD002", "Price must be positive"));

        var product = new Product(request.Name, request.Price);
        await _repo.SaveAsync(product, ct);
        return Result<Guid>.Success(product.Id);
    }
}
