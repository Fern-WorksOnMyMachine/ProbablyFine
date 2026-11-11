[CmdletBinding()]
param(
    [ValidateRange(5, 600)]
    [int]$TimeoutSeconds = 30,

    [Parameter(DontShow)]
    [switch]$AvaloniaChild
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$LogFile = 'C:\Windows\Temp\DeployR-VersionMismatch-Avalonia.log'
$PayloadVariable = 'DEPLOYR_VERSION_GATE_PAYLOAD'
$ClientPathVariable = 'DEPLOYR_VERSION_GATE_CLIENT_PATH'

function Write-VersionGateLog {
    param([string]$Text)

    try {
        $folder = Split-Path -Path $LogFile -Parent
        if (-not (Test-Path -LiteralPath $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }

        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $Text" |
            Out-File -LiteralPath $LogFile -Append -Encoding utf8
    }
    catch { }
}

function Get-DeployRTSVariable {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        $item = Get-Item -Path ("TSEnv:{0}" -f $Name) -ErrorAction Stop
        $value = [string]$item.Value

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }
    catch { }

    try {
        $value = [Environment]::GetEnvironmentVariable($Name, 'Process')

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }
    catch { }

    return ''
}

function Get-VersionInformation {
    if ($AvaloniaChild) {
        $payload = [Environment]::GetEnvironmentVariable($PayloadVariable, 'Process')

        if (-not [string]::IsNullOrWhiteSpace($payload)) {
            try {
                $bytes = [Convert]::FromBase64String($payload)
                $xml = [Text.Encoding]::UTF8.GetString($bytes)
                $data = [Management.Automation.PSSerializer]::Deserialize($xml)
                Write-VersionGateLog 'Loaded version information from parent-process payload.'
                return $data
            }
            catch {
                Write-VersionGateLog "Could not deserialize parent-process payload: $($_.Exception.Message)"
            }
        }
    }

    $source = 'DeployR task sequence environment'

    try {
        Import-Module DeployR.Utility -ErrorAction Stop
        Write-VersionGateLog 'DeployR.Utility imported successfully.'
    }
    catch {
        $source = 'Local demo values'
        Write-VersionGateLog "DeployR.Utility unavailable. Using local demo values: $($_.Exception.Message)"
    }

    $clientVersion = Get-DeployRTSVariable -Name 'DEPLOYRCLIENTVERSION'
    $serverVersion = Get-DeployRTSVariable -Name 'DEPLOYRSERVERVERSION'

    if ($source -eq 'Local demo values') {
        if ([string]::IsNullOrWhiteSpace($clientVersion)) {
            $clientVersion = '1.4.2645.2938'
        }
        if ([string]::IsNullOrWhiteSpace($serverVersion)) {
            $serverVersion = '1.4.2701.3102'
        }
    }

    if ([string]::IsNullOrWhiteSpace($clientVersion)) {
        $clientVersion = '<not set>'
    }
    if ([string]::IsNullOrWhiteSpace($serverVersion)) {
        $serverVersion = '<not set>'
    }

    [pscustomobject][ordered]@{
        ClientVersion = $clientVersion
        ServerVersion = $serverVersion
        DataSource     = $source
        TimeoutSeconds = $TimeoutSeconds
    }
}

function ConvertTo-VersionPayload {
    param([Parameter(Mandatory)]$InputObject)

    $xml = [Management.Automation.PSSerializer]::Serialize($InputObject)
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($xml))
}

function Find-DeployRClientPath {
    $candidates = [Collections.Generic.List[string]]::new()

    $inheritedPath = [Environment]::GetEnvironmentVariable($ClientPathVariable, 'Process')
    if (-not [string]::IsNullOrWhiteSpace($inheritedPath)) {
        $candidates.Add($inheritedPath)
    }

    $candidates.Add('C:\_2P\Client')
    $candidates.Add('X:\_2P\Client')
    $candidates.Add('C:\Program Files\2Pint Software\DeployR\Client')

    try {
        $hostPath = (Get-Process -Id $PID -ErrorAction Stop).Path
        if ($hostPath -and $hostPath -match '^(.*?\\_2P\\Client)\\') {
            $candidates.Insert(0, $Matches[1])
        }
    }
    catch { }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Container)) {
            continue
        }

        $controlsAssembly = Get-ChildItem -LiteralPath $candidate -Filter 'Avalonia.Controls.dll' -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($controlsAssembly) {
            return $candidate
        }
    }

    throw 'DeployR Avalonia runtime was not found under C:\_2P\Client, X:\_2P\Client, or the installed DeployR Client path.'
}

