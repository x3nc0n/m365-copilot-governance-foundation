using System.Net;
using System.Runtime.CompilerServices;
using System.Text.Json;
using Azure;
using M365CopilotGovernance.Collector;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;
using Xunit;

namespace M365CopilotGovernance.Collector.Tests;

public class ScopeTests
{
    private static readonly CollectorUser[] Licensed =
    [
        new("a", "a@contoso.com"),
        new("b", "b@contoso.com"),
        new("c", "c@contoso.com"),
        new("A", "duplicate@contoso.com"),
    ];

    [Fact]
    public void AllLicensedUsersReturnsDistinctLicensedUsers()
    {
        var users = ScopeResolver.Resolve(CollectionScope.AllLicensedUsers, Licensed, null);
        Assert.Equal(["a", "b", "c"], users.Select(u => u.Id));
    }

    [Fact]
    public void IncludeGroupReturnsOnlyLicensedMembers()
    {
        var members = new HashSet<string>(["b", "z"], StringComparer.OrdinalIgnoreCase);
        var users = ScopeResolver.Resolve(CollectionScope.IncludeGroup, Licensed, members);
        Assert.Equal(["b"], users.Select(u => u.Id));
    }

    [Fact]
    public void ExcludeGroupRemovesMembers()
    {
        var members = new HashSet<string>(["B"], StringComparer.OrdinalIgnoreCase);
        var users = ScopeResolver.Resolve(CollectionScope.ExcludeGroup, Licensed, members);
        Assert.Equal(["a", "c"], users.Select(u => u.Id));
    }

    [Fact]
    public void GroupScopesRequireMembership()
    {
        Assert.Throws<ArgumentNullException>(() => ScopeResolver.Resolve(CollectionScope.ExcludeGroup, Licensed, null));
    }

    [Theory]
    [InlineData("IncludeGroup", "")]
    [InlineData("ExcludeGroup", "not-a-guid")]
    [InlineData("Everyone", "")]
    [InlineData("includegroup", "6c2b5f0e-8f8e-4b4a-9d8e-2f3c4b5a6d7e")]
    public void InvalidScopeConfigurationFailsClosed(string scope, string groupId)
    {
        var options = new CollectorOptions { Scope = scope, GroupId = groupId };
        Assert.Throws<InvalidOperationException>(() => options.ParseScope());
    }

    [Fact]
    public void ValidGroupScopeParses()
    {
        var options = new CollectorOptions { Scope = "IncludeGroup", GroupId = "6c2b5f0e-8f8e-4b4a-9d8e-2f3c4b5a6d7e" };
        Assert.Equal(CollectionScope.IncludeGroup, options.ParseScope());
    }
}

public class GraphTests
{
    [Fact]
    public void InteractionUriUsesBoundedFilterAndRecommendedPageSize()
    {
        var uri = GraphSource.BuildInteractionUri(
            "https://graph.microsoft.com/v1.0",
            "user-1",
            new DateTimeOffset(2025, 1, 1, 0, 0, 0, TimeSpan.Zero),
            new DateTimeOffset(2025, 1, 1, 1, 0, 0, TimeSpan.Zero));

        Assert.StartsWith("https://graph.microsoft.com/v1.0/copilot/users/user-1/interactionHistory/getAllEnterpriseInteractions?$top=100&$filter=", uri);
        var filter = Uri.UnescapeDataString(uri[(uri.IndexOf("$filter=", StringComparison.Ordinal) + 8)..]);
        Assert.Equal("createdDateTime gt 2024-12-31T23:59:59.999Z and createdDateTime lt 2025-01-01T01:00:00.000Z", filter);
    }

    [Fact]
    public void LicensedUserRequiresEnabledGraphGroundedChatPlan()
    {
        var plans = new HashSet<string>(["3f30311c-6b1e-48a4-ab79-725b469da960"], StringComparer.OrdinalIgnoreCase);
        using var enabled = JsonDocument.Parse("""{"assignedPlans":[{"servicePlanId":"3F30311C-6B1E-48A4-AB79-725B469DA960","capabilityStatus":"Enabled"}]}""");
        using var suspended = JsonDocument.Parse("""{"assignedPlans":[{"servicePlanId":"3f30311c-6b1e-48a4-ab79-725b469da960","capabilityStatus":"Suspended"}]}""");
        using var other = JsonDocument.Parse("""{"assignedPlans":[{"servicePlanId":"a62f8878-de10-42f3-b68f-6149a25ceb97","capabilityStatus":"Enabled"}]}""");

        Assert.True(GraphSource.HasEnabledPlan(enabled.RootElement, plans));
        Assert.False(GraphSource.HasEnabledPlan(suspended.RootElement, plans));
        Assert.False(GraphSource.HasEnabledPlan(other.RootElement, plans));
    }

