<#
.SYNOPSIS
    DeployR Avalonia fireworks screen that runs for a fixed duration and closes automatically.
.DESCRIPTION
    Starts the Avalonia UI in a clean standalone PowerShell child process. This avoids reusing the
    Avalonia application and UI thread previously created by BootMenu in the DeployR host.
#>
[CmdletBinding()]
param(
    [string]$Message = 'Everything should work, probably...',

    [ValidateRange(1, 120)]
    [int]$DurationSeconds = 10,

    [switch]$Windowed,
    [switch]$NoSound,

    [Parameter(DontShow)]
    [switch]$AvaloniaChild
)

$ErrorActionPreference = 'Stop'
$LogFile = 'C:\Temp\TS-Fireworks-Avalonia.log'

function Write-FireworksLog {
    param([string]$Text)

    try {
        if (-not (Test-Path -LiteralPath 'C:\Temp')) {
            New-Item -Path 'C:\Temp' -ItemType Directory -Force | Out-Null
        }
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $Text" | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
    catch { }
}

try {
    if (-not $AvaloniaChild) {
        # Start a genuinely clean PowerShell process. Do not assume that PowerShell 7
        # is installed in Program Files. BootMenu may run in a DeployR-hosted process.
        $CandidateHosts = @()

        try {
            $CurrentProcessPath = (Get-Process -Id $PID -ErrorAction Stop).Path
            if ($CurrentProcessPath -and ((Split-Path -Leaf $CurrentProcessPath) -in @('pwsh.exe', 'powershell.exe'))) {
                $CandidateHosts += $CurrentProcessPath
            }
        }
        catch { }

        if ($PSHOME) {
            $CandidateHosts += "$PSHOME\pwsh.exe"
            $CandidateHosts += "$PSHOME\powershell.exe"
        }

        $CandidateHosts += 'C:\Program Files\PowerShell\7\pwsh.exe'
        $CandidateHosts += 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'

        $PowerShellHost = $CandidateHosts |
            Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
            Select-Object -Unique -First 1

        if (-not $PowerShellHost) {
            Write-FireworksLog 'WARNING: No standalone PowerShell host was found. Fireworks skipped.'
            exit 0
        }

        # Environment variables are inherited by the child and avoid fragile quoting
        # when the message contains spaces, line breaks, emoji, or quotation marks.
        $PreviousMessage = $env:DEPLOYR_FIREWORKS_MESSAGE
        $PreviousDuration = $env:DEPLOYR_FIREWORKS_DURATION
        $PreviousWindowed = $env:DEPLOYR_FIREWORKS_WINDOWED
        $PreviousNoSound = $env:DEPLOYR_FIREWORKS_NOSOUND

        try {
            $env:DEPLOYR_FIREWORKS_MESSAGE = $Message
            $env:DEPLOYR_FIREWORKS_DURATION = [string]$DurationSeconds
            $env:DEPLOYR_FIREWORKS_WINDOWED = if ($Windowed) { '1' } else { '0' }
            $env:DEPLOYR_FIREWORKS_NOSOUND = if ($NoSound) { '1' } else { '0' }

            if ([string]::IsNullOrWhiteSpace($PSCommandPath) -or -not (Test-Path -LiteralPath $PSCommandPath)) {
                Write-FireworksLog 'WARNING: Script path could not be resolved. Fireworks skipped.'
                exit 0
            }

            $Arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -AvaloniaChild' -f $PSCommandPath

            Write-FireworksLog "Starting isolated Avalonia process with '$PowerShellHost'."
            $Process = Start-Process -FilePath $PowerShellHost -ArgumentList $Arguments -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop
        }
        finally {
            $env:DEPLOYR_FIREWORKS_MESSAGE = $PreviousMessage
            $env:DEPLOYR_FIREWORKS_DURATION = $PreviousDuration
            $env:DEPLOYR_FIREWORKS_WINDOWED = $PreviousWindowed
            $env:DEPLOYR_FIREWORKS_NOSOUND = $PreviousNoSound
        }

        if ($null -ne $Process -and $Process.ExitCode -ne 0) {
            Write-FireworksLog "WARNING: The isolated fireworks process returned exit code $($Process.ExitCode). The task sequence will continue."
        }
        exit 0
    }

    # Read values inherited from the parent process.
    if ($null -ne $env:DEPLOYR_FIREWORKS_MESSAGE) {
        $Message = $env:DEPLOYR_FIREWORKS_MESSAGE
    }
    if ($env:DEPLOYR_FIREWORKS_DURATION -match '^\d+$') {
        $DurationSeconds = [Math]::Min(120, [Math]::Max(1, [int]$env:DEPLOYR_FIREWORKS_DURATION))
    }
    $Windowed = ($env:DEPLOYR_FIREWORKS_WINDOWED -eq '1')
    $NoSound = ($env:DEPLOYR_FIREWORKS_NOSOUND -eq '1')

    Write-FireworksLog '=== CHILD START ==='
    Write-FireworksLog "Host: $((Get-Process -Id $PID).Path) | PS $($PSVersionTable.PSVersion) | Apartment: $([Threading.Thread]::CurrentThread.ApartmentState)"
    # Independent of the task-sequence provider. Use the local DeployR client runtime.
    $ClientPath = 'C:\Program Files\2Pint Software\DeployR\Client'
    if (-not (Test-Path -LiteralPath "$ClientPath\Avalonia.Base.dll")) {
        Write-FireworksLog "WARNING: DeployR Avalonia runtime was not found in '$ClientPath'. Fireworks skipped."
        exit 0
    }

    $AssemblyNames = @(
        'Avalonia.Base.dll',
        'Avalonia.dll',
        'Avalonia.Controls.dll',
        'Avalonia.Desktop.dll',
        'Avalonia.Fonts.Inter.dll',
        'Avalonia.Markup.dll',
        'Avalonia.Markup.Xaml.dll',
        'Avalonia.Markup.Xaml.Loader.dll',
        'Avalonia.MicroCom.dll',
        'Avalonia.OpenGL.dll',
        'Avalonia.Skia.dll',
        'Avalonia.Themes.Fluent.dll',
        'Avalonia.Win32.dll',
        'HarfBuzzSharp.dll',
        'SkiaSharp.dll'
    )

    foreach ($AssemblyName in $AssemblyNames) {
        $AssemblyPath = "$ClientPath\$AssemblyName"
        if (Test-Path -LiteralPath $AssemblyPath) {
            [System.Reflection.Assembly]::LoadFrom($AssemblyPath) | Out-Null
        }
    }

    $Builder = [Avalonia.AppBuilder]::Configure[Avalonia.Application]()
    $Builder = [Avalonia.AppBuilderDesktopExtensions]::UsePlatformDetect($Builder)

    try {
        $PlatformOptions = [Avalonia.Win32PlatformOptions]::new()
        $RenderingModes = [System.Collections.Generic.List[Avalonia.Win32RenderingMode]]::new()
        $RenderingModes.Add([Avalonia.Win32RenderingMode]::Software)
        $PlatformOptions.RenderingMode = $RenderingModes
        $Builder = $Builder.With[Avalonia.Win32PlatformOptions]($PlatformOptions)
    }
    catch {
        Write-FireworksLog "Software rendering preference unavailable: $($_.Exception.Message)"
    }

    try { $Builder = [Avalonia.InterFontApplicationBuilderExtension]::WithInterFont($Builder) } catch { }
    $Builder.SetupWithoutStarting() | Out-Null
    [Avalonia.Application]::Current.Styles.Add([Avalonia.Themes.Fluent.FluentTheme]::new())

    $SafeMessage = [System.Security.SecurityElement]::Escape($Message)
    $Xaml = @"
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="DeployR - Installation successful"
        Width="1280" Height="720"
        MinWidth="800" MinHeight="450"
        WindowStartupLocation="CenterScreen"
        CanResize="False"
        Topmost="True"
        ShowInTaskbar="False"
        Background="#02030A">
  <Grid Background="#02030A">
    <!-- Fixed 16:9 design surface inside a Viewbox gives predictable scaling at mixed DPI. -->
    <Viewbox Stretch="Fill" StretchDirection="Both" HorizontalAlignment="Stretch" VerticalAlignment="Stretch">
      <Grid Width="1280" Height="720" Background="#02030A">
        <Canvas Name="Sky" Width="1280" Height="720" ClipToBounds="True">
          <Canvas.Background>
            <LinearGradientBrush StartPoint="0%,0%" EndPoint="100%,100%">
              <GradientStop Color="#02040D" Offset="0" />
              <GradientStop Color="#071830" Offset="0.46" />
              <GradientStop Color="#170824" Offset="1" />
            </LinearGradientBrush>
          </Canvas.Background>
        </Canvas>

        <!-- Lightweight party ambience, deliberately no giant circles. -->
        <Border Name="TopGlow" Height="1" VerticalAlignment="Top" Margin="0" CornerRadius="0" Opacity="0" IsVisible="False">
          <Border.Background>
            <LinearGradientBrush StartPoint="0%,50%" EndPoint="100%,50%">
              <GradientStop Color="#0022D3EE" Offset="0" />
              <GradientStop Color="#22D3EE" Offset="0.25" />
              <GradientStop Color="#A855F7" Offset="0.52" />
              <GradientStop Color="#F472B6" Offset="0.76" />
              <GradientStop Color="#00F472B6" Offset="1" />
            </LinearGradientBrush>
          </Border.Background>
        </Border>
        <TextBlock Name="PartyMark" Text="✦" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,58,0,0"
                   Foreground="#8BE9FD" FontSize="30" Opacity="0.82" />

        <!-- Event-poster energy behind the HUD. -->
        <TextBlock Name="MegaWowBack" Text="SUCCESS" HorizontalAlignment="Center" VerticalAlignment="Center"
                   Foreground="#0D72E9FF" FontSize="190" FontWeight="Black" LetterSpacing="18" Margin="0,-250,0,0" />
        <TextBlock Name="MegaWowBottom" Text="LET'S GO!" HorizontalAlignment="Center" VerticalAlignment="Bottom"
                   Foreground="#0CF472B6" FontSize="122" FontWeight="Black" LetterSpacing="14" Margin="0,0,0,-18" />
        <!-- Party rails: cheap visual energy, no expensive blur layers. -->
        <Border Name="LeftRail" Width="1" Height="1" IsVisible="False" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="52,0,0,0" CornerRadius="3" Opacity="0.48">
          <Border.Background><LinearGradientBrush StartPoint="50%,0%" EndPoint="50%,100%"><GradientStop Color="#0022D3EE" Offset="0"/><GradientStop Color="#22D3EE" Offset="0.5"/><GradientStop Color="#00A855F7" Offset="1"/></LinearGradientBrush></Border.Background>
        </Border>
        <Border Name="RightRail" Width="1" Height="1" IsVisible="False" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,52,0" CornerRadius="3" Opacity="0.48">
          <Border.Background><LinearGradientBrush StartPoint="50%,0%" EndPoint="50%,100%"><GradientStop Color="#00F472B6" Offset="0"/><GradientStop Color="#F472B6" Offset="0.5"/><GradientStop Color="#00A855F7" Offset="1"/></LinearGradientBrush></Border.Background>
        </Border>
        <TextBlock Name="LeftSpark" Text="✦" IsVisible="False" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="65,0,0,0" Foreground="#67E8F9" FontSize="22" Opacity="0.7"/>
        <TextBlock Name="RightSpark" Text="✦" IsVisible="False" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,65,0" Foreground="#F9A8D4" FontSize="22" Opacity="0.7"/>

        <!-- Premium glass success card. -->
        <Border Width="960" Height="408" HorizontalAlignment="Center" VerticalAlignment="Center"
                CornerRadius="38" BorderThickness="3"
                Background="#B5070C18" BoxShadow="0 44 125 0 #F0000000">
          <Border.BorderBrush>
            <LinearGradientBrush StartPoint="0%,0%" EndPoint="100%,100%">
              <GradientStop Color="#F022D3EE" Offset="0" />
              <GradientStop Color="#EE38BDF8" Offset="0.48" />
              <GradientStop Color="#E6A855F7" Offset="0.76" />
              <GradientStop Color="#E6F472B6" Offset="1" />
            </LinearGradientBrush>
          </Border.BorderBrush>
          <Grid Margin="42,28,42,25">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto" />
              <RowDefinition Height="*" />
              <RowDefinition Height="Auto" />
            </Grid.RowDefinitions>

            <Grid Grid.Row="0">
              <StackPanel Orientation="Horizontal" Spacing="10" HorizontalAlignment="Left">
                <Border CornerRadius="14" Padding="15,8" Background="#2538BDF8" BorderBrush="#4538BDF8" BorderThickness="1">
                  <StackPanel Orientation="Horizontal" Spacing="9">
                    <Ellipse Width="8" Height="8" Fill="#34D399" VerticalAlignment="Center" />
                    <TextBlock Text="INSTALLATION COMPLETE" Foreground="#CFF7FF" FontSize="12"
                               FontWeight="SemiBold" LetterSpacing="1.7" VerticalAlignment="Center" />
                  </StackPanel>
                </Border>
              </StackPanel>
              <TextBlock Text="DEPLOYR" HorizontalAlignment="Right" VerticalAlignment="Center"
                         Foreground="#8DC8DE" FontSize="14" FontWeight="Bold" LetterSpacing="3" />
            </Grid>

            <StackPanel Grid.Row="1" HorizontalAlignment="Center" VerticalAlignment="Center"
                        MaxWidth="800" Spacing="15">
              <TextBlock Name="PartyText" Text="MISSION ACCOMPLISHED"
                         HorizontalAlignment="Center" Foreground="#D5FAFF" FontSize="13"
                         FontWeight="Bold" LetterSpacing="2.5" Opacity="0.82" />
              <Grid Width="96" Height="96" HorizontalAlignment="Center">
                <Border Name="SuccessRingOuter" Width="96" Height="96" CornerRadius="48" BorderBrush="#6622D3EE" BorderThickness="1.5"/>
                <Border Name="SuccessRingMid" Width="82" Height="82" CornerRadius="41" BorderBrush="#80A855F7" BorderThickness="1.5"/>
                <Border Width="68" Height="68" CornerRadius="34" Background="#3034D399" BorderBrush="#B034D399" BorderThickness="2">
                  <TextBlock Text="✓" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#75FBD0" FontSize="44" FontWeight="Bold" />
                </Border>
              </Grid>
              <TextBlock Name="TitleText" Text="Installation successful!"
                         HorizontalAlignment="Center" TextAlignment="Center"
                         Foreground="#FFFFFF" FontSize="60" FontWeight="Bold" LetterSpacing="1.1" />
              <Border Width="330" Height="5" CornerRadius="2" HorizontalAlignment="Center">
                <Border.Background>
                  <LinearGradientBrush StartPoint="0%,50%" EndPoint="100%,50%">
                    <GradientStop Color="#22D3EE" Offset="0" />
                    <GradientStop Color="#A855F7" Offset="0.52" />
                    <GradientStop Color="#F472B6" Offset="1" />
                  </LinearGradientBrush>
                </Border.Background>
              </Border>
              <TextBlock Text="$SafeMessage" HorizontalAlignment="Center" TextAlignment="Center"
                         TextWrapping="Wrap" Foreground="#E4F4FC" FontSize="28"
                         FontWeight="SemiBold" LineHeight="38" />
              <TextBlock Name="StatusText" Text="CONFIDENCE LEVEL: SUSPICIOUSLY HIGH"
                         HorizontalAlignment="Center" Foreground="#55778C" FontSize="10"
                         FontWeight="SemiBold" LetterSpacing="1.9" />
            </StackPanel>

            <Grid Grid.Row="2">
              <StackPanel Orientation="Horizontal" Spacing="8" HorizontalAlignment="Left">
                <TextBlock Text="ESC" Foreground="#9CB6C7" FontSize="11" FontWeight="Bold" />
                <TextBlock Text="TO CLOSE" Foreground="#526D80" FontSize="11" LetterSpacing="1" />
              </StackPanel>
              <StackPanel Orientation="Horizontal" Spacing="9" HorizontalAlignment="Right">
                <Ellipse Width="7" Height="7" Fill="#34D399" VerticalAlignment="Center" />
                <TextBlock Text="SYSTEM READY" Foreground="#7898AA" FontSize="11"
                           FontWeight="SemiBold" LetterSpacing="1.4" />
              </StackPanel>
            </Grid>
          </Grid>
        </Border>

        <!-- Small signature outside the card. -->
        <TextBlock Text="MISSION COMPLETE  •  BUILT BY DEPLOYR"
                   HorizontalAlignment="Center" VerticalAlignment="Bottom" Margin="0,0,0,22"
                   Foreground="#40596C" FontSize="10" FontWeight="SemiBold" LetterSpacing="1.8" />
      </Grid>
    </Viewbox>
  </Grid>
</Window>
"@

    # Parse and all later control access happen on this child process' owning UI thread.
    Write-FireworksLog 'Parsing XAML.'
    $Window = [Avalonia.Markup.Xaml.AvaloniaRuntimeXamlLoader]::Parse($Xaml)
    Write-FireworksLog 'XAML parsed.'
    $NameScope = [Avalonia.Controls.NameScope]::GetNameScope($Window)
    $Canvas = $NameScope.Find('Sky')
    $TitleText = $NameScope.Find('TitleText')
    $StatusText = $NameScope.Find('StatusText')
    $TopGlow = $NameScope.Find('TopGlow')
    $PartyMark = $NameScope.Find('PartyMark')
    $PartyText = $NameScope.Find('PartyText')
    $LeftRail = $NameScope.Find('LeftRail')
    $RightRail = $NameScope.Find('RightRail')
    $LeftSpark = $NameScope.Find('LeftSpark')
    $RightSpark = $NameScope.Find('RightSpark')
    $MegaWowBack = $NameScope.Find('MegaWowBack')
    $MegaWowBottom = $NameScope.Find('MegaWowBottom')
    $SuccessRingOuter = $NameScope.Find('SuccessRingOuter')
    $SuccessRingMid = $NameScope.Find('SuccessRingMid')

    if (-not $Windowed) {
        $Window.SystemDecorations = 'None'
        $Window.WindowState = [Avalonia.Controls.WindowState]::FullScreen
        $Window.CanResize = $false
    }

    $Random = [System.Random]::new()
    $Rockets = [System.Collections.Generic.List[object]]::new()
    $Particles = [System.Collections.Generic.List[object]]::new()
    $Palettes = @(
        @('#38BDF8', '#22D3EE', '#A5F3FC', '#FFFFFF'),
        @('#F59E0B', '#FBBF24', '#FDE68A', '#FFFFFF'),
        @('#A855F7', '#EC4899', '#F0ABFC', '#FFFFFF'),
        @('#22C55E', '#34D399', '#BBF7D0', '#FFFFFF'),
        @('#EF4444', '#FB7185', '#FECDD3', '#FFFFFF')
    )
    $StartTime = [DateTime]::Now
    $EndTime = $StartTime.AddSeconds($DurationSeconds)
    $script:LastLaunch = [DateTime]::MinValue
    $script:PaletteIndex = 0
    $script:FrameNumber = 0
    $script:Closing = $false
    $script:FinaleTriggered = $false
    $PartyMarkRotate = [Avalonia.Media.RotateTransform]::new(0)
    $LeftSparkRotate = [Avalonia.Media.RotateTransform]::new(0)
    $RightSparkRotate = [Avalonia.Media.RotateTransform]::new(0)
    $RingScaleTransform = [Avalonia.Media.ScaleTransform]::new(1.0, 1.0)
    $RingRotateTransform = [Avalonia.Media.RotateTransform]::new(0)
    $PartyMark.RenderTransform = $PartyMarkRotate
    $LeftSpark.RenderTransform = $LeftSparkRotate
    $RightSpark.RenderTransform = $RightSparkRotate
    $SuccessRingOuter.RenderTransform = $RingScaleTransform
    $SuccessRingMid.RenderTransform = $RingRotateTransform

    function New-Brush([string]$Color) {
        [Avalonia.Media.SolidColorBrush]::new([Avalonia.Media.Color]::Parse($Color))
    }

    function Get-SkyWidth { 1280.0 }
    function Get-SkyHeight { 720.0 }

    function Add-StarField {
        # Fewer stars means fewer Avalonia controls to render every frame.
        for ($Index = 0; $Index -lt 55; $Index++) {
            $Star = [Avalonia.Controls.Shapes.Ellipse]::new()
            $Size = if (($Index % 9) -eq 0) { 2.2 } else { 1.1 }
            $Star.Width = $Size
            $Star.Height = $Size
            $Star.Fill = New-Brush $(if (($Index % 7) -eq 0) { '#67E8F9' } else { '#D9F2FF' })
            $Star.Opacity = 0.18 + ($Random.NextDouble() * 0.48)
            [Avalonia.Controls.Canvas]::SetLeft($Star, $Random.NextDouble() * 1280)
            [Avalonia.Controls.Canvas]::SetTop($Star, $Random.NextDouble() * 720)
            $Canvas.Children.Add($Star)
        }
    }

    function Add-Particle {
        param([double]$X, [double]$Y, [double]$VelocityX, [double]$VelocityY,
              [int]$Life, [double]$Size, [string]$Color, [double]$Gravity = 0.055)

        if ($Particles.Count -ge 1200) { return }
        $Shape = [Avalonia.Controls.Shapes.Ellipse]::new()
        $Shape.Width = $Size
        $Shape.Height = $Size
        $Shape.Fill = New-Brush $Color
        $Shape.Opacity = 0.96
        [Avalonia.Controls.Canvas]::SetLeft($Shape, $X)
        [Avalonia.Controls.Canvas]::SetTop($Shape, $Y)
        $Canvas.Children.Add($Shape)
        $Particles.Add([pscustomobject]@{
            Shape = $Shape; X = $X; Y = $Y; VelocityX = $VelocityX; VelocityY = $VelocityY
            Life = $Life; MaximumLife = $Life; Gravity = $Gravity
        })
    }

    function Add-Explosion {
        param([double]$X, [double]$Y, [string[]]$Palette, [int]$Count = 38)

        # Evenly distributed sparks look cleaner than a dense random blob.
        $Rotation = $Random.NextDouble() * [Math]::PI * 2
        for ($Index = 0; $Index -lt $Count; $Index++) {
            $Angle = $Rotation + (($Index / [double]$Count) * [Math]::PI * 2) + (($Random.NextDouble() - 0.5) * 0.09)
            $Speed = 2.2 + ($Random.NextDouble() * 3.8)
            $Life = $Random.Next(30, 52)
            $Size = 2.4 + ($Random.NextDouble() * 2.6)
            Add-Particle -X $X -Y $Y -VelocityX ([Math]::Cos($Angle) * $Speed) `
                -VelocityY ([Math]::Sin($Angle) * $Speed) -Life $Life -Size $Size `
                -Color $Palette[$Random.Next(0, $Palette.Count)]
        }

        # Bright, short-lived core gives a crisp pop without hundreds of objects.
        for ($Index = 0; $Index -lt 8; $Index++) {
            $Angle = $Random.NextDouble() * [Math]::PI * 2
            $Speed = 0.6 + ($Random.NextDouble() * 2.0)
            Add-Particle -X $X -Y $Y -VelocityX ([Math]::Cos($Angle) * $Speed) `
                -VelocityY ([Math]::Sin($Angle) * $Speed) -Life $Random.Next(10, 18) `
                -Size (3.5 + $Random.NextDouble() * 3.0) -Color '#FFFFFF' -Gravity 0.025
        }
    }



    function Add-Fountain {
        param([double]$X,[int]$Count=14,[string[]]$Palette=@('#22D3EE','#A855F7','#F472B6','#FBBF24'))
        for ($i=0; $i -lt $Count; $i++) {
            $Spread = ($Random.NextDouble()-0.5) * 4.8
            Add-Particle -X $X -Y 705 -VelocityX $Spread -VelocityY (-(5.2 + $Random.NextDouble()*5.0)) `
                -Life $Random.Next(38,66) -Size (2.2+$Random.NextDouble()*3.0) `
                -Color $Palette[$Random.Next(0,$Palette.Count)] -Gravity 0.12
        }
    }

    function Add-Starburst {
        param([double]$X,[double]$Y,[string[]]$Palette,[int]$Arms=10)
        $Rotation=$Random.NextDouble()*[Math]::PI*2
        for($arm=0;$arm -lt $Arms;$arm++){
            $Angle=$Rotation+(($arm/[double]$Arms)*[Math]::PI*2)
            for($j=1;$j -le 4;$j++){
                $Speed=1.6+($j*1.15)
                Add-Particle -X $X -Y $Y -VelocityX ([Math]::Cos($Angle)*$Speed) -VelocityY ([Math]::Sin($Angle)*$Speed) `
                    -Life (28+$j*5) -Size (2.0+$j*0.48) -Color $Palette[($arm+$j)%$Palette.Count] -Gravity 0.04
            }
        }
    }

    function Add-RingExplosion {
        param([double]$X,[double]$Y,[string[]]$Palette,[int]$Count=48,[double]$Speed=4.8)
        $Rotation = $Random.NextDouble() * [Math]::PI * 2
        for ($i=0; $i -lt $Count; $i++) {
            $Angle = $Rotation + (($i / [double]$Count) * [Math]::PI * 2)
            $Jitter = ($Random.NextDouble() - 0.5) * 0.22
            Add-Particle -X $X -Y $Y -VelocityX ([Math]::Cos($Angle) * ($Speed + $Jitter)) `
                -VelocityY ([Math]::Sin($Angle) * ($Speed + $Jitter)) -Life $Random.Next(34,54) `
                -Size (2.2 + $Random.NextDouble()*2.5) -Color $Palette[$Random.Next(0,$Palette.Count)] -Gravity 0.045
        }
    }

    function Add-PartyCannons {
        $Colors = @('#22D3EE','#A855F7','#F472B6','#FBBF24','#34D399','#FFFFFF')
        foreach ($Side in @(-1,1)) {
            $X = if ($Side -lt 0) { 42.0 } else { 1238.0 }
            for ($i=0; $i -lt 18; $i++) {
                $Vx = $Side * (3.2 + $Random.NextDouble()*4.8)
                if ($Side -gt 0) { $Vx = -$Vx }
                Add-Particle -X $X -Y (560 + $Random.NextDouble()*70) -VelocityX $Vx `
                    -VelocityY (-(4.0 + $Random.NextDouble()*5.0)) -Life $Random.Next(48,76) `
                    -Size (2.7 + $Random.NextDouble()*3.0) -Color $Colors[$Random.Next(0,$Colors.Count)] -Gravity 0.10
            }
        }
    }

    function Add-ConfettiBurst {
        param([int]$Count = 18)
        $Colors = @('#22D3EE','#A855F7','#F472B6','#FBBF24','#34D399','#FFFFFF')
        for ($i = 0; $i -lt $Count; $i++) {
            $x = 80 + ($Random.NextDouble() * 1120)
            $y = -10 - ($Random.NextDouble() * 50)
            Add-Particle -X $x -Y $y `
                -VelocityX (($Random.NextDouble() - 0.5) * 1.9) `
                -VelocityY (1.5 + $Random.NextDouble() * 2.2) `
                -Life $Random.Next(55, 85) -Size (2.2 + $Random.NextDouble() * 2.8) `
                -Color $Colors[$Random.Next(0,$Colors.Count)] -Gravity 0.035
        }
    }

    function Add-Rocket {
        if ($Rockets.Count -ge 9) { return }
        $Shape = [Avalonia.Controls.Shapes.Ellipse]::new()
        $Shape.Width = 4.5
        $Shape.Height = 4.5
        $Shape.Fill = New-Brush '#F8FAFC'
        $Shape.Opacity = 0.95
        $X = 110 + ($Random.NextDouble() * 1060)
        $Y = 730
        [Avalonia.Controls.Canvas]::SetLeft($Shape, $X)
        [Avalonia.Controls.Canvas]::SetTop($Shape, $Y)
        $Canvas.Children.Add($Shape)
        $Rockets.Add([pscustomobject]@{
            Shape = $Shape; X = $X; Y = $Y
            VelocityX = ($Random.NextDouble() - 0.5) * 0.75
            VelocityY = -(8.8 + $Random.NextDouble() * 2.5)
            TargetY = 55 + ($Random.NextDouble() * 190)
            Palette = $Palettes[$script:PaletteIndex % $Palettes.Count]
        })
        $script:PaletteIndex++
    }

    function Close-Fireworks {
        if ($script:Closing) { return }
        $script:Closing = $true
        try { $Timer.Stop() } catch { }
        try { $Window.Close() } catch { }
    }

    # 30 FPS is intentionally capped. PowerShell object updates at 60 FPS create no useful visual gain here.
    $Timer = [Avalonia.Threading.DispatcherTimer]::new()
    $Timer.Interval = [TimeSpan]::FromMilliseconds(33)
    $Timer.Add_Tick({
        try {
            $Now = [DateTime]::Now
            if ($Now -ge $EndTime) { Close-Fireworks; return }
            $Elapsed = ($Now - $StartTime).TotalSeconds
            $script:FrameNumber++
            # Persistent corner fountains for the complete show. Small recurring bursts keep them continuous
            # without adding permanent controls or unbounded particle growth.
            if (($script:FrameNumber % 6) -eq 0 -and $Particles.Count -lt 900) {
                Add-Fountain -X 68 -Count 5
                Add-Fountain -X 1212 -Count 5
            }
            $Remaining = ($EndTime - $Now).TotalSeconds
            $Finale = $Remaining -le [Math]::Min(5.0, [Math]::Max(2.5, $DurationSeconds * 0.20))
            if (($script:FrameNumber % 42) -eq 0 -and $Particles.Count -lt 860) { Add-ConfettiBurst -Count 10 }
            if (($script:FrameNumber % 54) -eq 0 -and -not $Finale) {
                $Side = $Random.Next(0, 2)
                $rx = if ($Side -eq 0) { 70 + $Random.NextDouble()*300 } else { 910 + $Random.NextDouble()*300 }
                $ry = 45 + $Random.NextDouble()*180
                if (($script:FrameNumber % 108) -eq 0) {
                    Add-Starburst -X $rx -Y $ry -Palette $Palettes[$Random.Next(0,$Palettes.Count)] -Arms 11
                } else {
                    Add-RingExplosion -X $rx -Y $ry -Palette $Palettes[$Random.Next(0,$Palettes.Count)] -Count 38 -Speed 4.1
                }
            }
            if (($script:FrameNumber % 45) -eq 0 -and $Particles.Count -lt 840) {
                Add-Fountain -X $(if (($script:FrameNumber % 108) -eq 0) { 150 } else { 1130 }) -Count 9
            }
            if ($Finale -and -not $script:FinaleTriggered) {
                $script:FinaleTriggered = $true
                Add-PartyCannons
                Add-Fountain -X 120 -Count 22
                Add-Fountain -X 1160 -Count 22
                Add-RingExplosion -X 150 -Y 125 -Palette $Palettes[2] -Count 50 -Speed 5.2
                Add-Starburst -X 390 -Y 82 -Palette $Palettes[3] -Arms 13
                Add-RingExplosion -X 640 -Y 118 -Palette $Palettes[0] -Count 56 -Speed 5.4
                Add-Starburst -X 890 -Y 82 -Palette $Palettes[4] -Arms 13
                Add-RingExplosion -X 1130 -Y 125 -Palette $Palettes[1] -Count 50 -Speed 5.2
            }
            $Opening = $Elapsed -lt [Math]::Min(4.0, [Math]::Max(2.0, $DurationSeconds * 0.35))
            $LaunchInterval = if ($Finale) {
                0.11
            }
            elseif ($Opening) {
                0.12 + ($Random.NextDouble() * 0.08)
            }
            else {
                0.28 + ($Random.NextDouble() * 0.18)
            }

            if (($Now - $script:LastLaunch).TotalSeconds -ge $LaunchInterval) {
                Add-Rocket
                if ($Finale -and $Rockets.Count -lt 6) { Add-Rocket; Add-Rocket } elseif ($Opening -and $Rockets.Count -lt 7 -and ($script:FrameNumber % 10) -eq 0) { Add-Rocket; if ($Rockets.Count -lt 7) { Add-Rocket } }
                $script:LastLaunch = $Now
            }

            for ($Index = $Rockets.Count - 1; $Index -ge 0; $Index--) {
                $Rocket = $Rockets[$Index]
                $Rocket.X += $Rocket.VelocityX
                $Rocket.Y += $Rocket.VelocityY
                $Rocket.VelocityY += 0.10
                [Avalonia.Controls.Canvas]::SetLeft($Rocket.Shape, $Rocket.X)
                [Avalonia.Controls.Canvas]::SetTop($Rocket.Shape, $Rocket.Y)

                # One tiny trail spark every other frame, not a continuous object hose.
                if (($script:FrameNumber % 3) -eq 0 -and $Particles.Count -lt 930) {
                    Add-Particle -X ($Rocket.X + 1) -Y ($Rocket.Y + 7) `
                        -VelocityX (($Random.NextDouble() - 0.5) * 0.35) `
                        -VelocityY (0.8 + $Random.NextDouble() * 0.8) `
                        -Life 11 -Size 2.0 -Color '#FDE68A' -Gravity 0.02
                }

                if (($Rocket.Y -le $Rocket.TargetY) -or ($Rocket.VelocityY -ge -1.2)) {
                    $Canvas.Children.Remove($Rocket.Shape)
                    $Rockets.RemoveAt($Index)
                    Add-Explosion -X $Rocket.X -Y $Rocket.Y -Palette $Rocket.Palette -Count $(if ($Finale) { 54 } else { 42 })
                }
            }

            for ($Index = $Particles.Count - 1; $Index -ge 0; $Index--) {
                $Particle = $Particles[$Index]
                $Particle.X += $Particle.VelocityX
                $Particle.Y += $Particle.VelocityY
                $Particle.VelocityY += $Particle.Gravity
                $Particle.VelocityX *= 0.982
                $Particle.Life--
                [Avalonia.Controls.Canvas]::SetLeft($Particle.Shape, $Particle.X)
                [Avalonia.Controls.Canvas]::SetTop($Particle.Shape, $Particle.Y)
                $Progress = [Math]::Max(0, $Particle.Life / [double]$Particle.MaximumLife)
                $Particle.Shape.Opacity = [Math]::Min(1, $Progress * $Progress * 1.35)
                if ($Particle.Life -le 0 -or $Particle.Y -gt 735) {
                    $Canvas.Children.Remove($Particle.Shape)
                    $Particles.RemoveAt($Index)
                }
            }

            $Pulse = 0.92 + ([Math]::Sin($Elapsed * 2.8) * 0.08)
            $TitleText.Opacity = 0.97 + ([Math]::Sin($Elapsed * 2.2) * 0.03)
            $TopGlow.Opacity = $Pulse
            $PartyMark.Opacity = 0.58 + ([Math]::Sin($Elapsed * 4.2) * 0.24)
            $PartyMarkRotate.Angle = $Elapsed * 42
            $PartyText.Opacity = 0.76 + ([Math]::Sin($Elapsed * 2.4) * 0.15)
            $RailPulse = 0.34 + ([Math]::Abs([Math]::Sin($Elapsed * 3.4)) * 0.50)
            $LeftRail.Opacity = $RailPulse
            $RightRail.Opacity = 0.34 + ([Math]::Abs([Math]::Cos($Elapsed * 3.4)) * 0.50)
            $LeftSparkRotate.Angle = -$Elapsed * 70
            $RightSparkRotate.Angle = $Elapsed * 70
            $LeftSpark.Opacity = 0.40 + ([Math]::Abs([Math]::Sin($Elapsed * 4.8)) * 0.55)
            $RightSpark.Opacity = 0.40 + ([Math]::Abs([Math]::Cos($Elapsed * 4.8)) * 0.55)
            $MegaWowBack.Opacity = 0.045 + ([Math]::Abs([Math]::Sin($Elapsed * 1.7)) * 0.055)
            $MegaWowBottom.Opacity = 0.035 + ([Math]::Abs([Math]::Cos($Elapsed * 1.5)) * 0.045)
            $RingScale = 0.95 + ([Math]::Abs([Math]::Sin($Elapsed * 2.4)) * 0.10)
            $RingScaleTransform.ScaleX = $RingScale
            $RingScaleTransform.ScaleY = $RingScale
            $SuccessRingOuter.Opacity = 0.42 + ([Math]::Abs([Math]::Sin($Elapsed * 2.4))*0.36)
            $RingRotateTransform.Angle = -$Elapsed * 42
            $SuccessRingMid.Opacity = 0.48 + ([Math]::Abs([Math]::Cos($Elapsed * 2.4))*0.30)
            if ($Finale) { $StatusText.Text = 'FINAL SEQUENCE  •  ABSOLUTELY UNNECESSARY' }
        }
        catch {
            Write-FireworksLog "Timer error: $($_.Exception.ToString())"
            Close-Fireworks
        }
    })

    $Cancellation = [System.Threading.CancellationTokenSource]::new()
    $Window.Add_KeyDown({ if ($_.Key -eq [Avalonia.Input.Key]::Escape) { Close-Fireworks } })
    $Window.Add_Closed({ $Cancellation.Cancel() })
    $Window.Add_Opened({
        Add-StarField
        Add-Starburst -X 115 -Y 138 -Palette $Palettes[2] -Arms 12
        Add-RingExplosion -X 300 -Y 88 -Palette $Palettes[0] -Count 44 -Speed 4.8
        Add-Starburst -X 500 -Y 145 -Palette $Palettes[4] -Arms 11
        Add-RingExplosion -X 780 -Y 92 -Palette $Palettes[1] -Count 46 -Speed 5.0
        Add-Starburst -X 985 -Y 142 -Palette $Palettes[3] -Arms 12
        Add-RingExplosion -X 1170 -Y 96 -Palette $Palettes[2] -Count 44 -Speed 4.8
        Add-PartyCannons
        Add-Fountain -X 95 -Count 20
        Add-Fountain -X 1185 -Count 20
        Add-ConfettiBurst -Count 22
        Add-Fountain -X 68 -Count 24
        Add-Fountain -X 1212 -Count 24
        Add-Rocket
        Add-Rocket
        Add-Rocket
        Add-Rocket
        Add-Rocket
        $Timer.Start()
    })

    if (-not $NoSound) {
        try { [System.Media.SoundPlayer]::new('C:\Windows\Media\tada.wav').Play() } catch { }
    }

    Write-FireworksLog 'Showing window.'
    $Window.Show()
    Write-FireworksLog 'Window shown; entering dispatcher loop.'
    try {
        [Avalonia.Threading.Dispatcher]::UIThread.MainLoop($Cancellation.Token)
    }
    catch [System.OperationCanceledException] { }

    Write-FireworksLog 'Avalonia child process completed normally.'
    exit 0
}
catch {
    Write-FireworksLog "FAILSAFE: $($_.Exception.ToString())"
    exit 0
}
