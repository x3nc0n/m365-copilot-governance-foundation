using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace M365CopilotGovernance.Collector;

public sealed record CollectorRunResult(
    string RunId,
    DateTimeOffset WindowStart,
    DateTimeOffset WindowEnd,
    int UsersInScope,
    int UsersUnavailable,
    int InteractionsUploaded,
    bool Skipped);

public sealed class CollectorRunner(
    IGraphSource graph,
    ICheckpointStore checkpoints,
    IInteractionUploader uploader,
    IOptions<CollectorOptions> options,
    TimeProvider timeProvider,
    ILogger<CollectorRunner> logger)
{
    private const int UploadBatchSize = 500;
    private readonly CollectorOptions _options = options.Value;

    public async Task<CollectorRunResult> RunAsync(CancellationToken cancellationToken)
    {
        _options.Validate();
        var scope = _options.ParseScope();
        var runId = Guid.NewGuid().ToString("n");
        var now = timeProvider.GetUtcNow();

        var (checkpoint, etag) = await checkpoints.ReadAsync(cancellationToken);
        var (start, end) = ComputeWindow(checkpoint, now, _options);
        if (end <= start)
        {
            logger.LogInformation("Collector run {RunId} skipped; no complete window is available yet.", runId);
            return new CollectorRunResult(runId, start, end, 0, 0, 0, Skipped: true);
        }

        var users = await ResolveUsersAsync(scope, cancellationToken);
        logger.LogInformation(
            "Collector run {RunId} exporting {Start:o}..{End:o} for {UserCount} users (scope {Scope}).",
            runId, start, end, users.Count, scope);

        var uploaded = 0;
        var unavailable = 0;
        await Parallel.ForEachAsync(
            users,
            new ParallelOptions { MaxDegreeOfParallelism = _options.MaxParallelUsers, CancellationToken = cancellationToken },
            async (user, token) =>
            {
                try
                {
                    var count = await CollectUserAsync(user, start, end, scope.ToString(), runId, token);
                    Interlocked.Add(ref uploaded, count);
                }
                catch (GraphUserUnavailableException ex)
                {
                    Interlocked.Increment(ref unavailable);
                    logger.LogWarning("Skipping user {UserId}: {Message}", user.Id, ex.Message);
                }
            });

        // Only advance after every in-scope user succeeded; failures retry the same window (at-least-once delivery).
        await checkpoints.WriteAsync(new Checkpoint(end, runId), etag, cancellationToken);
        logger.LogInformation(
            "Collector run {RunId} uploaded {Count} interactions; {Unavailable} users unavailable.",
            runId, uploaded, unavailable);
        return new CollectorRunResult(runId, start, end, users.Count, unavailable, uploaded, Skipped: false);
    }

    internal static (DateTimeOffset Start, DateTimeOffset End) ComputeWindow(Checkpoint? checkpoint, DateTimeOffset now, CollectorOptions options)
    {
        var latestEnd = now.AddMinutes(-options.IngestionLagMinutes);
        var start = checkpoint?.CollectedThrough ?? latestEnd.AddHours(-options.InitialLookbackHours);
        var end = start.AddHours(options.MaxWindowHours);
        return (start, end < latestEnd ? end : latestEnd);
    }

    private async Task<IReadOnlyList<CollectorUser>> ResolveUsersAsync(CollectionScope scope, CancellationToken cancellationToken)
    {
        var licensed = new List<CollectorUser>();
        await foreach (var user in graph.GetCopilotLicensedUsersAsync(cancellationToken))
        {
            licensed.Add(user);
        }

        var groupMembers = scope == CollectionScope.AllLicensedUsers
            ? null
            : await graph.GetGroupUserIdsAsync(_options.GroupId, cancellationToken);
        return ScopeResolver.Resolve(scope, licensed, groupMembers);
    }

    private async Task<int> CollectUserAsync(CollectorUser user, DateTimeOffset start, DateTimeOffset end, string scope, string runId, CancellationToken cancellationToken)
    {
        var total = 0;
        var batch = new List<InteractionRecord>(UploadBatchSize);
        await foreach (var interaction in graph.GetInteractionsAsync(user.Id, start, end, cancellationToken))
        {
            batch.Add(InteractionMapper.Map(interaction, user, scope, runId, _options.Version));
            if (batch.Count >= UploadBatchSize)
            {
                await uploader.UploadAsync(batch, cancellationToken);
                total += batch.Count;
                batch.Clear();
            }
        }

        await uploader.UploadAsync(batch, cancellationToken);
        return total + batch.Count;
    }
}