    [Fact]
    public void RetryHonorsRetryAfter()
    {
        using var response = new HttpResponseMessage(HttpStatusCode.TooManyRequests);
        response.Headers.RetryAfter = new System.Net.Http.Headers.RetryConditionHeaderValue(TimeSpan.FromSeconds(7));
        Assert.Equal(TimeSpan.FromSeconds(7), GraphSource.GetRetryDelay(response, 1));
        Assert.True(GraphSource.IsTransient(HttpStatusCode.TooManyRequests));
        Assert.False(GraphSource.IsTransient(HttpStatusCode.BadRequest));
    }
}

public class MapperTests
{
    [Fact]
    public void MapsDocumentedInteractionFields()
    {
        using var doc = JsonDocument.Parse("""
        {
          "id": "1732148356886",
          "sessionId": "19:abc@thread.v2",
          "requestId": "f128b7a9",
          "appClass": "IPM.SkypeTeams.Message.Copilot.BizChat",
          "interactionType": "userPrompt",
          "conversationType": "bizchat",
          "etag": "1732148356886",
          "createdDateTime": "2024-11-21T00:19:16.886Z",
          "locale": "en-us",
          "contexts": [],
          "from": { "user": { "id": "4db02e4b" }, "application": null },
          "body": { "contentType": "text", "content": "What should be on my radar?" },
          "attachments": [],
          "links": [],
          "mentions": []
        }
        """);

        var record = InteractionMapper.Map(doc.RootElement, new CollectorUser("4db02e4b", "user@contoso.com"), "AllLicensedUsers", "run", "0.2.0");

        Assert.Equal(DateTimeOffset.Parse("2024-11-21T00:19:16.886Z"), record.TimeGenerated);
        Assert.Equal("1732148356886", record.InteractionId);
        Assert.Equal("userPrompt", record.InteractionType);
        Assert.Equal("4db02e4b", record.FromUserId);
        Assert.Equal(string.Empty, record.FromApplicationName);
        Assert.Equal("What should be on my radar?", record.BodyContent);
        Assert.False(record.BodyTruncated);
        Assert.Equal("[]", record.Attachments);
        Assert.Equal("user@contoso.com", record.UserPrincipalName);
    }

    [Fact]
    public void TruncatesOversizedBodyOnUtf8Boundary()
    {
        var content = new string('é', InteractionMapper.MaxStringBytes);
        var (value, truncated) = InteractionMapper.TruncateUtf8(content, InteractionMapper.MaxStringBytes);
        Assert.True(truncated);
        Assert.True(System.Text.Encoding.UTF8.GetByteCount(value) <= InteractionMapper.MaxStringBytes);
        Assert.NotEmpty(value);
    }
}

public class RunnerTests
{
    private static readonly DateTimeOffset Now = new(2025, 6, 1, 12, 0, 0, TimeSpan.Zero);

    private static CollectorOptions Options(string scope = "AllLicensedUsers") => new()
    {
        Scope = scope,
        GroupId = "6c2b5f0e-8f8e-4b4a-9d8e-2f3c4b5a6d7e",
        LogsIngestionEndpoint = "https://example.ingest.monitor.azure.com",
        DataCollectionRuleImmutableId = "dcr-1",
        StreamName = "Custom-Test",
        StateBlobUri = "https://example.blob.core.windows.net/state/checkpoint.json",
        MaxParallelUsers = 2,
    };

    [Fact]
    public void FirstWindowUsesInitialLookbackAndLag()
    {
        var (start, end) = CollectorRunner.ComputeWindow(null, Now, Options());
        Assert.Equal(Now.AddMinutes(-30).AddHours(-24), start);
        Assert.Equal(Now.AddMinutes(-30), end);
    }

    [Fact]
    public void CatchUpWindowIsCapped()
    {
        var checkpoint = new Checkpoint(Now.AddDays(-5), "old");
        var (start, end) = CollectorRunner.ComputeWindow(checkpoint, Now, Options());
        Assert.Equal(Now.AddDays(-5), start);
        Assert.Equal(Now.AddDays(-4), end);
    }

