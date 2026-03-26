Recommended PerfMon Counters for IIS Performance Diagnostics
When troubleshooting IIS performance issues, collecting the following Performance Monitor (PerfMon) counters can help identify request bottlenecks, application processing delays, worker process behavior, and system resource constraints.

Recommended sampling interval: 5–10 seconds

 

The instructions below can be used to setup the counters recommend manually in Performance Monitor. The Powershell script below can be used to set this up automatically on a server.

Instructions
1. IIS Web Service Counters (Request Throughput)
PerfMon Object: Web Service

These counters measure HTTP request volume and connection activity handled by IIS.

Counter	Description	Diagnostic Use
Current Connections	Number of active client connections to the web service.	Identifies spikes in client activity that may correlate with performance degradation.
Total Method Requests/sec	Total number of HTTP requests processed per second.	Establishes baseline request throughput and highlights traffic spikes.
Get Requests/sec	Number of HTTP GET requests processed per second.	Indicates standard page or API request load.
Post Requests/sec	Number of HTTP POST requests processed per second.	Useful for identifying load caused by form submissions or API operations.
Bytes Sent/sec	Rate at which IIS sends data to clients.	Indicates outbound traffic volume.
Bytes Received/sec	Rate at which IIS receives data from clients.	Indicates inbound request payload traffic.
2. ASP.NET Application Counters
PerfMon Object: ASP.NET Applications

These counters provide visibility into ASP.NET request processing and application performance.

Counter	Description	Diagnostic Use
Requests/Sec	Number of ASP.NET requests processed per second.	Measures application throughput.
Requests Executing	Number of requests currently being processed.	Helps identify request saturation or slow execution.
Requests Queued	Number of requests waiting to be processed.	Persistent values above 0 indicate thread pool or application bottlenecks.
Request Wait Time	Time requests spend waiting in the queue before execution.	High values indicate request backlog.
Request Execution Time	Average time required to process requests.	Elevated values may indicate slow application logic or backend dependencies.
4. HTTP.sys Request Queue Counters
PerfMon Object: HTTP Service Request Queues

These counters measure requests queued in **HTTP.sys before IIS worker processes process them.

Counter	Description	Diagnostic Use
CurrentQueueSize	Number of requests currently waiting in the HTTP request queue.	Indicates worker processes may not be processing requests quickly enough.
RequestsQueued	Total number of requests that have been queued.	Useful for identifying request backlog trends.
RejectedRequests	Number of requests rejected because the queue limit was exceeded.	Indicates request queue overflow and potential service disruption.
5. Application Pool / Worker Process Counters
PerfMon Objects:
APP_POOL_WAS
W3SVC_W3WP

These counters provide insight into IIS worker process activity and application pool state.

Counter	Description	Diagnostic Use
Current Application Pool State	Indicates the operational state of the application pool.	Detects stopped pools or unexpected recycling.
Current Worker Processes	Number of worker processes currently running for the application pool.	Helps identify overlapping recycling or unexpected process behavior.
Active Requests	Number of requests currently executing within the worker process.	Indicates active workload within the worker process.
Requests/Sec	Rate at which the worker process is handling requests.	Useful for correlating application activity with performance behavior.
7. System Resource Counters
These counters help determine whether system resource constraints are contributing to IIS performance problems.

CPU
PerfMon Object: Processor

Counter	Description	Diagnostic Use
% Processor Time	Percentage of total CPU usage across the system.	Sustained high values may indicate CPU saturation affecting IIS processing.
% Privileged Time	CPU time spent executing kernel-mode operations.	Elevated values may indicate heavy system or driver activity impacting performance.
Memory
PerfMon Object: Memory

Counter	Description	Diagnostic Use
Available MBytes	Amount of physical memory immediately available for allocation.	Low values may indicate memory pressure impacting IIS or the operating system.
Committed Bytes	Total memory committed for use by the system and applications.	Indicates overall system memory demand.
% Committed Bytes In Use	Percentage of committed memory currently in use.	High values indicate the system is approaching its memory commit limit.
Pages/sec	Rate at which pages are read from or written to disk due to memory pressure.	Sustained high values may indicate insufficient physical memory.
