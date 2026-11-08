# Generic DeployR BootMenu example. Configure customers, sites and roles in BootMenu.Config.psd1.
param(
    [switch]$Windowed
)

$ErrorActionPreference = 'Stop'

$ConfigPath = "$PSScriptRoot\BootMenu.Config.psd1"
$GuiPath    = "$PSScriptRoot\BootMenu.Gui.ps1"

try {
    Import-Module DeployR.Utility -ErrorAction Stop

    $script:BootMenuConfig = Import-PowerShellDataFile -LiteralPath $ConfigPath
}
catch {
    Write-Error "Could not load BootMenu: $($_.Exception.Message)"
    throw
}



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

    if ($script:form) { $script:DeployAccepted = $true; $script:form.Hide(); $script:form.Close() }
}


function Get-BootMenuRole {

    param(
        [Parameter(Mandatory)]
        [string]$Code
    )

    foreach ($Municipality in $script:BootMenuConfig.Municipalities) {

        foreach ($Role in $Municipality.Roles) {

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


function Invoke-BootMenuRole {

    param(
        $Kommmunroll = 'TOM'
    )

    if ($Kommmunroll -eq 'TOM') {

        Show-BootMenuMessage -Message 'You must select a deployment role'

        return
    }

    $Role = Get-BootMenuRole -Code $Kommmunroll

    if (-not $Role) {
        throw "Unknown deployment role: $Kommmunroll"
    }

    if ($Role.Password) {

        $UserInput = ''

        while ($UserInput -ne $Role.Password) {

            $UserInput = ShowMaskedInputWithGif -ExpectedPassword $Role.Password

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


$IPADDRESS001 = ${TSEnv:IPADDRESS001}
$CurrentSite = $script:BootMenuConfig.Sites | Where-Object {
    $IPADDRESS001 -like $_.Pattern
} | Select-Object -First 1

$VisibleMunicipalities = $script:BootMenuConfig.Municipalities

if ($CurrentSite.VisibleMunicipalities) {
    $VisibleMunicipalities = $script:BootMenuConfig.Municipalities | Where-Object {
        $_.Name -in $CurrentSite.VisibleMunicipalities
    }
}

$MainMenu = foreach ($Municipality in $VisibleMunicipalities) {

    $MenuItems = foreach ($Role in $Municipality.Roles) {

        [PSCustomObject]@{
            Text    = [string]$Role.Name
            Code    = [string]$Role.Code
            Profile = $Role.Profile
            OnClick = $null
        }
    }

    [PSCustomObject]@{
        Text = [string]$Municipality.Name
        Menu = @($MenuItems)
    }
}


. $GuiPath