function Import-AvaloniaRuntime {
    param([Parameter(Mandatory)][string]$ClientPath)

    foreach ($nativePath in @(
        "$ClientPath\runtimes\win-x64\native",
        "$ClientPath\runtimes\win\native"
    )) {
        if (Test-Path -LiteralPath $nativePath -PathType Container) {
            $env:PATH = "$nativePath;$env:PATH"
        }
    }

    $assemblyNames = @(
        'Avalonia.Base.dll',
        'Avalonia.Controls.dll',
        'Avalonia.Desktop.dll',
        'Avalonia.Markup.Xaml.dll',
        'Avalonia.Markup.Xaml.Loader.dll',
        'Avalonia.Themes.Fluent.dll',
        'Avalonia.Win32.dll',
        'Avalonia.Skia.dll',
        'SkiaSharp.dll'
    )

    foreach ($assemblyName in $assemblyNames) {
        $assembly = Get-ChildItem -LiteralPath $ClientPath -Filter $assemblyName -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\ref\\' } |
            Select-Object -First 1

        if (-not $assembly) {
            throw "Required Avalonia assembly not found: $assemblyName"
        }

        [Reflection.Assembly]::LoadFrom($assembly.FullName) | Out-Null
    }
}

function Get-IsolatedPowerShellHost {
    param([Parameter(Mandatory)][string]$ClientPath)

    $candidates = [Collections.Generic.List[string]]::new()

    $bundledHost = Get-ChildItem -LiteralPath $ClientPath -Filter 'pwsh.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($bundledHost) {
        $candidates.Add($bundledHost)
    }

    try {
        $currentHost = (Get-Process -Id $PID -ErrorAction Stop).Path
        if ($currentHost -and (Split-Path -Path $currentHost -Leaf) -in @('pwsh.exe', 'powershell.exe')) {
            $candidates.Add($currentHost)
        }
    }
    catch { }

    if ($PSHOME) {
        $candidates.Add("$PSHOME\pwsh.exe")
        $candidates.Add("$PSHOME\powershell.exe")
    }

    $candidates.Add('C:\Program Files\PowerShell\7\pwsh.exe')
    $candidates.Add('X:\Program Files\PowerShell\7\pwsh.exe')
    $candidates.Add('C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe')
    $candidates.Add('X:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe')

    $powerShellHost = $candidates |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -Unique -First 1

    if (-not $powerShellHost) {
        throw 'No standalone PowerShell host was found for the Avalonia child process.'
    }

    return $powerShellHost
}

function Start-IsolatedAvaloniaChild {
    param(
        [Parameter(Mandatory)][string]$ClientPath,
        [Parameter(Mandatory)]$VersionInformation
    )

    if ([string]::IsNullOrWhiteSpace($PSCommandPath) -or -not (Test-Path -LiteralPath $PSCommandPath)) {
        throw 'The current script path could not be resolved.'
    }

    $powerShellHost = Get-IsolatedPowerShellHost -ClientPath $ClientPath

    [Environment]::SetEnvironmentVariable(
        $PayloadVariable,
        (ConvertTo-VersionPayload -InputObject $VersionInformation),
        'Process'
    )
    [Environment]::SetEnvironmentVariable($ClientPathVariable, $ClientPath, 'Process')

    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -TimeoutSeconds {1} -AvaloniaChild' -f `
        $PSCommandPath, $TimeoutSeconds

    Write-VersionGateLog "Starting isolated Avalonia process with '$powerShellHost'."
    $process = Start-Process -FilePath $powerShellHost -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden

    if ($null -eq $process) {
        throw 'The isolated Avalonia process could not be created.'
    }

    Write-VersionGateLog "Isolated Avalonia process returned exit code $($process.ExitCode)."
    return [int]$process.ExitCode
}

