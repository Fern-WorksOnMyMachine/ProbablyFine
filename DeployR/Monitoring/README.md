DeployR OSD Failure Monitor
Because finding out an OSD failed shouldn't require staring at a dashboard all day.

Install-DeployR-OSD-FailureMonitor.ps1 installs the event-triggered Scheduled Task.

teams-osd-error.ps1 picks up the DeployR failure event and sends a formatted alert to Microsoft Teams with the useful troubleshooting details.

Setup
Copy teams-osd-error.ps1 to D:\Monitoring\
Add your Teams webhook URL.
Run Install-DeployR-OSD-FailureMonitor.ps1 as Administrator.
Break something.*
Watch Teams.
* Preferably in test.

The monitor only reacts to new events and does not modify or delete anything in the Windows Event Log.

If OSD fails and nobody gets a Teams notification, did it really fail?
