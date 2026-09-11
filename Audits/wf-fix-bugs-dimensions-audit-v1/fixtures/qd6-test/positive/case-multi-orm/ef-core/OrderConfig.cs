// Fixture: EF Core configuration with missing HasIndex on FK columns
// Expected signal: "EF Core: FK property thiếu HasIndex" for OrderId, ProductId
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Demo.Infrastructure.Configurations
{
    // IMP-010 fixture: IEntityTypeConfiguration with FK properties but no HasIndex
    public class OrderItemConfig : IEntityTypeConfiguration<OrderItem>
    {
        public void Configure(EntityTypeBuilder<OrderItem> builder)
        {
            builder.ToTable("OrderItems");
            builder.HasKey(x => x.Id);

            // FK properties present but NO HasIndex
            builder.Property(x => x.OrderId).IsRequired();
            builder.Property(x => x.ProductId).IsRequired();

            builder.Property(x => x.Quantity).IsRequired();
            builder.Property(x => x.UnitPrice).HasColumnType("decimal(18,2)").IsRequired();
        }
    }
}
