<h1>DeployR OSD Failure Monitor</h1>

Automatically detects DeployR OSD failures and sends a notification to Microsoft Teams when something goes wrong.
No dashboard watching. No manual checking. If OSD crashes, Teams knows.
Because finding out an OSD failed shouldn't require staring at a dashboard all day.

How it works<br>
Install-DeployR-OSD-FailureMonitor.ps1 <br>
Installs an event-triggered Scheduled Task that listens for new DeployR OSD failure events.<br>
teams-osd-error.ps1<br>
Picks up the failure event and sends a formatted Microsoft Teams notification with useful troubleshooting details.

Setup<br>
1. Copy `teams-osd-error.ps1` to `D:\Monitoring` (or adjust the paths in both scripts).

2. Add your Teams webhook URL to `teams-osd-error.ps1`.

3. Run `Install-DeployR-OSD-FailureMonitor.ps1` as Administrator on the DeployR server.
   This creates an event-triggered Scheduled Task that listens for new DeployR OSD failure events and launches the Teams notification script when one occurs.

4. Break something in OSD.*<br>
   DeployR will probably provide this step naturally sooner or later.

5. Watch the magic happen in Teams.

*Preferably break it on purpose.


<img width="1006" height="503" alt="image" src="https://github.com/user-attachments/assets/4e3d1753-a96f-4057-a920-9e6724b16747" />
