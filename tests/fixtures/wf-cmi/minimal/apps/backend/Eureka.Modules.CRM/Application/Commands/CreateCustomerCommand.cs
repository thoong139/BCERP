// REQ-ID: REQ-CRM-CUST-001
// FEAT-ID: FEAT-CRM-CUST-001
// Module: MOD-CRM

using System;
using MediatR;

namespace Eureka.Modules.CRM.Application.Commands;

/// <summary>
/// Command tạo khách hàng mới — CQRS pattern qua MediatR.
/// </summary>
public record CreateCustomerCommand(
    string Name,
    string TaxCode,
    Guid? SalesOwnerId = null
) : IRequest<Guid>;
