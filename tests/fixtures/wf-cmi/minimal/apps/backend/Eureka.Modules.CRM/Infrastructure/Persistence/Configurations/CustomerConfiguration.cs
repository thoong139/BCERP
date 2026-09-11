// REQ-ID: REQ-CRM-CUST-004
// FEAT-ID: FEAT-CRM-CUST-001
// Module: MOD-CRM

using Eureka.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Eureka.Modules.CRM.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core configuration cho Customer entity — schema mapping, indexes, FK constraints.
/// </summary>
public class CustomerConfiguration : IEntityTypeConfiguration<Customer>
{
    public void Configure(EntityTypeBuilder<Customer> builder)
    {
        builder.ToTable("customers", "crm");

        builder.HasKey(c => c.Id);

        builder.Property(c => c.Name)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(c => c.TaxCode)
            .IsRequired()
            .HasMaxLength(50);

        // REQ-CRM-CUST-005: TaxCode unique invariant
        builder.HasIndex(c => c.TaxCode).IsUnique();

        // REQ-CRM-CUST-003: SalesOwner FK
        builder.HasOne(c => c.SalesOwner)
            .WithMany()
            .HasForeignKey(c => c.SalesOwnerId)
            .OnDelete(DeleteBehavior.Restrict);

        // REQ-CRM-CUST-002: Contacts 1:N relationship
        builder.HasMany(c => c.Contacts)
            .WithOne(c => c.Customer)
            .HasForeignKey(c => c.CustomerId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