    [Fact]
    public async Task SuccessfulRunUploadsAndAdvancesCheckpoint()
    {
        var graph = new FakeGraph();
        var store = new FakeCheckpoints();
        var uploader = new FakeUploader();
        var result = await CreateRunner(graph, store, uploader).RunAsync(CancellationToken.None);

        Assert.False(result.Skipped);
        Assert.Equal(2, result.InteractionsUploaded);
        Assert.Equal(1, result.UsersUnavailable);
        Assert.Equal(2, uploader.Records.Count);
        Assert.Equal(Now.AddMinutes(-30), store.Written!.CollectedThrough);
    }

    [Fact]
    public async Task FailedUserDoesNotAdvanceCheckpoint()
    {
        var graph = new FakeGraph { FailUser = "a" };
        var store = new FakeCheckpoints();
        await Assert.ThrowsAnyAsync<Exception>(() => CreateRunner(graph, store, new FakeUploader()).RunAsync(CancellationToken.None));
        Assert.Null(store.Written);
    }

    [Fact]
    public async Task IncludeGroupOnlyCollectsMembers()
    {
        var graph = new FakeGraph { GroupMembers = ["b"] };
        var uploader = new FakeUploader();
        await CreateRunner(graph, new FakeCheckpoints(), uploader, "IncludeGroup").RunAsync(CancellationToken.None);
        Assert.All(uploader.Records, record => Assert.Equal("b", record.UserId));
        Assert.Equal(["b"], graph.QueriedUsers.Order());
    }

    private static CollectorRunner CreateRunner(FakeGraph graph, FakeCheckpoints store, FakeUploader uploader, string scope = "AllLicensedUsers") =>
        new(graph, store, uploader, Microsoft.Extensions.Options.Options.Create(Options(scope)), new FakeTimeProvider(Now), NullLogger<CollectorRunner>.Instance);

    private sealed class FakeGraph : IGraphSource
    {
        public string? FailUser { get; init; }

        public string[] GroupMembers { get; init; } = [];

        public System.Collections.Concurrent.ConcurrentBag<string> QueriedUsers { get; } = [];

        public async IAsyncEnumerable<CollectorUser> GetCopilotLicensedUsersAsync([EnumeratorCancellation] CancellationToken cancellationToken)
        {
            await Task.Yield();
            yield return new CollectorUser("a", "a@contoso.com");
            yield return new CollectorUser("b", "b@contoso.com");
            yield return new CollectorUser("gone", "gone@contoso.com");
        }

        public Task<IReadOnlySet<string>> GetGroupUserIdsAsync(string groupId, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlySet<string>>(new HashSet<string>(GroupMembers));

        public async IAsyncEnumerable<JsonElement> GetInteractionsAsync(string userId, DateTimeOffset start, DateTimeOffset end, [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            QueriedUsers.Add(userId);
            await Task.Yield();
            if (userId == "gone")
            {
                throw new GraphUserUnavailableException(userId, HttpStatusCode.NotFound);
            }

            if (userId == FailUser)
            {
                throw new HttpRequestException("boom");
            }

            var json = JsonSerializer.Serialize(new { id = $"{userId}-1", createdDateTime = start, body = new { content = "x" } });
            yield return JsonDocument.Parse(json).RootElement.Clone();
        }
    }

    private sealed class FakeCheckpoints : ICheckpointStore
    {
        public Checkpoint? Written { get; private set; }

        public Task<(Checkpoint? Checkpoint, ETag? ETag)> ReadAsync(CancellationToken cancellationToken) =>
            Task.FromResult<(Checkpoint?, ETag?)>((null, null));

        public Task WriteAsync(Checkpoint checkpoint, ETag? expected, CancellationToken cancellationToken)
        {
            Written = checkpoint;
            return Task.CompletedTask;
        }
    }

    private sealed class FakeUploader : IInteractionUploader
    {
        public System.Collections.Concurrent.ConcurrentBag<InteractionRecord> Records { get; } = [];

        public Task UploadAsync(IReadOnlyList<InteractionRecord> records, CancellationToken cancellationToken)
        {
            foreach (var record in records)
            {
                Records.Add(record);
            }

            return Task.CompletedTask;
        }
    }
}
