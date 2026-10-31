<#
.SYNOPSIS
    Displays a fireworks and confetti celebration after a successful deployment.

.DESCRIPTION
    Displays a celebratory fireworks and confetti window when a deployment
    or Task Sequence has completed successfully.

    The displayed message can be customized with -Message, and the display
    time can be controlled with -DurationSeconds.

    Press ESC to close the window manually.

.PARAMETER Message
    Specifies the message displayed in the center of the celebration window.

.PARAMETER DurationSeconds
    Specifies how long the celebration window remains visible, in seconds.

.EXAMPLE
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ".\TS-Fireworks.ps1" -Message "Task Sequence done!" -DurationSeconds 10
#>

param(
    [string]$Message = "Installation successful!`nEverything should work... probably.`n`n💖",
    [ValidateRange(1, 3600)]
    [int]$DurationSeconds = 10
)

$ErrorActionPreference = "Stop"

try {
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName WindowsBase

    $script:Random = [System.Random]::new()
    $script:Rockets = [System.Collections.Generic.List[object]]::new()
    $script:Particles = [System.Collections.Generic.List[object]]::new()
    $script:StartTime = [DateTime]::Now
    $script:EndTime = $script:StartTime.AddSeconds($DurationSeconds)
    $script:LastLaunch = [DateTime]::MinValue
    $script:Frame = 0

    $window = [System.Windows.Window]::new()
    $window.Title = "Deployment Celebration"
    $window.Width = 1000
    $window.Height = 650
    $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    $window.Background = [System.Windows.Media.Brushes]::Black
    $window.Topmost = $true
    $window.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $window.WindowStyle = [System.Windows.WindowStyle]::None

    $grid = [System.Windows.Controls.Grid]::new()
    $window.Content = $grid

    $canvas = [System.Windows.Controls.Canvas]::new()
    $canvas.Background = [System.Windows.Media.Brushes]::Black
    [void]$grid.Children.Add($canvas)

    $title = [System.Windows.Controls.TextBlock]::new()
    $title.Text = $Message
    $title.Foreground = [System.Windows.Media.Brushes]::White
    $title.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI")
    $title.FontSize = 48
    $title.FontWeight = [System.Windows.FontWeights]::Bold
    $title.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $title.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $title.TextAlignment = [System.Windows.TextAlignment]::Center
    $title.Opacity = 0.95
    $title.Effect = [System.Windows.Media.Effects.DropShadowEffect]@{
        Color       = [System.Windows.Media.Colors]::Gold
        BlurRadius  = 25
        ShadowDepth = 0
        Opacity     = 0.9
    }
    [void]$grid.Children.Add($title)

    $hint = [System.Windows.Controls.TextBlock]::new()
    $hint.Text = "DeployR"
    $hint.Foreground = [System.Windows.Media.Brushes]::Gray
    $hint.FontSize = 16
    $hint.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $hint.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
    $hint.Margin = [System.Windows.Thickness]::new(0, 0, 0, 18)
    $hint.Opacity = 0.8
    [void]$grid.Children.Add($hint)

    function New-RandomBrush {
        $color = [System.Windows.Media.Color]::FromRgb(
            [byte]$script:Random.Next(80, 256),
            [byte]$script:Random.Next(80, 256),
            [byte]$script:Random.Next(80, 256)
        )

        return [System.Windows.Media.SolidColorBrush]::new($color)
    }

    function Add-StarField {
        for ($i = 0; $i -lt 95; $i++) {
            $star = [System.Windows.Shapes.Ellipse]::new()
            $size = $script:Random.Next(1, 4)
            $star.Width = $size
            $star.Height = $size
            $star.Fill = [System.Windows.Media.Brushes]::White
            $star.Opacity = $script:Random.NextDouble() * 0.65 + 0.2

            [System.Windows.Controls.Canvas]::SetLeft($star, $script:Random.Next(0, [int]$window.Width))
            [System.Windows.Controls.Canvas]::SetTop($star, $script:Random.Next(0, [int]$window.Height))
            [void]$canvas.Children.Add($star)
        }
    }

    function Add-Rocket {
        $x = [double]$script:Random.Next(80, [int]($window.Width - 80))
        $y = [double]($window.Height - 40)
        $targetY = [double]$script:Random.Next(85, 310)

        $rocket = [System.Windows.Shapes.Ellipse]::new()
        $rocket.Width = 14
        $rocket.Height = 14
        $rocket.Fill = New-RandomBrush
        $rocket.Effect = [System.Windows.Media.Effects.DropShadowEffect]@{
            Color       = [System.Windows.Media.Colors]::White
            BlurRadius  = 15
            ShadowDepth = 0
            Opacity     = 1
        }

        $trail = [System.Windows.Shapes.Line]::new()
        $trail.X1 = $x + 7
        $trail.X2 = $x + 7
        $trail.Y1 = $y + 18
        $trail.Y2 = $y + 70
        $trail.Stroke = [System.Windows.Media.Brushes]::OrangeRed
        $trail.StrokeThickness = 4
        $trail.Opacity = 0.9

        [System.Windows.Controls.Canvas]::SetLeft($rocket, $x)
        [System.Windows.Controls.Canvas]::SetTop($rocket, $y)
        [void]$canvas.Children.Add($trail)
        [void]$canvas.Children.Add($rocket)

        $script:Rockets.Add([pscustomobject]@{
            Shape   = $rocket
            Trail   = $trail
            X       = $x
            Y       = $y
            TargetY = $targetY
            Speed   = [double]$script:Random.Next(12, 18)
        })
    }

    function Add-Explosion {
        param(
            [double]$X,
            [double]$Y,
            [int]$ParticleCount = 80
        )

        for ($i = 0; $i -lt $ParticleCount; $i++) {
            $particle = [System.Windows.Shapes.Ellipse]::new()
            $size = $script:Random.Next(5, 11)
            $particle.Width = $size
            $particle.Height = $size
            $particle.Fill = New-RandomBrush
            $particle.Opacity = 1

            [System.Windows.Controls.Canvas]::SetLeft($particle, $X)
            [System.Windows.Controls.Canvas]::SetTop($particle, $Y)
            [void]$canvas.Children.Add($particle)

            $angle = $script:Random.NextDouble() * [Math]::PI * 2
            $speed = $script:Random.NextDouble() * 7.5 + 2.0
            $life = $script:Random.Next(35, 65)

            $script:Particles.Add([pscustomobject]@{
                Shape   = $particle
                X       = $X
                Y       = $Y
                VX      = [Math]::Cos($angle) * $speed
                VY      = [Math]::Sin($angle) * $speed
                Life    = $life
                MaxLife = $life
            })
        }
    }

    function Add-Confetti {
        if (($script:Frame % 4) -ne 0) {
            return
        }

        for ($i = 0; $i -lt 5; $i++) {
            $particle = [System.Windows.Shapes.Rectangle]::new()
            $particle.Width = $script:Random.Next(5, 10)
            $particle.Height = $script:Random.Next(5, 10)
            $particle.Fill = New-RandomBrush
            $particle.Opacity = 0.95

            $x = [double]$script:Random.Next(0, [int]$window.Width)
            $y = -10.0
            [System.Windows.Controls.Canvas]::SetLeft($particle, $x)
            [System.Windows.Controls.Canvas]::SetTop($particle, $y)
            [void]$canvas.Children.Add($particle)

            $script:Particles.Add([pscustomobject]@{
                Shape   = $particle
                X       = $x
                Y       = $y
                VX      = $script:Random.NextDouble() * 2.0 - 1.0
                VY      = $script:Random.NextDouble() * 2.0 + 1.2
                Life    = 150
                MaxLife = 150
            })
        }
    }

    function Update-Scene {
        $now = [DateTime]::Now

        if (($now - $script:LastLaunch).TotalMilliseconds -gt 420) {
            Add-Rocket
            if ($script:Random.Next(0, 100) -gt 65) {
                Add-Rocket
            }
            $script:LastLaunch = $now
        }

        Add-Confetti

        for ($i = $script:Rockets.Count - 1; $i -ge 0; $i--) {
            $rocket = $script:Rockets[$i]
            $rocket.Y -= $rocket.Speed

            [System.Windows.Controls.Canvas]::SetTop($rocket.Shape, $rocket.Y)
            $rocket.Trail.Y1 = $rocket.Y + 18
            $rocket.Trail.Y2 = $rocket.Y + 70

            if ($rocket.Y -le $rocket.TargetY) {
                [void]$canvas.Children.Remove($rocket.Shape)
                [void]$canvas.Children.Remove($rocket.Trail)
                Add-Explosion -X $rocket.X -Y $rocket.Y -ParticleCount $script:Random.Next(60, 100)
                $script:Rockets.RemoveAt($i)
            }
        }

        for ($i = $script:Particles.Count - 1; $i -ge 0; $i--) {
            $particle = $script:Particles[$i]
            $particle.X += $particle.VX
            $particle.Y += $particle.VY
            $particle.VY += 0.06
            $particle.VX *= 0.992
            $particle.Life -= 1

            [System.Windows.Controls.Canvas]::SetLeft($particle.Shape, $particle.X)
            [System.Windows.Controls.Canvas]::SetTop($particle.Shape, $particle.Y)
            $particle.Shape.Opacity = [Math]::Max(0, $particle.Life / $particle.MaxLife)

            if ($particle.Life -le 0) {
                [void]$canvas.Children.Remove($particle.Shape)
                $script:Particles.RemoveAt($i)
            }
        }

        $elapsed = ([DateTime]::Now - $script:StartTime).TotalSeconds
        $title.Opacity = 0.72 + ([Math]::Sin($elapsed * 5) * 0.18)
    }

    Add-StarField

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(33)
    $timer.Add_Tick({
        try {
            $script:Frame++

            if ([DateTime]::Now -ge $script:EndTime) {
                $timer.Stop()
                $window.Close()
                return
            }

            Update-Scene
        }
        catch {
            try {
                $logPath = "C:\Temp\TS-Fireworks-error.txt"
                if (-not (Test-Path -LiteralPath "C:\Temp")) {
                    New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
                }
                $_ | Out-File -FilePath $logPath -Append -Encoding UTF8
            }
            catch {
            }
        }
    })

    $window.Add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::Escape) {
            $timer.Stop()
            $window.Close()
        }
    })

    $window.Add_Loaded({
        Add-Explosion -X 500 -Y 255 -ParticleCount 130
        $timer.Start()
    })

    try {
        $player = [System.Media.SoundPlayer]::new("C:\Windows\Media\tada.wav")
        $player.Play()
    }
    catch {
    }

    [void]$window.ShowDialog()
}
catch {
    if (-not (Test-Path -LiteralPath "C:\Temp")) {
        New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
    }

    $_ | Out-File -FilePath "C:\Temp\TS-Fireworks-error.txt" -Append -Encoding UTF8
    throw
}
