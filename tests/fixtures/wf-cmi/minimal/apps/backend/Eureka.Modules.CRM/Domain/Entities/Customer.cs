// REQ-ID: REQ-CRM-CUST-001
// FEAT-ID: FEAT-CRM-CUST-001
// Module: MOD-CRM

using System;
using System.Collections.Generic;

namespace Eureka.Modules.CRM.Domain.Entities;

/// <summary>
/// Hồ sơ khách hàng — entity gốc của module CRM.
/// </summary>
public class Customer
{
    public Guid Id { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string TaxCode { get; private set; } = string.Empty;  // REQ-CRM-CUST-005: phải unique
    public Guid? SalesOwnerId { get; private set; }              // REQ-CRM-CUST-003: FK đến SalesOwner

    // Navigation properties
    public SalesOwner? SalesOwner { get; private set; }
    public ICollection<Contact> Contacts { get; private set; } = new List<Contact>();

    private Customer() { }

    public static Customer Create(string name, string taxCode, Guid? salesOwnerId = null)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Tên khách hàng không được rỗng", nameof(name));
        if (string.IsNullOrWhiteSpace(taxCode))
            throw new ArgumentException("Mã số thuế không được rỗng", nameof(taxCode));

        return new Customer
        {
            Id = Guid.NewGuid(),
            Name = name,
            TaxCode = taxCode,
            SalesOwnerId = salesOwnerId
        };
    }

    public void AssignSalesOwner(Guid salesOwnerId)
    {
        SalesOwnerId = salesOwnerId;
    }
}
