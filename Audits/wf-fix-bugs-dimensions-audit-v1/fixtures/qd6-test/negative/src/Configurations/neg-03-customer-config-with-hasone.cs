// neg-03: CustomerEntityConfiguration — Property(*Id) present + HasOne().WithMany() present
// Expected: NO signal (CHECK 2 guard passes: HasOne found → skip)
// Both conditions required for signal: Property(*Id) = true BUT HasOne = true → no emit
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MyApp.Domain.Entities;

namespace MyApp.Infrastructure.Configurations
{
    public class CustomerEntityConfiguration : IEntityTypeConfiguration<CustomerEntity>
    {
        public void Configure(EntityTypeBuilder<CustomerEntity> builder)
        {
            builder.ToTable("Customers");
            builder.HasKey(x => x.Id);
            builder.Property(x => x.Email).IsRequired().HasMaxLength(256);
            builder.Property(x => x.FullName).HasMaxLength(200);
            builder.Property(x => x.TenantId).IsRequired();

            builder.HasOne<TenantEntity>(x => x.Tenant)
                   .WithMany(t => t.Customers)
                   .HasForeignKey(x => x.TenantId)
                   .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
