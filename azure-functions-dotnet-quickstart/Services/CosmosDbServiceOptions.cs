using System;
using System.Collections.Generic;
using System.Text;

namespace azure_functions_dotnet_quickstart.Services
{
    public class CosmosDbServiceOptions
    {
        public string ConnectionString { get; set; }
        public string DatabaseId { get; set; }
        public string ContainerId { get; set; }

    }
}
