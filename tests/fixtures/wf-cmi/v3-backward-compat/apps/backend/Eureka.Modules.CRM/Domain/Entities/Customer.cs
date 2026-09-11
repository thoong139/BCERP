// REQ-ID: REQ-CRM-CUST-001
// FEAT-ID: FEAT-CRM-CUST-001
// Fixture v3-backward-compat — stub entity for TC-cmi-014

namespace Eureka.Modules.CRM.Domain.Entities;

public class Customer
{
    public Guid Id { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string Email { get; private set; } = string.Empty;
    public DateTime CreatedAt { get; private set; }

    private Customer() { }

    public static Customer Create(string name, string email)
    {
        return new Customer
        {
            Id = Guid.NewGuid(),
            Name = name,
            Email = email,
            CreatedAt = DateTime.UtcNow
        };
    }
}