function Show-VersionDecisionDialog {
    param(
        [Parameter(Mandatory)]$VersionInformation,
        [Parameter(Mandatory)][string]$ClientPath
    )

    Import-AvaloniaRuntime -ClientPath $ClientPath

    if (-not ('DeployRVersionGate.AvaloniaBootstrap' -as [type])) {
        $references = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object {
                $_.Location -and
                ($_.GetName().Name -like 'Avalonia*' -or $_.GetName().Name -eq 'SkiaSharp')
            } |
            Select-Object -ExpandProperty Location -Unique

        Add-Type -TypeDefinition @'
using Avalonia;
namespace DeployRVersionGate
{
    public static class AvaloniaBootstrap
    {
        public static void Setup()
        {
            AppBuilder.Configure<Application>().UsePlatformDetect().SetupWithoutStarting();
        }
    }
}
'@ -ReferencedAssemblies $references
    }

    [DeployRVersionGate.AvaloniaBootstrap]::Setup()

    $xaml = @'
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="900" Height="590"
        MinWidth="760" MinHeight="540"
        MaxWidth="1180" MaxHeight="760"
        WindowStartupLocation="CenterScreen"
        CanResize="True"
        ShowInTaskbar="True"
        Topmost="True"
        SystemDecorations="BorderOnly"
        Background="#0B1118">
  <Window.Styles>
    <Style Selector="TextBlock">
      <Setter Property="FontFamily" Value="Segoe UI"/>
    </Style>
    <Style Selector="Button.continue">
      <Setter Property="Background" Value="#2563A7"/>
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="CornerRadius" Value="9"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="MinWidth" Value="205"/>
      <Setter Property="MinHeight" Value="42"/>
      <Setter Property="Padding" Value="22,10"/>
    </Style>
    <Style Selector="Button.fail">
      <Setter Property="Background" Value="#D34841"/>
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="CornerRadius" Value="9"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="MinWidth" Value="185"/>
      <Setter Property="MinHeight" Value="42"/>
      <Setter Property="Padding" Value="22,10"/>
    </Style>
  </Window.Styles>

  <Grid RowDefinitions="5,*,80">
    <Border Grid.Row="0" Background="#D64C45"/>

    <Grid Grid.Row="1" Margin="48,34,48,26" RowDefinitions="Auto,Auto,*,Auto">
      <Grid Grid.Row="0" ColumnDefinitions="*,Auto">
        <StackPanel Grid.Column="0" Spacing="8">
          <TextBlock Text="VERSION MISMATCH DETECTED"
                     Foreground="#E05B54" FontSize="12"
                     FontWeight="SemiBold" LetterSpacing="1.9"/>
          <TextBlock Text="Client and server disagree"
                     Foreground="#F7F9FC" FontSize="31"
                     FontWeight="SemiBold"/>
          <TextBlock Text="The deployment may still work, but the versions have chosen different paths in life."
                     Foreground="#AAB4C0" FontSize="14.5"
                     TextWrapping="Wrap"/>
        </StackPanel>

        <Border Grid.Column="1" Width="68" Height="68"
                VerticalAlignment="Center" Margin="28,0,4,0"
                Background="#18D64C45" BorderBrush="#70D64C45"
                BorderThickness="1" CornerRadius="34">
          <Grid>
            <Path Width="36" Height="32" Stretch="Uniform"
                  Fill="#E05B54" Data="M24,2 L46,42 L2,42 Z"/>
            <TextBlock Text="!" Foreground="#FFFFFF" FontSize="21"
                       FontWeight="Bold" HorizontalAlignment="Center"
                       VerticalAlignment="Center" Margin="0,10,0,0"/>
          </Grid>
        </Border>
      </Grid>

      <Border Grid.Row="1" Margin="0,26,0,22" Padding="30,26"
              Background="#141E29" BorderBrush="#314153"
              BorderThickness="1" CornerRadius="18">
        <Grid RowDefinitions="Auto,1,Auto">
          <StackPanel Grid.Row="0" Spacing="5">
            <TextBlock Text="VERSION INFORMATION"
                       Foreground="#F7F9FC" FontSize="13"
                       FontWeight="SemiBold" LetterSpacing="1.35"/>
            <TextBlock Name="SourceText" Foreground="#718093" FontSize="11.5"/>
          </StackPanel>

          <Border Grid.Row="1" Background="#2B3948" Margin="0,18,0,18"/>

          <Grid Grid.Row="2" ColumnDefinitions="165,*"
                RowDefinitions="Auto,Auto">
            <TextBlock Grid.Row="0" Text="Client version"
                       Foreground="#8B99AA" FontSize="13.5"
                       VerticalAlignment="Center" Margin="0,0,0,15"/>
            <TextBlock Grid.Row="1" Text="Server version"
                       Foreground="#8B99AA" FontSize="13.5"
                       VerticalAlignment="Center"/>

            <TextBlock Name="ClientVersionValue" Grid.Row="0" Grid.Column="1"
                       Foreground="#F1F4F8" FontSize="17" FontWeight="SemiBold"
                       TextWrapping="Wrap" Margin="0,0,0,18"/>
            <TextBlock Name="ServerVersionValue" Grid.Row="1" Grid.Column="1"
                       Foreground="#F1F4F8" FontSize="17" FontWeight="SemiBold"
                       TextWrapping="Wrap" Margin="0,0,0,0"/>
          </Grid>
        </Grid>
      </Border>

      <StackPanel Grid.Row="2" Spacing="7">
        <TextBlock Text="Choose your own deployment adventure."
                   Foreground="#E05B54" FontSize="15.5"
                   FontWeight="SemiBold"/>
        <TextBlock Text="Continue and hope the versions remain on speaking terms, or stop the task sequence and investigate."
                   Foreground="#9BA7B5" FontSize="12.5"
                   TextWrapping="Wrap"/>
      </StackPanel>

      <Grid Grid.Row="3" Margin="0,24,0,0" ColumnDefinitions="*,Auto">
        <StackPanel Grid.Column="0" Spacing="6">
          <TextBlock Name="CountdownText"
                     Foreground="#7F8D9F" FontSize="12.5"/>
          <ProgressBar Name="CountdownBar" Height="6"
                       Minimum="0" Maximum="30" Value="30"
                       Foreground="#2563A7" Background="#17212C"
                       CornerRadius="3"/>
        </StackPanel>
        <TextBlock Grid.Column="1" Text="Default: continue"
                   Foreground="#607083" FontSize="11.5"
                   VerticalAlignment="Bottom" Margin="20,0,0,0"/>
      </Grid>
    </Grid>

    <Border Grid.Row="2" Background="#101720"
            BorderBrush="#273341" BorderThickness="0,1,0,0">
      <Grid Margin="48,0" ColumnDefinitions="*,Auto,Auto">
        <TextBlock Text="No versions were synchronized while displaying this message."
                   Foreground="#647284" FontSize="11.5"
                   TextWrapping="Wrap" VerticalAlignment="Center"
                   Margin="0,0,24,0"/>
        <Button Name="ContinueButton" Grid.Column="1" Classes="continue"
                Content="Continue Task Sequence" VerticalAlignment="Center"
                Margin="0,0,12,0"/>
        <Button Name="FailButton" Grid.Column="2" Classes="fail"
                Content="Fail Task Sequence" VerticalAlignment="Center"/>
      </Grid>
    </Border>
  </Grid>
</Window>
'@

    $window = [Avalonia.Markup.Xaml.AvaloniaRuntimeXamlLoader]::Load($xaml)
    $nameScope = [Avalonia.Controls.NameScope]::GetNameScope($window)

    if (-not $nameScope) {
        throw 'Avalonia XAML NameScope was not created.'
    }

    $window.Title = 'DeployR - Version mismatch'

    $clientValue = $nameScope.Find('ClientVersionValue')
    $serverValue = $nameScope.Find('ServerVersionValue')
    $sourceText = $nameScope.Find('SourceText')
    $countdownText = $nameScope.Find('CountdownText')
    $countdownBar = $nameScope.Find('CountdownBar')
    $continueButton = $nameScope.Find('ContinueButton')
    $failButton = $nameScope.Find('FailButton')

    $clientValue.Text = [string]$VersionInformation.ClientVersion
    $serverValue.Text = [string]$VersionInformation.ServerVersion
    $sourceText.Text = [string]$VersionInformation.DataSource
    $countdownBar.Maximum = [double]$VersionInformation.TimeoutSeconds
    $countdownBar.Value = [double]$VersionInformation.TimeoutSeconds

    $redBrush = [Avalonia.Media.SolidColorBrush]::Parse('#E05B54')
    $clientValue.Foreground = $redBrush
    $serverValue.Foreground = $redBrush

    $script:DecisionExitCode = 0
    $script:DecisionMade = $false
    $script:StartedAt = [DateTime]::UtcNow

    $cancellation = [Threading.CancellationTokenSource]::new()
    $timer = [Avalonia.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)

    $continueAction = {
        if (-not $script:DecisionMade) {
            $script:DecisionMade = $true
            $script:DecisionExitCode = 0
            Write-VersionGateLog 'Continue Task Sequence selected.'
            $window.Close()
        }
    }

    $failAction = {
        if (-not $script:DecisionMade) {
            $script:DecisionMade = $true
            $script:DecisionExitCode = 124
            Write-VersionGateLog 'Fail Task Sequence selected.'
            $window.Close()
        }
    }

    $continueButton.Add_Click($continueAction)
    $failButton.Add_Click($failAction)

    $window.Add_KeyDown({
        param($sender, $eventArgs)

        if ($eventArgs.Key -eq [Avalonia.Input.Key]::Enter) {
            & $continueAction
        }
        elseif ($eventArgs.Key -eq [Avalonia.Input.Key]::Escape) {
            & $failAction
        }
    })

    $timer.Add_Tick({
        $elapsed = ([DateTime]::UtcNow - $script:StartedAt).TotalSeconds
        $remaining = [Math]::Max(0, [Math]::Ceiling([double]$VersionInformation.TimeoutSeconds - $elapsed))

        $countdownText.Text = "Automatically continuing in $([int]$remaining) seconds."
        $countdownBar.Value = [double]$remaining

        if ($elapsed -ge [double]$VersionInformation.TimeoutSeconds) {
            Write-VersionGateLog 'Countdown expired. Continuing automatically.'
            & $continueAction
        }
    })

    $window.Add_Opened({
        $window.Activate()
        $continueButton.Focus() | Out-Null
        $countdownText.Text = "Automatically continuing in $($VersionInformation.TimeoutSeconds) seconds."
        $timer.Start()
    })

    $window.Add_Closed({
        $timer.Stop()
        $cancellation.Cancel()
    })

    Write-VersionGateLog 'Showing Avalonia version mismatch decision dialog.'
    $window.Show()
    [Avalonia.Threading.Dispatcher]::UIThread.MainLoop($cancellation.Token)

    return [int]$script:DecisionExitCode
}

