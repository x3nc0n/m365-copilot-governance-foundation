using Azure.Core;
using Azure.Identity;
using M365CopilotGovernance.Collector;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices((context, services) =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        services.AddOptions<CollectorOptions>().Bind(context.Configuration.GetSection(CollectorOptions.SectionName));
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<TokenCredential>(provider =>
        {
            var clientId = provider.GetRequiredService<IOptions<CollectorOptions>>().Value.ManagedIdentityClientId;
            return string.IsNullOrWhiteSpace(clientId)
                ? new DefaultAzureCredential()
                : new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(clientId));
        });
        services.AddHttpClient<IGraphSource, GraphSource>(client => client.Timeout = TimeSpan.FromMinutes(2));
        services.AddSingleton<ICheckpointStore, BlobCheckpointStore>();
        services.AddSingleton<IInteractionUploader, LogsIngestionUploader>();
        services.AddTransient<CollectorRunner>();
    })
    .Build();

host.Run();
