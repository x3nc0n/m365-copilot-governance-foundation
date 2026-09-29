using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Runtime.CompilerServices;
using System.Text.Json;
using Azure.Core;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace M365CopilotGovernance.Collector;

public interface IGraphSource
{
    IAsyncEnumerable<CollectorUser> GetCopilotLicensedUsersAsync(CancellationToken cancellationToken);

    Task<IReadOnlySet<string>> GetGroupUserIdsAsync(string groupId, CancellationToken cancellationToken);

    IAsyncEnumerable<JsonElement> GetInteractionsAsync(string userId, DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken);
}

public sealed class GraphUserUnavailableException(string userId, HttpStatusCode status)
    : Exception($"Interaction history for user '{userId}' is unavailable ({(int)status}).")
{
    public HttpStatusCode Status { get; } = status;
}

public sealed class GraphSource(
    HttpClient httpClient,
    TokenCredential credential,
    IOptions<CollectorOptions> options,
    ILogger<GraphSource> logger) : IGraphSource
{
    private const int MaxAttempts = 6;
    private readonly CollectorOptions _options = options.Value;

    public async IAsyncEnumerable<CollectorUser> GetCopilotLicensedUsersAsync([EnumeratorCancellation] CancellationToken cancellationToken)
    {
        var planIds = new HashSet<string>(_options.CopilotServicePlanIds, StringComparer.OrdinalIgnoreCase);
        var uri = $"{_options.GraphBaseUri}/users?$select=id,userPrincipalName,assignedPlans&$top=999";
        await foreach (var user in GetPagedAsync(uri, userId: null, cancellationToken))
        {
            if (HasEnabledPlan(user, planIds))
            {
                yield return new CollectorUser(
                    user.GetProperty("id").GetString()!,
                    GetString(user, "userPrincipalName"));
            }
        }
    }

    public async Task<IReadOnlySet<string>> GetGroupUserIdsAsync(string groupId, CancellationToken cancellationToken)
    {
        var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var uri = $"{_options.GraphBaseUri}/groups/{Uri.EscapeDataString(groupId)}/transitiveMembers/microsoft.graph.user?$select=id&$top=999";
        await foreach (var member in GetPagedAsync(uri, userId: null, cancellationToken))
        {
            ids.Add(member.GetProperty("id").GetString()!);
        }

        return ids;
    }

    public IAsyncEnumerable<JsonElement> GetInteractionsAsync(string userId, DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken)
    {
        var uri = BuildInteractionUri(_options.GraphBaseUri, userId, start, end);
        return GetPagedAsync(uri, userId, cancellationToken);
    }

    internal static string BuildInteractionUri(string graphBaseUri, string userId, DateTimeOffset start, DateTimeOffset end)
    {
        // The API requires both bounds; subtracting 1 ms makes the effective window [start, end).
        var lower = start.UtcDateTime.AddMilliseconds(-1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ", CultureInfo.InvariantCulture);
        var upper = end.UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ", CultureInfo.InvariantCulture);
        var filter = Uri.EscapeDataString($"createdDateTime gt {lower} and createdDateTime lt {upper}");
        return $"{graphBaseUri}/copilot/users/{Uri.EscapeDataString(userId)}/interactionHistory/getAllEnterpriseInteractions?$top=100&$filter={filter}";
    }

    internal static bool HasEnabledPlan(JsonElement user, IReadOnlySet<string> planIds)
    {
        if (!user.TryGetProperty("assignedPlans", out var plans) || plans.ValueKind != JsonValueKind.Array)
        {
            return false;
        }

        foreach (var plan in plans.EnumerateArray())
        {
            if (planIds.Contains(GetString(plan, "servicePlanId")) &&
                string.Equals(GetString(plan, "capabilityStatus"), "Enabled", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private async IAsyncEnumerable<JsonElement> GetPagedAsync(string uri, string? userId, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        string? next = uri;
        while (next is not null)
        {
            using var document = await GetJsonAsync(next, userId, cancellationToken);
            if (document.RootElement.TryGetProperty("value", out var values))
            {
                foreach (var item in values.EnumerateArray())
                {
                    yield return item.Clone();
                }
            }

            next = document.RootElement.TryGetProperty("@odata.nextLink", out var link) ? link.GetString() : null;
        }
    }

    private async Task<JsonDocument> GetJsonAsync(string uri, string? userId, CancellationToken cancellationToken)
    {
        for (var attempt = 1; ; attempt++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, uri);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await GetTokenAsync(cancellationToken));
            using var response = await httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
                return await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            }

            if (userId is not null && response.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.NotFound)
            {
                throw new GraphUserUnavailableException(userId, response.StatusCode);
            }

            if (!IsTransient(response.StatusCode) || attempt >= MaxAttempts)
            {
                var body = await response.Content.ReadAsStringAsync(cancellationToken);
                throw new HttpRequestException(
                    $"Microsoft Graph returned {(int)response.StatusCode} for {new Uri(uri).AbsolutePath}: {Truncate(body, 512)}",
                    inner: null,
                    response.StatusCode);
            }

            var delay = GetRetryDelay(response, attempt);
            logger.LogWarning("Microsoft Graph returned {Status}; retrying in {Delay} (attempt {Attempt}/{Max}).", (int)response.StatusCode, delay, attempt, MaxAttempts);
            await Task.Delay(delay, cancellationToken);
        }
    }

    internal static bool IsTransient(HttpStatusCode status) =>
        status is HttpStatusCode.TooManyRequests or HttpStatusCode.InternalServerError or HttpStatusCode.BadGateway
            or HttpStatusCode.ServiceUnavailable or HttpStatusCode.GatewayTimeout;

    internal static TimeSpan GetRetryDelay(HttpResponseMessage response, int attempt)
    {
        var retryAfter = response.Headers.RetryAfter;
        if (retryAfter?.Delta is { } delta && delta > TimeSpan.Zero)
        {
            return delta;
        }

        if (retryAfter?.Date is { } date && date > DateTimeOffset.UtcNow)
        {
            return date - DateTimeOffset.UtcNow;
        }

        return TimeSpan.FromSeconds(Math.Min(60, Math.Pow(2, attempt)));
    }

    // Azure.Identity caches managed identity tokens, so requesting per call is cheap and thread-safe.
    private async Task<string> GetTokenAsync(CancellationToken cancellationToken) =>
        (await credential.GetTokenAsync(new TokenRequestContext([_options.GraphScope]), cancellationToken)).Token;

    private static string GetString(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString()! : string.Empty;

    private static string Truncate(string value, int length) => value.Length <= length ? value : value[..length];
}
