// pos-03: .NET WebAPI route — known FN-001 reproduction
//
// REQ-ID: REQ-CATALOG-003  ← Legit, có trong registry → KHÔNG flag
// FEAT-ID: FEAT-CATALOG-PROD-003  ← Annotated, có trong registry → KHÔNG flag coverage_gap
//
// Mục đích: P-QD1-route-config-parse spec phải bắt được .NET routes nhưng
// hiện tại chỉ grep `app.get`, `@Get`, `<Route` → miss 100% .NET routes.
// Bug này được audit §FN-001 ghi nhận. Vì probe KHÔNG có bash script độc lập
// (xem 02-qd1 §3 Probe 2 D1), hiện không thể đo automatic. Documented gap.
//
// Audit reference: 02-qd1-functional-audit.md §FN-001
// Expected_to_detect: orphan_api signal (HIGH) cho route /api/products
// Current_probe_status: not_implemented (no standalone script)

using Microsoft.AspNetCore.Mvc;

namespace QD1Test.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductsController : ControllerBase
    {
        // .NET attribute-based routing — script hiện tại không grep được pattern này
        [HttpGet("/api/products")]
        public IActionResult GetProducts()
        {
            return Ok(new[] { "p1", "p2", "p3" });
        }

        [HttpGet("/api/products/{id}")]
        public IActionResult GetProduct(int id)
        {
            return Ok(new { id, name = "Sample" });
        }
    }
}
