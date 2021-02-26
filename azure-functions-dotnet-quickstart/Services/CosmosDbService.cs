using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.Net.NetworkInformation;
using System.Text;
using System.Threading.Tasks;

namespace azure_functions_dotnet_quickstart.Services
{
    public class CosmosDbService
    {
        private readonly CosmosClient _cosmosClient;
        private readonly Container _cosmosContainer;

        public CosmosDbService(IOptions<CosmosDbServiceOptions> options)
        {
            _cosmosClient = new CosmosClient(options.Value.ConnectionString);
            _cosmosContainer = _cosmosClient.GetContainer(options.Value.DatabaseId, options.Value.ContainerId);
        
        }
        
    }
}
