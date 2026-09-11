// pos-03: OrderEntityConfiguration — Property(*Id) present but FK relationship config is missing
// Expected: CHECK 2 signal "EF Configuration thieu FK relationship" (medium, deep+ only)
// Pattern triggered: Property(x => x.CustomerId) matches Property(.*Id\b) + no FK navigation config found
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MyApp.Domain.Entities;

namespace MyApp.Infrastructure.Configurations
{
    public class OrderEntityConfiguration : IEntityTypeConfiguration<OrderEntity>
    {
        public void Configure(EntityTypeBuilder<OrderEntity> builder)
        {
            builder.ToTable("Orders");
            builder.HasKey(x => x.Id);
            builder.Property(x => x.CustomerId).IsRequired();
            builder.Property(x => x.Description).HasMaxLength(500);
            builder.Property(x => x.TotalAmount).HasColumnType("decimal(18,2)");
        }
    }
}