try {
    Write-VersionGateLog "=== START === Child=$AvaloniaChild Host=$((Get-Process -Id $PID).Path) SystemDrive=$env:SystemDrive"

    $versionInfo = Get-VersionInformation

    Write-Host "DeployR client version: $($versionInfo.ClientVersion)"
    Write-Host "DeployR server version: $($versionInfo.ServerVersion)"

    if (
        $versionInfo.ClientVersion -eq $versionInfo.ServerVersion -and
        $versionInfo.ClientVersion -ne '<not set>'
    ) {
        Write-VersionGateLog 'Versions match. Continuing task sequence.'
        Write-Host 'DeployR versions match. Continuing task sequence.' -ForegroundColor Green
        exit 0
    }

    $clientPath = Find-DeployRClientPath
    Write-VersionGateLog "DeployR client path: $clientPath"

    $isWinPE = $env:SystemDrive -eq 'X:' -or $env:windir -like 'X:\*'

    if ($isWinPE -and -not $AvaloniaChild) {
        try {
            $childExitCode = Start-IsolatedAvaloniaChild -ClientPath $clientPath -VersionInformation $versionInfo
            exit $childExitCode
        }
        catch {
            Write-VersionGateLog "ERROR: Isolated Avalonia start failed. Continuing by default: $($_.Exception.Message)"
            Write-Host "Unable to show version mismatch dialog: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host 'Continuing task sequence by default due to mismatch prompt fallback behavior.' -ForegroundColor Yellow
            exit 0
        }
        finally {
            [Environment]::SetEnvironmentVariable($PayloadVariable, $null, 'Process')
            [Environment]::SetEnvironmentVariable($ClientPathVariable, $null, 'Process')
        }
    }

    $decisionExitCode = Show-VersionDecisionDialog -VersionInformation $versionInfo -ClientPath $clientPath

    if ($decisionExitCode -eq 124) {
        Write-Host 'User selected Fail Task Sequence.' -ForegroundColor Red
        exit 124
    }

    Write-Host 'User selected Continue Task Sequence.' -ForegroundColor Yellow
    exit 0
}
catch {
    Write-VersionGateLog "ERROR: $($_.Exception.ToString())"
    Write-Host "Unable to show version mismatch dialog: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Continuing task sequence by default due to mismatch prompt fallback behavior.' -ForegroundColor Yellow
    exit 0
}
finally {
    [Environment]::SetEnvironmentVariable($PayloadVariable, $null, 'Process')
    [Environment]::SetEnvironmentVariable($ClientPathVariable, $null, 'Process')
}
