// pos-05: CustomerEntity — Create() with NO null/guard check
// Expected: CHECK 1 signal "Entity Create thieu validation guard" (medium)
// Pattern triggered: public static CustomerEntity Create( — missing all validation (no failure return, no null check exception)
using System;

namespace MyApp.Domain.Entities
{
    public class CustomerEntity
    {
        public Guid Id { get; private set; }
        public string Email { get; private set; }
        public string FullName { get; private set; }

        private CustomerEntity() { }

        public static CustomerEntity Create(string email, string fullName)
        {
            return new CustomerEntity
            {
                Id = Guid.NewGuid(),
                Email = email,
                FullName = fullName
            };
        }
    }
}
