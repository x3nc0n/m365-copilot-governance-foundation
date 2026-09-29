using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace M365CopilotGovernance.Collector;

public sealed class CollectInteractionsFunction(CollectorRunner runner, ILogger<CollectInteractionsFunction> logger)
{
    [Function("CollectCopilotInteractions")]
    public async Task RunAsync([TimerTrigger("0 5 * * * *")] TimerInfo timer, CancellationToken cancellationToken)
    {
        var result = await runner.RunAsync(cancellationToken);
        logger.LogInformation(
            "Run {RunId}: skipped={Skipped}, users={Users}, unavailable={Unavailable}, uploaded={Uploaded}, window={Start:o}..{End:o}, next={Next}.",
            result.RunId, result.Skipped, result.UsersInScope, result.UsersUnavailable, result.InteractionsUploaded,
            result.WindowStart, result.WindowEnd, timer.ScheduleStatus?.Next);
    }
}
