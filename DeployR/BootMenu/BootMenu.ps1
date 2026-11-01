param(
    [switch]$Windowed
)

$ErrorActionPreference = 'Stop'

$ConfigPath = "$PSScriptRoot\BootMenu.Config.psd1"
$GuiPath    = "$PSScriptRoot\BootMenu.Gui.ps1"

try {
    Import-Module DeployR.Utility -ErrorAction Stop

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop

    $script:BootMenuConfig = Import-PowerShellDataFile -LiteralPath $ConfigPath
}
catch {
    Write-Error "Could not load BootMenu: $($_.Exception.Message)"
    throw
}

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$Now = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(
    (Get-Date).ToUniversalTime(),
    $script:BootMenuConfig.Settings.TimeZone
)

$TSEnv:BootMenyStart = $Now.ToString('yyyy-MM-dd HH:mm:ss')


function global:ShowExit {

    $IPADDRESS001 = ${TSEnv:IPADDRESS001}
    $Site = 'Unknown'

    foreach ($SiteDefinition in $script:BootMenuConfig.Sites) {

        if ($IPADDRESS001 -like $SiteDefinition.Pattern) {
            $Site = $SiteDefinition.Name
            break
        }
    }

    Write-Host '================================================================================'
    Write-Host '================================================================================'
    Write-Host "Deployment role: $($TSEnv:F12Role)"
    Write-Host "Site: $Site"
    Write-Host '================================================================================'
    Write-Host '================================================================================'

    if ($script:form -and -not $script:form.IsDisposed) {
        $script:form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $script:form.Close()
    }
}


function Get-BootMenuRole {

    param(
        [Parameter(Mandatory)]
        [string]$Code
    )

    foreach ($Customer in $script:BootMenuConfig.Municipalities) {

        foreach ($Role in $Customer.Roles) {

            if ($Role.Code -eq $Code) {
                return $Role
            }
        }
    }
}


function Set-TaskSequenceVariables {

    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Variables
    )

    foreach ($VariableName in $Variables.Keys) {
        Set-Item -Path "TSEnv:$VariableName" -Value $Variables[$VariableName]
    }
}


function Invoke-DeployRAction {

    param(
        $CustomerRole = 'EMPTY'
    )

    if ($CustomerRole -eq 'EMPTY') {

        [System.Windows.Forms.MessageBox]::Show(
            'You must select a customer role.'
        ) | Out-Null

        return
    }

    $Role = Get-BootMenuRole -Code $CustomerRole

    if (-not $Role) {
        throw "Unknown customer role: $CustomerRole"
    }

    if ($Role.RequiresOemPassword) {

        $UserInput = ''

        while ($UserInput -ne $script:BootMenuConfig.Settings.OemPassword) {

            $UserInput = ShowMaskedInputWithGif

            if ($UserInput -eq $script:BootMenuConfig.Settings.OemBackValue) {
                return
            }
        }
    }

    Set-TaskSequenceVariables -Variables $Role.Variables

    if (${TSEnv:IsVM} -eq $true) {
        Set-TaskSequenceVariables -Variables $Role.VMVariables
    }
    else {
        Set-TaskSequenceVariables -Variables $Role.PhysicalVariables
    }

    ShowExit
}


$MainMenu = foreach ($Customer in $script:BootMenuConfig.Municipalities) {

    $MenuItems = foreach ($Role in $Customer.Roles) {

        [PSCustomObject]@{
            Text    = [string]$Role.Name
            Code    = [string]$Role.Code
            Profile = $Role.Profile
            OnClick = $null
        }
    }

    [PSCustomObject]@{
        Text = [string]$Customer.Name
        Menu = @($MenuItems)
    }
}


. $GuiPath
