using System.Text.Json;
using Azure;
using Azure.Core;
using Azure.Monitor.Ingestion;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Microsoft.Extensions.Options;

namespace M365CopilotGovernance.Collector;

public sealed record Checkpoint(DateTimeOffset CollectedThrough, string? LastRunId);

public interface ICheckpointStore
{
    Task<(Checkpoint? Checkpoint, ETag? ETag)> ReadAsync(CancellationToken cancellationToken);

    Task WriteAsync(Checkpoint checkpoint, ETag? expected, CancellationToken cancellationToken);
}

public sealed class BlobCheckpointStore(TokenCredential credential, IOptions<CollectorOptions> options) : ICheckpointStore
{
    private readonly BlobClient _blob = new(new Uri(options.Value.StateBlobUri), credential);

    public async Task<(Checkpoint? Checkpoint, ETag? ETag)> ReadAsync(CancellationToken cancellationToken)
    {
        try
        {
            var result = await _blob.DownloadContentAsync(cancellationToken);
            return (result.Value.Content.ToObjectFromJson<Checkpoint>(), result.Value.Details.ETag);
        }
        catch (RequestFailedException ex) when (ex.Status == 404)
        {
            return (null, null);
        }
    }

    public async Task WriteAsync(Checkpoint checkpoint, ETag? expected, CancellationToken cancellationToken)
    {
        var conditions = expected is { } etag
            ? new BlobRequestConditions { IfMatch = etag }
            : new BlobRequestConditions { IfNoneMatch = ETag.All };
        await _blob.UploadAsync(
            BinaryData.FromObjectAsJson(checkpoint),
            new BlobUploadOptions { Conditions = conditions },
            cancellationToken);
    }
}

public interface IInteractionUploader
{
    Task UploadAsync(IReadOnlyList<InteractionRecord> records, CancellationToken cancellationToken);
}

public sealed class LogsIngestionUploader(TokenCredential credential, IOptions<CollectorOptions> options) : IInteractionUploader
{
    private static readonly JsonSerializerOptions SerializerOptions = new() { PropertyNamingPolicy = null };
    private readonly CollectorOptions _options = options.Value;
    private readonly LogsIngestionClient _client = new(new Uri(options.Value.LogsIngestionEndpoint), credential);

    public async Task UploadAsync(IReadOnlyList<InteractionRecord> records, CancellationToken cancellationToken)
    {
        if (records.Count == 0)
        {
            return;
        }

        // The client splits payloads into service-sized batches and fails if any batch is rejected.
        await _client.UploadAsync(
            _options.DataCollectionRuleImmutableId,
            _options.StreamName,
            records.Select(record => BinaryData.FromObjectAsJson(record, SerializerOptions)),
            new LogsUploadOptions { MaxConcurrency = 1 },
            cancellationToken);
    }
}
