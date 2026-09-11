using Microsoft.Extensions.Caching.Memory;

namespace Commerce.Infrastructure.Services;

// Fixture QD2-neg-05: .cs in Services/ layer — CHECK 4 domain filter /(Domain|Application)/ won't match
// Expected: 0 signals from CHECK 4
// Why: grep finds "if (errorCount > 10)" (10 = 2-digit, matches [0-9]{2,})
//       but domain filter: echo "$file" | grep -qE "/(Domain|Application)/.*\.cs$"
//       Path ./negative/neg-05-wrong-layer/Services/CacheService.cs → contains /Services/ → FAILS filter
public class CacheService
{
    private readonly IMemoryCache _cache;

    public CacheService(IMemoryCache cache) => _cache = cache;

    public T? Get<T>(string key) => _cache.TryGetValue(key, out T? val) ? val : default;

    public void Set<T>(string key, T value)
    {
        var options = new MemoryCacheEntryOptions()
            .SetAbsoluteExpiration(TimeSpan.FromMinutes(30));
        _cache.Set(key, value, options);
    }

    public bool IsHealthy(int errorCount)
    {
        if (errorCount > 10)  // Magic number 10 present but path filtered — no signal expected
            return false;
        return true;
    }
}
