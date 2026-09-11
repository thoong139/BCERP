namespace Commerce.Orders.Application;

// Fixture QD2-pos-05: CHECK 4 (exhaustive) — magic number in Application layer
// Expected signal: "Magic number trong business logic" severity=low
// Trigger: grep magic-number pattern in Domain/Application layer *.cs
//   magic literal 50 (2 digits) in while-loop condition → matches probe regex
//   Path contains /Application/ → passes domain layer filter
//
// DESIGN NOTE: EXECUTION-PROMPT planned single-digit 5 — probe regex requires 2+ digit literal.
// Corrected to 50 per Phase 2 bash regex trace analysis.
public class RetryPolicy
{
    public async Task ExecuteWithRetryAsync(Func<Task> operation)
    {
        int attempts = 0;
        while (attempts < 50)
        {
            try
            {
                await operation();
                return;
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                attempts++;
            }
        }
    }
}
