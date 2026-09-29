namespace M365CopilotGovernance.Collector;

public sealed class CollectorOptions
{
    public const string SectionName = "Collector";

    public string ManagedIdentityClientId { get; set; } = string.Empty;

    public string Scope { get; set; } = string.Empty;

    public string GroupId { get; set; } = string.Empty;

    public string LogsIngestionEndpoint { get; set; } = string.Empty;

    public string DataCollectionRuleImmutableId { get; set; } = string.Empty;

    public string StreamName { get; set; } = string.Empty;

    public string StateBlobUri { get; set; } = string.Empty;

    public string Version { get; set; } = "unknown";

    public string GraphBaseUri { get; set; } = "https://graph.microsoft.com/v1.0";

    public string GraphScope { get; set; } = "https://graph.microsoft.com/.default";

    // Microsoft Copilot with Graph-grounded chat (M365_COPILOT_BUSINESS_CHAT), required by the export API.
    public string[] CopilotServicePlanIds { get; set; } = ["3f30311c-6b1e-48a4-ab79-725b469da960"];

    public int InitialLookbackHours { get; set; } = 24;

    public int IngestionLagMinutes { get; set; } = 30;

    public int MaxWindowHours { get; set; } = 24;

    public int MaxParallelUsers { get; set; } = 4;

    public CollectionScope ParseScope()
    {
        if (!Enum.TryParse<CollectionScope>(Scope, ignoreCase: false, out var scope) || !Enum.IsDefined(scope))
        {
            throw new InvalidOperationException($"Collector:Scope '{Scope}' is not one of AllLicensedUsers, IncludeGroup, or ExcludeGroup.");
        }

        if (scope != CollectionScope.AllLicensedUsers && !Guid.TryParse(GroupId, out _))
        {
            throw new InvalidOperationException($"Collector:GroupId must be a Microsoft Entra group object ID when Collector:Scope is {scope}.");
        }

        return scope;
    }

    public void Validate()
    {
        ParseScope();
        Require(LogsIngestionEndpoint, nameof(LogsIngestionEndpoint));
        Require(DataCollectionRuleImmutableId, nameof(DataCollectionRuleImmutableId));
        Require(StreamName, nameof(StreamName));
        Require(StateBlobUri, nameof(StateBlobUri));
        if (InitialLookbackHours < 1 || MaxWindowHours < 1 || IngestionLagMinutes < 0 || MaxParallelUsers < 1)
        {
            throw new InvalidOperationException("Collector window and parallelism settings must be positive.");
        }
    }

    private static void Require(string value, string name)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Collector:{name} is required.");
        }
    }
}

public enum CollectionScope
{
    AllLicensedUsers,
    IncludeGroup,
    ExcludeGroup,
}
