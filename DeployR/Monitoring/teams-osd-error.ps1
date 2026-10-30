#requires -Version 7.0

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [long]$EventRecordId
)

# ============================================================================
# CONFIGURATION - CHANGE THIS URL
# ============================================================================

$TeamsWebhookUrl = 'PASTE-YOUR-TEAMS-WORKFLOW-WEBHOOK-URL-HERE'

# ============================================================================
# SETTINGS
# ============================================================================

$DeployRLogName = 'TwoPintSoftware-DeployR-Audit/Operational'
$DeployREventId = 17004
$LogFile        = 'D:\Monitoring\teams-osd-error.log'

function Write-MonitorLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$Timestamp] [$Level] $Message"
    Write-Host $Line

    try {
        Add-Content -LiteralPath $LogFile -Value $Line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not write monitor log '$LogFile': $($_.Exception.Message)"
    }
}

function Get-DeployRFailureEvent {
    param (
        [long]$RecordId
    )

    if ($RecordId -gt 0) {
        # Read-only lookup. This does not modify the Windows Event Log.
        $Event = Get-WinEvent -FilterHashtable @{
            LogName = $DeployRLogName
            Id      = $DeployREventId
        } -ErrorAction Stop | Where-Object {
            $_.RecordId -eq $RecordId
        } | Select-Object -First 1

        if (-not $Event) {
            throw "DeployR Event ID $DeployREventId with Record ID $RecordId was not found."
        }

        return $Event
    }

    # Manual test mode only: read the newest existing 17004 event.
    # Still read-only. Nothing in the event log is changed.
    Write-MonitorLog 'No EventRecordId supplied. Manual mode will read the newest existing 17004 event.' 'WARNING'

    return Get-WinEvent -FilterHashtable @{
        LogName = $DeployRLogName
        Id      = $DeployREventId
    } -MaxEvents 1 -ErrorAction Stop
}

function ConvertFrom-DeployREvent {
    param (
        [Parameter(Mandatory = $true)]
        $Event
    )

    [xml]$EventXml = $Event.ToXml()

    $EventData = @{}
    foreach ($Data in $EventXml.Event.EventData.Data) {
        $EventData[[string]$Data.Name] = [string]$Data.'#text'
    }

    $ClientIp = [string]$EventData['ip']
    if (-not [string]::IsNullOrWhiteSpace($ClientIp)) {
        $ClientIp = $ClientIp -replace '^::ffff:', ''
    }
    else {
        $ClientIp = 'Unknown'
    }

    $TaskSequenceId = [string]$EventData['tsID']
    if ([string]::IsNullOrWhiteSpace($TaskSequenceId)) {
        $TaskSequenceId = 'Unknown'
    }

    [PSCustomObject]@{
        RecordId       = [long]$Event.RecordId
        TimeCreated    = $Event.TimeCreated
        TaskSequenceId = $TaskSequenceId
        ClientIp       = $ClientIp
        Server         = [string]$Event.MachineName
        EventId        = [int]$Event.Id
    }
}

function Send-TeamsOsdFailure {
    param (
        [Parameter(Mandatory = $true)]
        $Failure
    )

    if ([string]::IsNullOrWhiteSpace($TeamsWebhookUrl) -or
        $TeamsWebhookUrl -eq 'PASTE-YOUR-TEAMS-WORKFLOW-WEBHOOK-URL-HERE') {
        throw 'TeamsWebhookUrl has not been configured at the top of the script.'
    }

    $FailureTime = $Failure.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')

    $Payload = @{
        type = 'message'
        attachments = @(
            @{
                contentType = 'application/vnd.microsoft.card.adaptive'
                contentUrl  = $null
                content     = @{
                    '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
                    type      = 'AdaptiveCard'
                    version   = '1.4'
                    msteams   = @{ width = 'Full' }
                    body      = @(
                        @{
                            type  = 'Container'
                            style = 'attention'
                            bleed = $true
                            items = @(
                                @{
                                    type   = 'TextBlock'
                                    text   = "`u{1F6A8} DEPLOYR OSD FAILURE"
                                    size   = 'Large'
                                    weight = 'Bolder'
                                    color  = 'Light'
                                    wrap   = $true
                                },
                                @{
                                    type    = 'TextBlock'
                                    text    = "Houston, we have an OSD problem. `u{1F4A5}"
                                    weight  = 'Bolder'
                                    color   = 'Light'
                                    spacing = 'Small'
                                    wrap    = $true
                                }
                            )
                        },
                        @{
                            type    = 'TextBlock'
                            text    = 'A DeployR Task Sequence has ended in failure.'
                            size    = 'Medium'
                            weight  = 'Bolder'
                            spacing = 'Medium'
                            wrap    = $true
                        },
                        @{
                            type  = 'FactSet'
                            facts = @(
                                @{ title = "`u{1F552} Time";           value = $FailureTime },
                                @{ title = "`u{1F4BB} Client IP";      value = $Failure.ClientIp },
                                @{ title = "`u{1F9E9} Task Sequence";  value = $Failure.TaskSequenceId },
                                @{ title = "`u{26A0} Event ID";        value = [string]$Failure.EventId },
                                @{ title = "`u{1F50E} Record ID";      value = [string]$Failure.RecordId }
                            )
                        },
                        @{
                            type      = 'Container'
                            separator = $true
                            spacing   = 'Medium'
                            items     = @(
                                @{
                                    type   = 'TextBlock'
                                    text   = "`u{1F527} **Next move**"
                                    weight = 'Bolder'
                                    wrap   = $true
                                },
                                @{
                                    type = 'TextBlock'
                                    text = 'Check DeployR for the failed deployment and its uploaded logs. The task sequence has officially chosen violence.'
                                    wrap = $true
                                }
                            )
                        },
                        @{
                            type      = 'TextBlock'
                            text      = "DeployR Failure Monitor  `u{2022}  Event $($Failure.EventId)  `u{2022}  Record $($Failure.RecordId)"
                            size      = 'Small'
                            isSubtle  = $true
                            separator = $true
                            spacing   = 'Medium'
                            wrap      = $true
                        }
                    )
                }
            }
        )
    }

    $Json = $Payload | ConvertTo-Json -Depth 20

    Write-MonitorLog "Sending Teams notification for Record ID $($Failure.RecordId)."

    Invoke-RestMethod `
        -Uri $TeamsWebhookUrl `
        -Method Post `
        -ContentType 'application/json; charset=utf-8' `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($Json)) `
        -ErrorAction Stop | Out-Null

    Write-MonitorLog "Teams notification sent successfully for Record ID $($Failure.RecordId)."
}

try {
    Write-MonitorLog 'DeployR OSD Failure Monitor started.'

    $Event = Get-DeployRFailureEvent -RecordId $EventRecordId
    $Failure = ConvertFrom-DeployREvent -Event $Event

    Write-MonitorLog "Failure detected. RecordId=$($Failure.RecordId), TS=$($Failure.TaskSequenceId), IP=$($Failure.ClientIp)."

    Send-TeamsOsdFailure -Failure $Failure

    Write-MonitorLog 'DeployR OSD Failure Monitor completed successfully.'
    exit 0
}
catch {
    Write-MonitorLog $_.Exception.Message 'ERROR'
    exit 1
}
