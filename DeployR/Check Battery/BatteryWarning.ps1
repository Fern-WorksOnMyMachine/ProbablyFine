function global:MessageBox {
    $charge = (Get-CimInstance Win32_Battery).EstimatedChargeRemaining
    $Message = "Connect the power cable to continue the installation."
    if (-not $Message) { $Message = 'Inget meddelande' }
    $Title = 'DeployR - Battery Warning - ' + $charge + '% left'

    Add-Type -AssemblyName System.Windows.Forms, System.Drawing

    # Colors
    $white  = [Drawing.Color]::White
    $panel  = [Drawing.Color]::FromArgb(245,247,250)
    $orange = [Drawing.Color]::FromArgb(232,156,0)
    $dark   = [Drawing.Color]::FromArgb(32,33,36)
    $text   = [Drawing.Color]::FromArgb(65,65,65)
    $muted  = [Drawing.Color]::FromArgb(100,100,100)
    $border = [Drawing.Color]::FromArgb(220,223,228)

    # Label helper
    function Label($text,$x,$y,$w,$h,$size=5,$bold=$false,$color=$dark) {
        $l = New-Object Windows.Forms.Label
        $l.Text = $text
        $l.AutoSize = $false
        $l.Location = [Drawing.Point]::new($x,$y)
        $l.Size = [Drawing.Size]::new($w,$h)
        $l.ForeColor = $color
        $l.BackColor = [Drawing.Color]::Transparent
        $l.Font = [Drawing.Font]::new(
            "Regular",
            $size,
            $(if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular})
        )
        $l
    }

    # Main window
    $ExitForm = New-Object Windows.Forms.Form
    $ExitForm.Text = $Title
    $ExitForm.ClientSize = [Drawing.Size]::new(800,350)
    $ExitForm.StartPosition = 'CenterScreen'
    $ExitForm.FormBorderStyle = 'FixedDialog'
    $ExitForm.TopMost = $true
    $ExitForm.ShowInTaskbar = $true
    $ExitForm.MaximizeBox = $false
    $ExitForm.MinimizeBox = $false
    $ExitForm.BackColor = $white

    # Accent
    $accent = New-Object Windows.Forms.Panel
    $accent.Size = [Drawing.Size]::new(800,5)
    $accent.BackColor = $orange
    $ExitForm.Controls.Add($accent)

    # Power adapter icon
    $icon = New-Object Windows.Forms.Panel
    $icon.Location = [Drawing.Point]::new(38,40)
    $icon.Size = [Drawing.Size]::new(72,72)
    $icon.BackColor = $white

    $icon.Add_Paint({
        $g = $_.Graphics
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias

        $c = [Drawing.Color]::FromArgb(70,75,82)

        $brush = New-Object Drawing.SolidBrush($c)
        $pen   = New-Object Drawing.Pen($c,2)

        # Adapter
        $g.FillRectangle($brush,14,23,34,26)
        $g.DrawRectangle($pen,14,23,34,26)

        # Plug pins
        $pin = New-Object Drawing.Pen($c,4)
        $pin.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $pin.EndCap   = [Drawing.Drawing2D.LineCap]::Round

        $g.DrawLine($pin,23,18,23,10)
        $g.DrawLine($pin,39,18,39,10)

        # Cable
        $cable = New-Object Drawing.Pen($c,4)
        $cable.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $cable.EndCap   = [Drawing.Drawing2D.LineCap]::Round

        $g.DrawArc($cable,28,43,32,24,0,180)
        $g.DrawLine($cable,44,67,44,71)

        # Power indicator
        $indicator = New-Object Drawing.SolidBrush($orange)
        $g.FillEllipse($indicator,52,25,9,9)

        $brush.Dispose()
        $pen.Dispose()
        $pin.Dispose()
        $cable.Dispose()
        $indicator.Dispose()
    })

    $ExitForm.Controls.Add($icon)

    # Header
    $ExitForm.Controls.Add(
        (Label "Power adapter required" 130 34 440 32 14 $true $dark)
    )

    $ExitForm.Controls.Add(
        (Label "Connect the charger to unlock deployment progress." 130 67 640 28 10 $false $muted)
    )

    # Message panel
    $info = New-Object Windows.Forms.Panel
    $info.Location = [Drawing.Point]::new(130,105)
    $info.Size = [Drawing.Size]::new(600,65)
    $info.BackColor = $panel
    $info.BorderStyle = 'FixedSingle'

    $info.Controls.Add(
        (Label $Message 15 18 640 30 10.5 $true $text)
    )

    $ExitForm.Controls.Add($info)

    # Footer
    $ExitForm.Controls.Add(
        (Label "Current objective: Find the power cable..." 130 185 640 25 9.5 $false $muted)
    )

    <# Auto close after 2 seconds
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 2000
    $timer.Add_Tick({
        $timer.Stop()
        $ExitForm.Close()
        $ExitForm.Dispose()
    })
    $timer.Start()#>

    # Kontrollera batteristatus varje sekund

    $script:BlinkState = $false

    $Color1 = [Drawing.Color]::FromArgb(255,243,205)  # Gul
    $Color2 = [Drawing.Color]::FromArgb(255,220,220)  # Ljus röd

    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 1000

    $timer.Add_Tick({
        $Battery = Get-CimInstance Win32_Battery

        # Uppdatera titel
        $ExitForm.Text = "DeployR - Battery Warning - $($Battery.EstimatedChargeRemaining)% left"
        # Växla färg
        if ($script:BlinkState) {
            $info.BackColor = $Color1
        }
        else {
            $info.BackColor = $Color2
        }

        $script:BlinkState = -not $script:BlinkState

        try {
            $Battery = Get-CimInstance Win32_Battery -ErrorAction Stop

            if ($Battery.BatteryStatus -eq 2) {
                $info.BackColor = [Drawing.Color]::FromArgb(220,255,220)
                Start-Sleep -Seconds 2
                $timer.Stop()

                

                

                $ExitForm.Close()
            }
        }
        catch {
            $timer.Stop()
            $ExitForm.Close()
        }
    })

    $timer.Start()

    # Show / Always on top
    $ExitForm.Add_Shown({
        $ExitForm.Activate()
        $ExitForm.BringToFront()
    })

    [void]$ExitForm.ShowDialog()

    if ($icon) {
        $icon.Dispose()
    }
}

#if ((Get-CimInstance -ClassName Win32_Battery).BatteryStatus -ne "2") {
    MessageBox
#}

#exit 0