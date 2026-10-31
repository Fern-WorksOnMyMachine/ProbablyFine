Import-Module DeployR.Utility
$msg = @"
Model is NOT certified for OS deployment.
Maybe it is too new, too old, too exotic or simply having a bad day.

Make:        $($TSEnv:Make)
MakeAlias:   $($TSEnv:MakeAlias)
ModelAlias:  $($TSEnv:ModelAlias)
SystemAlias: $($TSEnv:SystemAlias)
Serial:      $($TSEnv:SerialNumber)

Deployment will now stop.
We blame the hardware, not the deployment team.
"@

Write-Host "`n============================================================" -ForegroundColor Red
Write-Host "MODEL NOT CERTIFIED"
Write-Host "============================================================"
Write-Host $msg
Write-Host "============================================================`n"

try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # --- Helpers ---
    function Label($text,$x,$y,$w,$h,$size=10,$bold=$false,$color=[System.Drawing.Color]::Black) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text
        $l.Location = [Drawing.Point]::new($x,$y)
        $l.Size = [Drawing.Size]::new($w,$h)
        $l.ForeColor = $color
        $l.Font = [Drawing.Font]::new("Segoe UI",$size,
            $(if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}))
        return $l
    }

    $white  = [Drawing.Color]::White
    $panel  = [Drawing.Color]::FromArgb(245,247,250)
    $red    = [Drawing.Color]::FromArgb(196,43,28)
    $dark   = [Drawing.Color]::FromArgb(32,33,36)
    $text   = [Drawing.Color]::FromArgb(65,65,65)
    $muted  = [Drawing.Color]::FromArgb(100,100,100)
    $border = [Drawing.Color]::FromArgb(220,223,228)

    # --- Main window ---
    $form = New-Object Windows.Forms.Form
    $form.Text = "DeployR - Model not certified"
    $form.ClientSize = [Drawing.Size]::new(720,440)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $true
    $form.TopMost = $true
    $form.BackColor = $white
    $form.AutoScaleMode = "Dpi"
    $form.Icon = [Drawing.SystemIcons]::Error

    # --- Header ---
    $accent = New-Object Windows.Forms.Panel
    $accent.Size = [Drawing.Size]::new(720,5)
    $accent.BackColor = $red

    # --- Modern Windows 11 style icon ---
$icon = New-Object Windows.Forms.PictureBox
$icon.Location = [Drawing.Point]::new(32,37)
$icon.Size = [Drawing.Size]::new(48,48)
$icon.BackColor = [Drawing.Color]::Transparent

$bmp = New-Object Drawing.Bitmap 48,48
$g = [Drawing.Graphics]::FromImage($bmp)

$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# PC screen
$screenBrush = New-Object Drawing.SolidBrush (
    [Drawing.Color]::FromArgb(55,65,81)
)

$screenRect = [Drawing.Rectangle]::new(6,5,36,27)

$path = New-Object Drawing.Drawing2D.GraphicsPath
$path.AddArc(6,5,8,8,180,90)
$path.AddArc(34,5,8,8,270,90)
$path.AddArc(34,24,8,8,0,90)
$path.AddArc(6,24,8,8,90,90)
$path.CloseFigure()

$g.FillPath($screenBrush,$path)

# Screen
$displayBrush = New-Object Drawing.SolidBrush (
    [Drawing.Color]::FromArgb(235,238,242)
)

$g.FillRectangle($displayBrush,10,9,28,19)

# Stand
$standPen = New-Object Drawing.Pen (
    [Drawing.Color]::FromArgb(55,65,81),4
)

$g.DrawLine($standPen,24,32,24,38)
$g.DrawLine($standPen,17,40,31,40)

# Warning circle
$warningBrush = New-Object Drawing.SolidBrush (
    [Drawing.Color]::FromArgb(220,53,47)
)

$g.FillEllipse($warningBrush,28,26,18,18)

# Exclamation mark
$exclamationPen = New-Object Drawing.Pen (
    [Drawing.Color]::White,2.5
)

$exclamationPen.StartCap = [Drawing.Drawing2D.LineCap]::Round
$exclamationPen.EndCap   = [Drawing.Drawing2D.LineCap]::Round

$g.DrawLine($exclamationPen,37,30,37,36)
$g.FillEllipse(
    [Drawing.Brushes]::White,
    [Drawing.RectangleF]::new(35.8,39,2.4,2.4)
)

# Cleanup
$path.Dispose()
$screenBrush.Dispose()
$displayBrush.Dispose()
$standPen.Dispose()
$warningBrush.Dispose()
$exclamationPen.Dispose()
$g.Dispose()

$icon.Image = $bmp

    $form.Controls.Add($accent)
    $form.Controls.Add($icon)
    $form.Controls.Add((Label "Model is NOT certified for OS deployment." 105 30 580 30 13 $true $dark))
    $form.Controls.Add((Label "Maybe it is too new, too old, too exotic or simply having a bad day." 105 63 580 44 10 $false $muted))

    # --- Information panel ---
    $info = New-Object Windows.Forms.Panel
    $info.Location = [Drawing.Point]::new(105,120)
    $info.Size = [Drawing.Size]::new(580,175)
    $info.BackColor = $panel
    $info.BorderStyle = "FixedSingle"

    $info.Controls.Add((Label "DEVICE INFORMATION" 16 12 300 23 10 $true $dark))

    $names = "Make`r`nMakeAlias`r`nModelAlias`r`nSystemAlias`r`nSerial"
    $values = @(
        $TSEnv:Make
        $TSEnv:MakeAlias
        $TSEnv:ModelAlias
        $TSEnv:SystemAlias
        $TSEnv:SerialNumber
    ) -join "`r`n"

    $info.Controls.Add((Label $names 16 42 110 120 9.5 $false $muted))
    $info.Controls.Add((Label $values 130 42 430 120 9.5 $true $text))
    $form.Controls.Add($info)

    # --- Footer ---
    $form.Controls.Add((Label "Deployment will now stop." 105 315 580 28 11 $true $red))
    $form.Controls.Add((Label "We blame the hardware, not the deployment team." 105 345 580 28 10 $false $text))

    # --- Button area ---
    $buttons = New-Object Windows.Forms.Panel
    $buttons.Location = [Drawing.Point]::new(0,385)
    $buttons.Size = [Drawing.Size]::new(720,55)
    $buttons.BackColor = $panel

    $line = New-Object Windows.Forms.Panel
    $line.Size = [Drawing.Size]::new(720,1)
    $line.BackColor = $border

    $ok = New-Object Windows.Forms.Button
    $ok.Text = "OK"
    $ok.Size = [Drawing.Size]::new(110,32)
    $ok.Location = [Drawing.Point]::new(585,12)
    $ok.DialogResult = "OK"
    $ok.Font = [Drawing.Font]::new("Segoe UI",9.5)

    $buttons.Controls.Add($line)
    $buttons.Controls.Add($ok)
    $form.Controls.Add($buttons)

    $form.AcceptButton = $ok

    $form.Add_Shown({
        $form.BringToFront()
        $form.Activate()
        $ok.Select()
    })

    $null = $form.ShowDialog()

    if ($icon.Image) { $icon.Image.Dispose() }
    $form.Dispose()
}
catch {
    Write-Host "Unable to display error popup." -ForegroundColor Red
    Write-Host "Popup error: $($_.Exception.Message)" -ForegroundColor Red
}

exit 0