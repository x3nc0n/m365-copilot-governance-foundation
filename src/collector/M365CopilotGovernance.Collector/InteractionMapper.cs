using System.Text;
using System.Text.Json;

namespace M365CopilotGovernance.Collector;

public sealed class InteractionRecord
{
    public DateTimeOffset TimeGenerated { get; init; }

    public string InteractionId { get; init; } = string.Empty;

    public string SessionId { get; init; } = string.Empty;

    public string RequestId { get; init; } = string.Empty;

    public string InteractionType { get; init; } = string.Empty;

    public string AppClass { get; init; } = string.Empty;

    public string ConversationType { get; init; } = string.Empty;

    public string Locale { get; init; } = string.Empty;

    public string Etag { get; init; } = string.Empty;

    public string UserId { get; init; } = string.Empty;

    public string UserPrincipalName { get; init; } = string.Empty;

    public string FromUserId { get; init; } = string.Empty;

    public string FromApplicationId { get; init; } = string.Empty;

    public string FromApplicationName { get; init; } = string.Empty;

    public string BodyContentType { get; init; } = string.Empty;

    public string BodyContent { get; init; } = string.Empty;

    public bool BodyTruncated { get; init; }

    public string Attachments { get; init; } = string.Empty;

    public bool AttachmentsTruncated { get; init; }

    public JsonElement? Contexts { get; init; }

    public JsonElement? Links { get; init; }

    public JsonElement? Mentions { get; init; }

    public string CollectionScope { get; init; } = string.Empty;

    public string CollectorRunId { get; init; } = string.Empty;

    public string CollectorVersion { get; init; } = string.Empty;
}

public static class InteractionMapper
{
    // Azure Monitor limits individual string values; stay well below the limit and flag truncation.
    public const int MaxStringBytes = 30_000;

    public static InteractionRecord Map(JsonElement interaction, CollectorUser user, string scope, string runId, string version)
    {
        var (body, bodyTruncated) = TruncateUtf8(GetString(interaction, "body", "content"), MaxStringBytes);
        var attachmentsJson = interaction.TryGetProperty("attachments", out var attachments) && attachments.ValueKind == JsonValueKind.Array
            ? attachments.GetRawText()
            : "[]";
        var (attachmentText, attachmentsTruncated) = TruncateUtf8(attachmentsJson, MaxStringBytes);

        return new InteractionRecord
        {
            TimeGenerated = interaction.TryGetProperty("createdDateTime", out var created) && created.TryGetDateTimeOffset(out var createdAt)
                ? createdAt
                : DateTimeOffset.UtcNow,
            InteractionId = GetString(interaction, "id"),
            SessionId = GetString(interaction, "sessionId"),
            RequestId = GetString(interaction, "requestId"),
            InteractionType = GetString(interaction, "interactionType"),
            AppClass = GetString(interaction, "appClass"),
            ConversationType = GetString(interaction, "conversationType"),
            Locale = GetString(interaction, "locale"),
            Etag = GetString(interaction, "etag"),
            UserId = user.Id,
            UserPrincipalName = user.UserPrincipalName,
            FromUserId = GetString(interaction, "from", "user", "id"),
            FromApplicationId = GetString(interaction, "from", "application", "id"),
            FromApplicationName = GetString(interaction, "from", "application", "displayName"),
            BodyContentType = GetString(interaction, "body", "contentType"),
            BodyContent = body,
            BodyTruncated = bodyTruncated,
            Attachments = attachmentText,
            AttachmentsTruncated = attachmentsTruncated,
            Contexts = GetBoundedArray(interaction, "contexts"),
            Links = GetBoundedArray(interaction, "links"),
            Mentions = GetBoundedArray(interaction, "mentions"),
            CollectionScope = scope,
            CollectorRunId = runId,
            CollectorVersion = version,
        };
    }

    internal static (string Value, bool Truncated) TruncateUtf8(string value, int maxBytes)
    {
        if (Encoding.UTF8.GetByteCount(value) <= maxBytes)
        {
            return (value, false);
        }

        var length = Math.Min(value.Length, maxBytes);
        while (length > 0 && Encoding.UTF8.GetByteCount(value.AsSpan(0, length)) > maxBytes)
        {
            length = length * 9 / 10;
        }

        if (length > 0 && char.IsHighSurrogate(value[length - 1]))
        {
            length--;
        }

        return (value[..length], true);
    }

    private static JsonElement? GetBoundedArray(JsonElement interaction, string name)
    {
        if (!interaction.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        return Encoding.UTF8.GetByteCount(value.GetRawText()) <= MaxStringBytes ? value.Clone() : null;
    }

    private static string GetString(JsonElement element, params string[] path)
    {
        var current = element;
        foreach (var segment in path)
        {
            if (current.ValueKind != JsonValueKind.Object || !current.TryGetProperty(segment, out current))
            {
                return string.Empty;
            }
        }

        return current.ValueKind == JsonValueKind.String ? current.GetString() ?? string.Empty : string.Empty;
    }
}
