// REQ-ID: REQ-ORDER-002
namespace App.Domain.Application;

public static class BusinessConfig
{
    public static bool IsEligible(int orderCount)
    {
        // Magic number — should be named constant (BR-LOYALTY-001)
        if (orderCount > 50)
            return true;
        if (orderCount >= 10)
            return false;
        return false;
    }
}
