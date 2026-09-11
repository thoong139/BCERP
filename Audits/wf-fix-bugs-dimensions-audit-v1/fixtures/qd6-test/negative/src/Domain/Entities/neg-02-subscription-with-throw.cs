// neg-02: SubscriptionEntity — Create() WITH throw new ArgumentException guard
// Expected: NO signal (CHECK 1 guard check passes: throw new ArgumentException present)
// Guard pattern found: throw new ArgumentException satisfies grep -qE "throw new ArgumentException"
using System;

namespace MyApp.Domain.Entities
{
    public class SubscriptionEntity
    {
        public Guid Id { get; private set; }
        public string PlanName { get; private set; }
        public DateTime ExpiresAt { get; private set; }

        private SubscriptionEntity() { }

        public static SubscriptionEntity Create(string planName, DateTime expiresAt)
        {
            if (string.IsNullOrEmpty(planName))
                throw new ArgumentException("Plan name cannot be null or empty", nameof(planName));
            if (expiresAt <= DateTime.UtcNow)
                throw new ArgumentException("Expiry must be in the future", nameof(expiresAt));

            return new SubscriptionEntity
            {
                Id = Guid.NewGuid(),
                PlanName = planName,
                ExpiresAt = expiresAt
            };
        }
    }
}
