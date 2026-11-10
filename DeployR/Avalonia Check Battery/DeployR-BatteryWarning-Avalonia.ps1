[CmdletBinding()]
param(
    [ValidateRange(250, 10000)]
    [int]$PollIntervalMilliseconds = 1000,
    [ValidateRange(250, 10000)]
    [int]$CloseDelayMilliseconds = 1400,
    [Parameter(DontShow)]
    [switch]$AvaloniaChild
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$LogFile = 'C:\Windows\Temp\DeployR-BatteryWarning-Avalonia.log'
function Write-BatteryLog {
    param([string]$Text)
    try {
        $folder = Split-Path -Path $LogFile -Parent
        if (-not (Test-Path -LiteralPath $folder)) { New-Item -Path $folder -ItemType Directory -Force | Out-Null }
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $Text" | Out-File -LiteralPath $LogFile -Append -Encoding utf8
    } catch { }
}
function Get-PowerState {
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop | Select-Object -First 1
        if (-not $battery) { return [pscustomobject]@{ HasBattery=$false; Charge=100; OnAC=$true } }
        $charge = if ($null -ne $battery.EstimatedChargeRemaining) { [Math]::Max(0,[Math]::Min(100,[int]$battery.EstimatedChargeRemaining)) } else { 0 }
        $onAC = [int]$battery.BatteryStatus -in @(2,6,7,8,9,11)
        [pscustomobject]@{ HasBattery=$true; Charge=$charge; OnAC=$onAC }
    } catch {
        Write-BatteryLog "Battery query unavailable: $($_.Exception.Message)"
        [pscustomobject]@{ HasBattery=$false; Charge=100; OnAC=$true }
    }
}
function Find-DeployRClientPath {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($env:DEPLOYR_BATTERY_CLIENT_PATH) { $candidates.Add($env:DEPLOYR_BATTERY_CLIENT_PATH) }
    $candidates.Add('C:\_2P\Client'); $candidates.Add('X:\_2P\Client'); $candidates.Add('C:\Program Files\2Pint Software\DeployR\Client')
    try { $hostPath=(Get-Process -Id $PID -ErrorAction Stop).Path; if($hostPath -and $hostPath -match '^(.*?\\_2P\\Client)\\'){ $candidates.Insert(0,$Matches[1]) } } catch {}
    foreach($candidate in ($candidates|Select-Object -Unique)) { if($candidate -and (Test-Path -LiteralPath $candidate) -and (Get-ChildItem -LiteralPath $candidate -Filter 'Avalonia.Controls.dll' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1)){return $candidate} }
    throw 'DeployR Avalonia runtime was not found under C:\_2P\Client, X:\_2P\Client, or the installed DeployR Client path.'
}
function Import-AvaloniaRuntime {
    param([Parameter(Mandatory)][string]$ClientPath)
    $assemblyNames=@('Avalonia.Base.dll','Avalonia.Controls.dll','Avalonia.Desktop.dll','Avalonia.Markup.Xaml.dll','Avalonia.Markup.Xaml.Loader.dll','Avalonia.Themes.Fluent.dll','Avalonia.Win32.dll','Avalonia.Skia.dll','SkiaSharp.dll')
    foreach($nativePath in @("$ClientPath\runtimes\win-x64\native","$ClientPath\runtimes\win\native")){if(Test-Path -LiteralPath $nativePath){$env:PATH="$nativePath;$env:PATH"}}
    foreach($assemblyName in $assemblyNames){$assembly=Get-ChildItem -LiteralPath $ClientPath -Filter $assemblyName -File -Recurse -ErrorAction SilentlyContinue|Where-Object {$_.FullName -notmatch '\\ref\\'}|Select-Object -First 1;if(-not $assembly){throw "Required Avalonia assembly not found: $assemblyName"};[System.Reflection.Assembly]::LoadFrom($assembly.FullName)|Out-Null}
}
function Start-IsolatedAvaloniaChild {
    param([Parameter(Mandatory)][string]$ClientPath)

    if ([string]::IsNullOrWhiteSpace($PSCommandPath) -or -not (Test-Path -LiteralPath $PSCommandPath)) {
        throw 'The current script path could not be resolved.'
    }

    # BootMenu may already have initialized Avalonia in the current DeployR host.
    # Always launch this UI in a clean PowerShell process in WinPE.
    $candidateHosts = [System.Collections.Generic.List[string]]::new()

    try {
        $currentHost = (Get-Process -Id $PID -ErrorAction Stop).Path
        if ($currentHost -and (Split-Path -Path $currentHost -Leaf) -in @('pwsh.exe', 'powershell.exe')) {
            $candidateHosts.Add($currentHost)
        }
    }
    catch { }

    if ($PSHOME) {
        $candidateHosts.Add("$PSHOME\pwsh.exe")
        $candidateHosts.Add("$PSHOME\powershell.exe")
    }

    $candidateHosts.Add('C:\Program Files\PowerShell\7\pwsh.exe')
    $candidateHosts.Add('X:\Program Files\PowerShell\7\pwsh.exe')
    $candidateHosts.Add('C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe')
    $candidateHosts.Add('X:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe')

    $bundledHost = Get-ChildItem -LiteralPath $ClientPath -Filter 'pwsh.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($bundledHost) { $candidateHosts.Insert(0, $bundledHost) }

    $powerShellHost = $candidateHosts |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -Unique -First 1

    if (-not $powerShellHost) {
        throw 'No standalone PowerShell host was found for the Avalonia child process.'
    }

    $env:DEPLOYR_BATTERY_CLIENT_PATH = $ClientPath
    $argumentString = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -PollIntervalMilliseconds {1} -CloseDelayMilliseconds {2} -AvaloniaChild' -f `
        $PSCommandPath, $PollIntervalMilliseconds, $CloseDelayMilliseconds

    Write-BatteryLog "Starting isolated Avalonia process with '$powerShellHost'."
    $process = Start-Process -FilePath $powerShellHost -ArgumentList $argumentString -Wait -PassThru -WindowStyle Hidden

    if ($null -eq $process) {
        throw 'The isolated Avalonia process could not be created.'
    }

    Write-BatteryLog "Isolated Avalonia process returned exit code $($process.ExitCode)."
}
try {
    Write-BatteryLog "=== START === Child=$AvaloniaChild Host=$((Get-Process -Id $PID).Path) SystemDrive=$env:SystemDrive"
    $initialState=Get-PowerState
    if($initialState.OnAC -or -not $initialState.HasBattery){Write-BatteryLog 'Power requirement already satisfied. UI skipped.';exit 0}
    $clientPath=Find-DeployRClientPath; Write-BatteryLog "DeployR client path: $clientPath"
    $isWinPE=$env:SystemDrive -eq 'X:' -or $env:windir -like 'X:\*'
    if ($isWinPE -and -not $AvaloniaChild) { try { Start-IsolatedAvaloniaChild -ClientPath $clientPath } catch { Write-BatteryLog "WARNING: Isolated Avalonia start failed; power warning skipped safely: $($_.Exception.Message)" }; exit 0 }
    Import-AvaloniaRuntime -ClientPath $clientPath
    if(-not ('DeployRBattery.AvaloniaBootstrap' -as [type])){$references=[AppDomain]::CurrentDomain.GetAssemblies()|Where-Object {$_.Location -and ($_.GetName().Name -like 'Avalonia*' -or $_.GetName().Name -eq 'SkiaSharp')}|Select-Object -ExpandProperty Location -Unique;Add-Type -TypeDefinition @'
using Avalonia;
namespace DeployRBattery { public static class AvaloniaBootstrap { public static void Setup() { AppBuilder.Configure<Application>().UsePlatformDetect().SetupWithoutStarting(); } } }
'@ -ReferencedAssemblies $references}
    [DeployRBattery.AvaloniaBootstrap]::Setup()
    $xaml=@'
<Window xmlns="https://github.com/avaloniaui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Width="780" Height="390" MinWidth="680" MinHeight="360" WindowStartupLocation="CenterScreen"
 CanResize="False" ShowInTaskbar="True" Topmost="True" SystemDecorations="BorderOnly" Background="#0D131B">
 <Window.Styles>
  <Style Selector="TextBlock"><Setter Property="FontFamily" Value="Segoe UI"/></Style>
  <Style Selector="Border.card"><Setter Property="Background" Value="#18212C"/><Setter Property="BorderBrush" Value="#2D3A49"/><Setter Property="BorderThickness" Value="1"/><Setter Property="CornerRadius" Value="16"/></Style>
 </Window.Styles>
 <Grid RowDefinitions="5,*">
  <Border Grid.Row="0" Background="#F4A300"/>
  <Grid Grid.Row="1" Margin="38,29,38,24" RowDefinitions="Auto,*,Auto">
   <Grid Grid.Row="0" ColumnDefinitions="*,Auto">
    <StackPanel Grid.Column="0" Spacing="7" VerticalAlignment="Center">
     <TextBlock Text="POWER ADAPTER REQUIRED" Foreground="#F4A300" FontSize="11.5" FontWeight="SemiBold" LetterSpacing="1.8"/>
     <TextBlock Text="Connect power to continue" Foreground="#F7F9FC" FontSize="29" FontWeight="SemiBold"/>
     <TextBlock Text="Deployment refuses to continue on hopes and battery power alone." Foreground="#AAB4C0" FontSize="14"/>
    </StackPanel>
    <Border Grid.Column="1" Width="62" Height="62" VerticalAlignment="Center" Margin="24,0,4,0" Background="#18F4A300" BorderBrush="#70F4A300" BorderThickness="1" CornerRadius="31">
     <Grid><Ellipse Width="40" Height="40" Fill="#12F4A300"/><Path Width="21" Height="28" Stretch="Uniform" Fill="#F4A300" Data="M22,1 L7,21 L17,21 L13,39 L30,16 L20,16 Z"/></Grid>
    </Border>
   </Grid>
   <Border Name="StatusCard" Grid.Row="1" Classes="card" Margin="0,21,0,17" Padding="22,17">
    <Grid ColumnDefinitions="*,Auto">
     <StackPanel Spacing="5" VerticalAlignment="Center">
      <TextBlock Name="StatusText" Text="Waiting for external power" Foreground="#F7F9FC" FontSize="16" FontWeight="SemiBold"/>
      <TextBlock Name="DetailText" Text="Plug in the charger. We'll pretend this never happened." Foreground="#8F9BA8" FontSize="12.5"/>
     </StackPanel>
     <Grid Grid.Column="1" Width="102" Height="38" VerticalAlignment="Center">
      <Border Background="#0E151D" BorderBrush="#465566" BorderThickness="2" CornerRadius="8" Margin="0,0,7,0">
       <Grid Margin="4"><Border Name="BatteryFill" Background="#F4A300" CornerRadius="4" HorizontalAlignment="Left" Width="70"/><TextBlock Name="ChargeText" Text="--%" Foreground="#FFFFFF" FontSize="12.5" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Grid>
      </Border>
      <Border Width="7" Height="16" Background="#465566" CornerRadius="0,3,3,0" HorizontalAlignment="Right"/>
     </Grid>
    </Grid>
   </Border>
   <Grid Grid.Row="2" ColumnDefinitions="Auto,*,Auto">
    <Ellipse Name="PulseDot" Width="7" Height="7" Fill="#F4A300" VerticalAlignment="Center" Margin="0,0,9,0"/>
    <TextBlock Grid.Column="1" Name="FooterText" Text="Current objective: Locate the mysterious power cable..." Foreground="#778493" FontSize="12.5" VerticalAlignment="Center"/>
    <Border Grid.Column="2" Background="#151D27" BorderBrush="#344150" BorderThickness="1" CornerRadius="7" Padding="9,5" Margin="12,0,0,0">
     <StackPanel Orientation="Horizontal" Spacing="7"><TextBlock Text="ESC" Foreground="#D9E1EA" FontSize="11" FontWeight="SemiBold"/><TextBlock Text="Skip" Foreground="#7F8C9C" FontSize="11"/></StackPanel>
    </Border>
   </Grid>
  </Grid>
 </Grid>
</Window>
'@
    $window=[Avalonia.Markup.Xaml.AvaloniaRuntimeXamlLoader]::Load($xaml)
    $nameScope=[Avalonia.Controls.NameScope]::GetNameScope($window);if(-not $nameScope){throw 'Avalonia XAML NameScope was not created.'}
    $statusCard=$nameScope.Find('StatusCard');$statusText=$nameScope.Find('StatusText');$detailText=$nameScope.Find('DetailText');$chargeText=$nameScope.Find('ChargeText');$batteryFill=$nameScope.Find('BatteryFill');$pulseDot=$nameScope.Find('PulseDot');$footerText=$nameScope.Find('FooterText')
    $script:closeScheduled=$false;$script:pulseOn=$false;$script:closeTimer=$null
    $cancellation=[System.Threading.CancellationTokenSource]::new();$timer=[Avalonia.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds($PollIntervalMilliseconds)
    $updateState={
        $state=Get-PowerState;$window.Title="DeployR - Battery warning - $($state.Charge)% remaining";$chargeText.Text="$($state.Charge)%";$batteryFill.Width=[Math]::Max(4,[Math]::Round(0.82*$state.Charge));$script:pulseOn=-not $script:pulseOn;$pulseDot.Opacity=if($script:pulseOn){1.0}else{0.35}
        if(($state.OnAC -or -not $state.HasBattery)-and -not $script:closeScheduled){$script:closeScheduled=$true;$statusCard.Background=[Avalonia.Media.SolidColorBrush]::Parse('#173127');$statusCard.BorderBrush=[Avalonia.Media.SolidColorBrush]::Parse('#4FA46D');$statusText.Text=if($state.HasBattery){'Power connected. Resuming deployment...'}else{'No battery detected. Continuing deployment...'};$detailText.Text='Power requirement satisfied.';$footerText.Text='System ready.';$pulseDot.Fill=[Avalonia.Media.SolidColorBrush]::Parse('#5EE08B');$batteryFill.Background=[Avalonia.Media.SolidColorBrush]::Parse('#5EE08B');$script:closeTimer=[Avalonia.Threading.DispatcherTimer]::new();$script:closeTimer.Interval=[TimeSpan]::FromMilliseconds($CloseDelayMilliseconds);$script:closeTimer.Add_Tick({$script:closeTimer.Stop();$timer.Stop();$window.Close()});$script:closeTimer.Start()}
    }
    $timer.Add_Tick($updateState)
    $window.Add_KeyDown({param($sender,$eventArgs);if($eventArgs.Key -eq [Avalonia.Input.Key]::Escape -and -not $script:closeScheduled){$script:closeScheduled=$true;Write-BatteryLog 'Power requirement manually bypassed with ESC.';$timer.Stop();if($script:closeTimer){$script:closeTimer.Stop()};$window.Close()}})
    $window.Add_Opened({$window.Activate();& $updateState;$timer.Start()})
    $window.Add_Closed({$timer.Stop();if($script:closeTimer){$script:closeTimer.Stop()};$cancellation.Cancel()})
    Write-BatteryLog 'Showing Avalonia battery warning.';$window.Show();[Avalonia.Threading.Dispatcher]::UIThread.MainLoop($cancellation.Token);Write-BatteryLog 'Avalonia battery warning closed normally.'
}catch{Write-BatteryLog "ERROR: $($_.Exception.ToString())"}finally{Remove-Item Env:\DEPLOYR_BATTERY_CLIENT_PATH -ErrorAction SilentlyContinue}
exit 0
