namespace M365CopilotGovernance.Collector;

public sealed record CollectorUser(string Id, string UserPrincipalName);

public static class ScopeResolver
{
    public static IReadOnlyList<CollectorUser> Resolve(
        CollectionScope scope,
        IEnumerable<CollectorUser> licensedUsers,
        IReadOnlySet<string>? groupMemberIds)
    {
        if (scope != CollectionScope.AllLicensedUsers && groupMemberIds is null)
        {
            throw new ArgumentNullException(nameof(groupMemberIds), $"Group membership is required for {scope}.");
        }

        var users = licensedUsers.DistinctBy(user => user.Id, StringComparer.OrdinalIgnoreCase);
        return scope switch
        {
            CollectionScope.AllLicensedUsers => users.ToList(),
            CollectionScope.IncludeGroup => users.Where(user => groupMemberIds!.Contains(user.Id)).ToList(),
            CollectionScope.ExcludeGroup => users.Where(user => !groupMemberIds!.Contains(user.Id)).ToList(),
            _ => throw new ArgumentOutOfRangeException(nameof(scope)),
        };
    }
}
