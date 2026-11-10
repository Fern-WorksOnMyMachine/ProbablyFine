[CmdletBinding()]
param(
    [ValidateRange(1, 20)]
    [int]$DemoProfile = 1,

    [Parameter(DontShow)]
    [switch]$AvaloniaChild
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$LogFile = 'C:\Windows\Temp\DeployR-ModelNotCertified-Avalonia.log'
$PayloadVariable = 'DEPLOYR_MODEL_POPUP_PAYLOAD'
$ClientPathVariable = 'DEPLOYR_MODEL_POPUP_CLIENT_PATH'

function Write-PopupLog {
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

function Get-ModelInformation {
    if ($AvaloniaChild -and [Environment]::GetEnvironmentVariable($PayloadVariable, 'Process')) {
        try {
            $bytes = [Convert]::FromBase64String([Environment]::GetEnvironmentVariable($PayloadVariable, 'Process'))
            $xml = [Text.Encoding]::UTF8.GetString($bytes)
            $data = [Management.Automation.PSSerializer]::Deserialize($xml)
            Write-PopupLog 'Loaded device information from the isolated-process payload.'
            return $data
        }
        catch {
            Write-PopupLog "Could not read child-process payload: $($_.Exception.Message)"
        }
    }

    try {
        Import-Module DeployR.Utility -ErrorAction Stop

        $data = [pscustomobject][ordered]@{
            Make         = [string]${TSEnv:Make}
            MakeAlias    = [string]${TSEnv:MakeAlias}
            ModelAlias   = [string]${TSEnv:ModelAlias}
            SystemAlias  = [string]${TSEnv:SystemAlias}
            SerialNumber = [string]${TSEnv:SerialNumber}
            DataSource   = 'DeployR task sequence environment'
        }

        foreach ($property in @('Make', 'MakeAlias', 'ModelAlias', 'SystemAlias', 'SerialNumber')) {
            if ([string]::IsNullOrWhiteSpace([string]$data.$property)) {
                $data.$property = 'Not set'
            }
        }

        Write-PopupLog 'DeployR.Utility imported and task sequence variables were read successfully.'
        return $data
    }
    catch {
        Write-PopupLog "DeployR task sequence environment unavailable. Loading demo values: $($_.Exception.Message)"

        return [pscustomobject][ordered]@{
            Make         = 'Lenovo'
            MakeAlias    = 'Lenovo'
            ModelAlias   = 'ThinkPad X1 Yoga Gen 7'
            SystemAlias  = '21CD'
            SerialNumber = 'DEMO-123456'
            DataSource   = 'Local demo values'
        }
    }
}

function ConvertTo-Payload {
    param([Parameter(Mandatory)]$InputObject)

    $xml = [Management.Automation.PSSerializer]::Serialize($InputObject)
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($xml))
}

function Find-DeployRClientPath {
    $candidates = [Collections.Generic.List[string]]::new()

    if ([Environment]::GetEnvironmentVariable($ClientPathVariable, 'Process')) {
        $candidates.Add([Environment]::GetEnvironmentVariable($ClientPathVariable, 'Process'))
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

        $controls = Get-ChildItem -LiteralPath $candidate -Filter 'Avalonia.Controls.dll' -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($controls) {
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

function Start-IsolatedAvaloniaChild {
    param(
        [Parameter(Mandatory)][string]$ClientPath,
        [Parameter(Mandatory)]$ModelInformation
    )

    if ([string]::IsNullOrWhiteSpace($PSCommandPath) -or -not (Test-Path -LiteralPath $PSCommandPath)) {
        throw 'The current script path could not be resolved.'
    }

    $candidateHosts = [Collections.Generic.List[string]]::new()

    $bundledHost = Get-ChildItem -LiteralPath $ClientPath -Filter 'pwsh.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($bundledHost) {
        $candidateHosts.Add($bundledHost)
    }

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

    $powerShellHost = $candidateHosts |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -Unique -First 1

    if (-not $powerShellHost) {
        throw 'No standalone PowerShell host was found for the Avalonia child process.'
    }

    [Environment]::SetEnvironmentVariable($PayloadVariable, (ConvertTo-Payload -InputObject $ModelInformation), 'Process')
    [Environment]::SetEnvironmentVariable($ClientPathVariable, $ClientPath, 'Process')

    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -AvaloniaChild' -f $PSCommandPath

    Write-PopupLog "Starting isolated Avalonia process with '$powerShellHost'."
    $process = Start-Process -FilePath $powerShellHost -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden

    if ($null -eq $process) {
        throw 'The isolated Avalonia process could not be created.'
    }

    Write-PopupLog "Isolated Avalonia process returned exit code $($process.ExitCode)."
}

try {
    Write-PopupLog "=== START === Child=$AvaloniaChild Host=$((Get-Process -Id $PID).Path) SystemDrive=$env:SystemDrive"

    $model = Get-ModelInformation

    Write-Host "`n============================================================" -ForegroundColor Red
    Write-Host 'MODEL NOT CERTIFIED'
    Write-Host '============================================================'
    Write-Host 'Model is NOT certified for OS deployment.'
    Write-Host 'Maybe it is too new, too old, too exotic or simply having a bad day.'
    Write-Host ''
    Write-Host "Make:        $($model.Make)"
    Write-Host "MakeAlias:   $($model.MakeAlias)"
    Write-Host "ModelAlias:  $($model.ModelAlias)"
    Write-Host "SystemAlias: $($model.SystemAlias)"
    Write-Host "Serial:      $($model.SerialNumber)"
    Write-Host ''
    Write-Host 'Deployment will now stop.'
    Write-Host 'We blame the hardware, not the deployment team.'
    Write-Host "============================================================`n"

    $clientPath = Find-DeployRClientPath
    Write-PopupLog "DeployR client path: $clientPath"

    $isWinPE = $env:SystemDrive -eq 'X:' -or $env:windir -like 'X:\*'

    if ($isWinPE -and -not $AvaloniaChild) {
        try {
            Start-IsolatedAvaloniaChild -ClientPath $clientPath -ModelInformation $model
        }
        catch {
            Write-PopupLog "ERROR: Isolated Avalonia start failed: $($_.Exception.Message)"
            throw
        }
        finally {
            [Environment]::SetEnvironmentVariable($PayloadVariable, $null, 'Process')
            [Environment]::SetEnvironmentVariable($ClientPathVariable, $null, 'Process')
        }

        exit 0
    }

    Import-AvaloniaRuntime -ClientPath $clientPath

    if (-not ('DeployRModelPopup.AvaloniaBootstrap' -as [type])) {
        $references = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object {
                $_.Location -and
                ($_.GetName().Name -like 'Avalonia*' -or $_.GetName().Name -eq 'SkiaSharp')
            } |
            Select-Object -ExpandProperty Location -Unique

        Add-Type -TypeDefinition @'
using Avalonia;
namespace DeployRModelPopup
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

    [DeployRModelPopup.AvaloniaBootstrap]::Setup()

    $xaml = @'
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="900" Height="600"
        MinWidth="680" MinHeight="500"
        MaxWidth="1180" MaxHeight="780"
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
    <Style Selector="Button.primary">
      <Setter Property="Background" Value="#D34841"/>
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="CornerRadius" Value="9"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="MinWidth" Value="190"/>
      <Setter Property="MinHeight" Value="40"/>
      <Setter Property="Padding" Value="22,10"/>
    </Style>
  </Window.Styles>

  <Grid RowDefinitions="5,*,76">
    <Border Grid.Row="0" Background="#D64C45"/>

    <Grid Grid.Row="1" Margin="48,36,48,28" RowDefinitions="Auto,*,Auto">
      <Grid Grid.Row="0" ColumnDefinitions="*,Auto">
        <StackPanel Grid.Column="0" Spacing="8">
          <TextBlock Text="DEPLOYMENT BLOCKED" Foreground="#E05B54"
                     FontSize="12" FontWeight="SemiBold" LetterSpacing="1.9"/>
          <TextBlock Text="Model not certified" Foreground="#F7F9FC"
                     FontSize="32" FontWeight="SemiBold"/>
          <TextBlock Text="This device is not approved for OS deployment."
                     Foreground="#AAB4C0" FontSize="14.5" TextWrapping="Wrap"/>
        </StackPanel>

        <Border Grid.Column="1" Width="68" Height="68"
                VerticalAlignment="Center" Margin="28,0,4,0"
                Background="#18D64C45" BorderBrush="#70D64C45"
                BorderThickness="1" CornerRadius="34">
          <Grid>
            <Path Width="36" Height="32" Stretch="Uniform" Fill="#E05B54"
                  Data="M24,2 L46,42 L2,42 Z"/>
            <TextBlock Text="!" Foreground="#FFFFFF" FontSize="21"
                       FontWeight="Bold" HorizontalAlignment="Center"
                       VerticalAlignment="Center" Margin="0,10,0,0"/>
          </Grid>
        </Border>
      </Grid>

      <Border Grid.Row="1" Margin="0,28,0,24" Padding="28,24"
              Background="#151E28" BorderBrush="#2B3948"
              BorderThickness="1" CornerRadius="18"
              MinHeight="235">
        <Grid RowDefinitions="Auto,1,*">
          <StackPanel Grid.Row="0" Spacing="5">
            <TextBlock Text="DEVICE INFORMATION" Foreground="#F7F9FC"
                       FontSize="13" FontWeight="SemiBold" LetterSpacing="1.35"/>
            <TextBlock Name="SourceText" Foreground="#718093" FontSize="11.5"/>
          </StackPanel>

          <Border Grid.Row="1" Background="#2B3948" Margin="0,18,0,20"/>

          <Grid Grid.Row="2" ColumnDefinitions="145,*"
                RowDefinitions="*,*,*,*,*" VerticalAlignment="Stretch">
            <TextBlock Grid.Row="0" Text="Make" Foreground="#8391A3" FontSize="13.5" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="1" Text="Make alias" Foreground="#8391A3" FontSize="13.5" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="2" Text="Model alias" Foreground="#8391A3" FontSize="13.5" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="3" Text="System alias" Foreground="#8391A3" FontSize="13.5" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="4" Text="Serial number" Foreground="#8391A3" FontSize="13.5" VerticalAlignment="Center"/>

            <TextBlock Name="MakeValue" FontSize="13.5" Grid.Row="0" Grid.Column="1" Foreground="#F1F4F8" FontWeight="SemiBold" VerticalAlignment="Center" TextWrapping="Wrap"/>
            <TextBlock Name="MakeAliasValue" FontSize="13.5" Grid.Row="1" Grid.Column="1" Foreground="#F1F4F8" FontWeight="SemiBold" VerticalAlignment="Center" TextWrapping="Wrap"/>
            <TextBlock Name="ModelAliasValue" FontSize="13.5" Grid.Row="2" Grid.Column="1" Foreground="#F1F4F8" FontWeight="SemiBold" VerticalAlignment="Center" TextWrapping="Wrap"/>
            <TextBlock Name="SystemAliasValue" FontSize="13.5" Grid.Row="3" Grid.Column="1" Foreground="#F1F4F8" FontWeight="SemiBold" VerticalAlignment="Center" TextWrapping="Wrap"/>
            <TextBlock Name="SerialValue" FontSize="13.5" Grid.Row="4" Grid.Column="1" Foreground="#F1F4F8" FontWeight="SemiBold" VerticalAlignment="Center" TextWrapping="Wrap"/>
          </Grid>
        </Grid>
      </Border>

      <StackPanel Grid.Row="2" Spacing="6">
        <TextBlock Text="Deployment will now stop." Foreground="#E05B54"
                   FontSize="15.5" FontWeight="SemiBold"/>
        <TextBlock Text="Maybe it is too new, too old, too exotic or simply having a bad day."
                   Foreground="#9BA7B5" FontSize="12.5" TextWrapping="Wrap"/>
        <TextBlock Text="We blame the hardware, not the deployment team."
                   Foreground="#687687" FontSize="12" FontStyle="Italic" TextWrapping="Wrap"/>
      </StackPanel>
    </Grid>

    <Border Grid.Row="2" Background="#101720"
            BorderBrush="#273341" BorderThickness="0,1,0,0">
      <Grid Margin="48,0" ColumnDefinitions="*,Auto">
        <TextBlock Text="No computers were harmed while displaying this message."
                   Foreground="#647284" FontSize="11.5"
                   TextWrapping="Wrap" VerticalAlignment="Center"
                   Margin="0,0,24,0"/>
        <Button Name="OkayButton" Grid.Column="1" Classes="primary"
                Content="OK, blame the hardware" VerticalAlignment="Center"/>
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

    $window.Title = 'DeployR - Model not certified'

    $nameScope.Find('MakeValue').Text = [string]$model.Make
    $nameScope.Find('MakeAliasValue').Text = [string]$model.MakeAlias
    $nameScope.Find('ModelAliasValue').Text = [string]$model.ModelAlias
    $nameScope.Find('SystemAliasValue').Text = [string]$model.SystemAlias
    $nameScope.Find('SerialValue').Text = [string]$model.SerialNumber
    $nameScope.Find('SourceText').Text = [string]$model.DataSource

    $okayButton = $nameScope.Find('OkayButton')
    $cancellation = [Threading.CancellationTokenSource]::new()

    $okayButton.Add_Click({ $window.Close() })
    $window.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.Key -in @([Avalonia.Input.Key]::Enter, [Avalonia.Input.Key]::Escape)) {
            $window.Close()
        }
    })
    $window.Add_Opened({
        $window.Activate()
        $okayButton.Focus() | Out-Null
    })
    $window.Add_Closed({ $cancellation.Cancel() })

    Write-PopupLog 'Showing Avalonia model certification popup.'
    $window.Show()
    [Avalonia.Threading.Dispatcher]::UIThread.MainLoop($cancellation.Token)
    Write-PopupLog 'Avalonia model certification popup closed normally.'
}
catch {
    Write-PopupLog "ERROR: $($_.Exception.ToString())"
    Write-Host 'Unable to display the model certification popup.' -ForegroundColor Red
    Write-Host "Popup error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    [Environment]::SetEnvironmentVariable($PayloadVariable, $null, 'Process')
    [Environment]::SetEnvironmentVariable($ClientPathVariable, $null, 'Process')
}

# This popup reports information only. The task sequence decides whether to stop.
exit 0
