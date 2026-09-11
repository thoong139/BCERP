// REQ-ID: REQ-CRM-CUST-003
// FEAT-ID: FEAT-CRM-CUST-001
// Module: MOD-CRM

using System;

namespace Eureka.Modules.CRM.Domain.Entities;

public class SalesOwner
{
    public Guid Id { get; private set; }
    public string FullName { get; private set; } = string.Empty;
    public string Email { get; private set; } = string.Empty;
    public bool IsActive { get; private set; } = true;

    private SalesOwner() { }

    public static SalesOwner Create(string fullName, string email)
        => new() { Id = Guid.NewGuid(), FullName = fullName, Email = email, IsActive = true };
}
