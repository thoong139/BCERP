// REQ-ID: REQ-CRM-CUST-002
// FEAT-ID: FEAT-CRM-CUST-001
// Module: MOD-CRM

using System;

namespace Eureka.Modules.CRM.Domain.Entities;

/// <summary>
/// Thông tin liên hệ phụ — 1 Customer có nhiều Contact (1:N).
/// </summary>
public class Contact
{
    public Guid Id { get; private set; }
    public Guid CustomerId { get; private set; }  // FK đến Customer
    public string FullName { get; private set; } = string.Empty;
    public string Email { get; private set; } = string.Empty;
    public string Phone { get; private set; } = string.Empty;
    public bool IsPrimary { get; private set; }

    // Navigation property
    public Customer? Customer { get; private set; }

    private Contact() { }

    public static Contact Create(Guid customerId, string fullName, string email, string phone, bool isPrimary = false)
    {
        if (customerId == Guid.Empty)
            throw new ArgumentException("CustomerId phải hợp lệ", nameof(customerId));

        return new Contact
        {
            Id = Guid.NewGuid(),
            CustomerId = customerId,
            FullName = fullName,
            Email = email,
            Phone = phone,
            IsPrimary = isPrimary
        };
    }
}
