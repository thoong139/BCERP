using Microsoft.AspNetCore.Builder;

namespace Commerce.Products.Api;

// Fixture QD2-neg-02: endpoint WITH RequireAuthorization — CHECK 2 should NOT trigger
// Expected: 0 signals
// Why: grep -qE "RequireAuthorization|AllowAnonymous" → found → condition false → no EMIT
public static class ProductEndpoints
{
    public static void MapProductEndpoints(this WebApplication app)
    {
        app.MapGet("/api/products", GetProducts).RequireAuthorization();
        app.MapGet("/api/products/{id}", GetProduct).RequireAuthorization();
        app.MapPost("/api/products", CreateProduct).RequireAuthorization("manager");
    }

    private static IResult GetProducts() => Results.Ok();
    private static IResult GetProduct(Guid id) => Results.Ok(new { id });
    private static IResult CreateProduct(object req) => Results.Created("/api/products/1", null);
}
