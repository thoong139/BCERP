// REQ-ID: REQ-API-001
// FEAT-ID: FEAT-DEMO-ROUTE-001
// Fixture for IMP-001: ASP.NET Core route detection
// Tests: [HttpGet], [HttpPost], [Route], app.MapGet (Minimal API)

using Microsoft.AspNetCore.Mvc;

namespace Demo.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductsController : ControllerBase
    {
        [HttpGet]
        public IActionResult GetAll() => Ok();

        [HttpGet("{id:int}")]
        public IActionResult GetById(int id) => Ok();

        [HttpPost]
        public IActionResult Create([FromBody] object body) => Created("/api/products/1", null);

        [HttpPut("{id:int}")]
        public IActionResult Update(int id, [FromBody] object body) => Ok();

        [HttpDelete("{id:int}")]
        public IActionResult Delete(int id) => NoContent();
    }
}

// Minimal API (Program.cs style)
// app.MapGet("/health", () => Results.Ok("healthy"));
// app.MapPost("/api/orders", (Order order) => Results.Created($"/api/orders/{order.Id}", order));
