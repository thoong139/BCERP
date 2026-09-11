using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Routing;

namespace Commerce.Cart.Api;

// Fixture QD2-pos-02: CHECK 2 — endpoint file with Map() calls but no auth decorator
// Expected signal: "Endpoint thieu auth" severity=critical (line 1, whole-file signal)
// Trigger: find *Endpoints.cs → has MapGet/Post → missing auth/anonymous annotation → EMIT
public static class CartEndpoints
{
    public static void MapCartEndpoints(this WebApplication app)
    {
        app.MapGet("/api/cart/{id}", GetCart);
        app.MapPost("/api/cart/{id}/items", AddItem);
        app.MapDelete("/api/cart/{id}/items/{itemId}", RemoveItem);
    }

    private static IResult GetCart(Guid id) => Results.Ok(new { id });
    private static IResult AddItem(Guid id, object req) => Results.Created($"/api/cart/{id}", null);
    private static IResult RemoveItem(Guid id, Guid itemId) => Results.NoContent();
}
