using Azure.Extensions.AspNetCore.Configuration.Secrets;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using azure_functions_dotnet_quickstart.Services;
using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.IO;

[assembly: FunctionsStartup(typeof(azure_functions_dotnet_quickstart.Startup))]

namespace azure_functions_dotnet_quickstart
{
    public class Startup : FunctionsStartup
    {
        public override void ConfigureAppConfiguration(IFunctionsConfigurationBuilder builder)
        {
            FunctionsHostBuilderContext context = builder.GetContext();

            var env = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");

            builder.ConfigurationBuilder
               .AddJsonFile(Path.Combine(context.ApplicationRootPath, $"appsettings.json"), true, true)
               .AddJsonFile(Path.Combine(context.ApplicationRootPath, $"appsettings.{env}.json"), true, true);


            var cosmosKeyVaultUrl = Environment.GetEnvironmentVariable("KeyVaultUrl");
            if (!string.IsNullOrEmpty(cosmosKeyVaultUrl))
            {
                var secretClient = new SecretClient(new Uri(cosmosKeyVaultUrl), new DefaultAzureCredential());
                builder.ConfigurationBuilder.AddAzureKeyVault(secretClient, new KeyVaultSecretManager());
            }

            builder.ConfigurationBuilder.AddEnvironmentVariables();
            builder.ConfigurationBuilder.Build();
        }

        public override void Configure(IFunctionsHostBuilder builder)
        {
            FunctionsHostBuilderContext context = builder.GetContext();

            builder.Services.AddOptions()
                       //.Configure<CosmosDbServiceOptions>(context.Configuration.GetSection("CosmosDb"))
                       ;

            builder.Services
                .AddHttpClient()
                //.AddSingleton<CosmosDbService>()
                ;
        }
    }
}
