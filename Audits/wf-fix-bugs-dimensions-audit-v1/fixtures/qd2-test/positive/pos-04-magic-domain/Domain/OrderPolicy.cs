namespace Commerce.Orders.Domain;

// Fixture QD2-pos-04: CHECK 4 (exhaustive) — magic number in Domain layer
// Expected signal: "Magic number trong business logic" severity=low
// Trigger: grep magic-number pattern in Domain/Application layer *.cs
//   magic literal 1000 (4 digits) in branch condition → matches probe regex
//   Path contains /Domain/ → passes domain layer filter
public class OrderPolicy
{
    public bool IsLargeOrder(decimal amount)
    {
        if (amount > 1000)
            return true;

        return false;
    }
}
