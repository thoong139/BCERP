// pos-02: ProductEntity — Create() method with NO validation guard
// Expected: CHECK 1 signal "Entity Create thieu validation guard" (medium)
// Pattern triggered: public static ProductEntity Create( — missing all validation (no failure return, no guard class, no exception)
using System;

namespace MyApp.Domain.Entities
{
    public class ProductEntity
    {
        public Guid Id { get; private set; }
        public string Name { get; private set; }
        public decimal Price { get; private set; }
        public int StockQuantity { get; private set; }

        private ProductEntity() { }

        public static ProductEntity Create(string name, decimal price, int stockQuantity)
        {
            return new ProductEntity
            {
                Id = Guid.NewGuid(),
                Name = name,
                Price = price,
                StockQuantity = stockQuantity
            };
        }
    }
}
