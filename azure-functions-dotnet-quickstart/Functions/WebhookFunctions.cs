using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;

namespace azure_functions_dotnet_quickstart.Functions
{
    public class WebhookFunctions
    {
        public WebhookFunctions()
        {

        }

        [FunctionName("Webhook")]
        public async Task<IActionResult> WebhookAsync(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)] HttpRequest req,
            [CosmosDB(
                databaseName: "core",
                collectionName: "events",
                ConnectionStringSetting = "CosmosDbConnectionString")]
                IAsyncCollector<JObject> output,
            ILogger log)
        {
            try
            {
                using var requestBodyReader = new StreamReader(req.Body);
                var requestBody = await requestBodyReader.ReadToEndAsync();
                var @event = JsonConvert.DeserializeObject<JObject>(requestBody);

                await output.AddAsync(@event);

            }
            catch(Exception e)
            {
                return new BadRequestObjectResult(e.Message);
            }
            return new OkObjectResult("OK");
        }

    }
}
