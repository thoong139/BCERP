// REQ-ID: REQ-CRM-CUST-003
// FEAT-ID: FEAT-CRM-CUST-001
// Module: MOD-CRM

using System;

namespace Eureka.Modules.CRM.Domain.Entities;

/// <summary>
/// Nhân viên phụ trách khách hàng (sales owner).
/// Ở realistic fixture, entity này sẽ tham chiếu đến HRM.Employee (cross-module dep).
/// Ở minimal fixture, đây là entity standalone trong CRM module.
/// </summary>
public class SalesOwner
{
    public Guid Id { get; private set; }
    public string FullName { get; private set; } = string.Empty;
    public string Email { get; private set; } = string.Empty;
    public bool IsActive { get; private set; } = true;

    private SalesOwner() { }

    public static SalesOwner Create(string fullName, string email)
    {
        return new SalesOwner
        {
            Id = Guid.NewGuid(),
            FullName = fullName,
            Email = email,
            IsActive = true
        };
    }

    public void Deactivate()
    {
        IsActive = false;
    }
}
