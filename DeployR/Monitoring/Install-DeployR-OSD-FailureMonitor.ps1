#requires -RunAsAdministrator

$TaskName   = 'DeployR - OSD Failure Monitor'
$ScriptPath = 'D:\Monitoring\teams-osd-error.ps1'
$LogName    = 'TwoPintSoftware-DeployR-Audit/Operational'
$EventId    = 17004

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Monitor script not found: $ScriptPath"
}

# This task only subscribes to NEW events. It does not clear, modify, archive,
# acknowledge, or otherwise change any Windows Event Log entries.

$Subscription = @"
<QueryList>
  <Query Id="0" Path="$LogName">
    <Select Path="$LogName">*[System[(EventID=$EventId)]]</Select>
  </Query>
</QueryList>
"@

# Pass data from the exact event that triggered the task.
# EventRecordID prevents races when several OSD failures occur close together.
$ValueQueries = @"
<ValueQueries>
  <Value name="EventRecordID">Event/System/EventRecordID</Value>
</ValueQueries>
"@

$EscapedSubscription = [System.Security.SecurityElement]::Escape($Subscription)

$TaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Starts the DeployR Teams OSD failure notifier for new DeployR Event ID 17004 events. Read-only against Windows Event Log.</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>$EscapedSubscription</Subscription>
      $ValueQueries
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <ExecutionTimeLimit>PT5M</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>C:\Program Files\PowerShell\7\pwsh.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -File "D:\Monitoring\teams-osd-error.ps1" -EventRecordId "`$(EventRecordID)"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Write-Host "Replacing existing scheduled task: $TaskName" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Register-ScheduledTask -TaskName $TaskName -Xml $TaskXml -Force | Out-Null

Write-Host ''
Write-Host 'DeployR OSD Failure Monitor scheduled task installed.' -ForegroundColor Green
Write-Host "Task   : $TaskName"
Write-Host "Trigger: NEW Event ID $EventId in $LogName"
Write-Host "Action : $ScriptPath"
Write-Host 'Events : READ ONLY - no Windows events are changed or deleted.' -ForegroundColor Cyan
