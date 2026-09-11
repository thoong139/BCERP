// REQ-ID: REQ-CRM-CUST-001
// FEAT-ID: FEAT-CRM-CUST-001
// Module: MOD-CRM

using System;
using System.Collections.Generic;

namespace Eureka.Modules.CRM.Domain.Entities;

public class Customer
{
    public Guid Id { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string TaxCode { get; private set; } = string.Empty;  // REQ-CRM-CUST-002: unique
    public Guid? SalesOwnerId { get; private set; }              // REQ-CRM-CUST-003

    public SalesOwner? SalesOwner { get; private set; }

    private Customer() { }

    public static Customer Create(string name, string taxCode, Guid? salesOwnerId = null)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException(nameof(name));
        if (string.IsNullOrWhiteSpace(taxCode))
            throw new ArgumentException(nameof(taxCode));
        return new Customer { Id = Guid.NewGuid(), Name = name, TaxCode = taxCode, SalesOwnerId = salesOwnerId };
    }
}
