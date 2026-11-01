function global:ShowMaskedInputWithGif {
    [CmdletBinding()]
    param(
        [string]$GifPath = "$PSScriptRoot\dennis-nedry.gif",
        [string]$Title   = "Password",
        [string]$Prompt  = "This deployment role requires a password.",
        [switch]$ReturnSecureString
    )

    # Integrated role authentication in the main window.
    # Function name and return values are retained to preserve calling behavior.
    if (-not $script:form -or $script:form.IsDisposed) {
        throw 'The main window is not available.'
    }

    $script:OemPasswordResult = $null
    $script:OemPasswordDone = $false

    $overlay = New-Object System.Windows.Forms.Panel
    $overlay.Dock = 'Fill'
    $overlay.BackColor = [System.Drawing.Color]::FromArgb(8,16,30)
    $overlay.Padding = New-Object System.Windows.Forms.Padding(40)

    $center = New-Object System.Windows.Forms.TableLayoutPanel
    $center.Dock = 'Fill'
    $center.BackColor = [System.Drawing.Color]::Transparent
    $center.ColumnCount = 3
    $center.RowCount = 3
    [void]$center.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,25)))
    [void]$center.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,50)))
    [void]$center.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,25)))
    [void]$center.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,18)))
    [void]$center.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,64)))
    [void]$center.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,18)))
    $overlay.Controls.Add($center)

    $card = New-Object System.Windows.Forms.Panel
    $card.Dock = 'Fill'
    $card.Padding = New-Object System.Windows.Forms.Padding(34)
    $card.BackColor = [System.Drawing.Color]::FromArgb(18,29,48)
    $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $center.Controls.Add($card,1,1)

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.BackColor = [System.Drawing.Color]::Transparent
    $layout.ColumnCount = 1
    $layout.RowCount = 8
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,54)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,45)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,30)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,54)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,40)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,52)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,5)))
    $card.Controls.Add($layout)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'PROTECTED ROLE'
    $lblTitle.Dock = 'Fill'
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI',22,[System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::White
    $lblTitle.TextAlign = 'MiddleCenter'
    $layout.Controls.Add($lblTitle,0,0)

    $lblPrompt = New-Object System.Windows.Forms.Label
    $lblPrompt.Text = $Prompt
    $lblPrompt.Dock = 'Fill'
    $lblPrompt.Font = New-Object System.Drawing.Font('Segoe UI',11)
    $lblPrompt.ForeColor = [System.Drawing.Color]::FromArgb(157,177,205)
    $lblPrompt.TextAlign = 'MiddleCenter'
    $layout.Controls.Add($lblPrompt,0,1)

    $lblPassword = New-Object System.Windows.Forms.Label
    $lblPassword.Text = 'Password'
    $lblPassword.Dock = 'Fill'
    $lblPassword.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $lblPassword.ForeColor = [System.Drawing.Color]::White
    $lblPassword.TextAlign = 'BottomLeft'
    $layout.Controls.Add($lblPassword,0,2)

    $passwordRow = New-Object System.Windows.Forms.TableLayoutPanel
    $passwordRow.Dock = 'Fill'
    $passwordRow.ColumnCount = 2
    $passwordRow.RowCount = 1
    $passwordRow.BackColor = [System.Drawing.Color]::Transparent
    [void]$passwordRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,82)))
    [void]$passwordRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,18)))
    $layout.Controls.Add($passwordRow,0,3)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Dock = 'Fill'
    $textbox.Margin = New-Object System.Windows.Forms.Padding(0,6,8,6)
    $textbox.Font = New-Object System.Drawing.Font('Segoe UI',14)
    $textbox.UseSystemPasswordChar = $true
    $textbox.BackColor = [System.Drawing.Color]::FromArgb(244,247,251)
    $textbox.ForeColor = [System.Drawing.Color]::FromArgb(16,24,39)
    $passwordRow.Controls.Add($textbox,0,0)

    $toggle = New-Object System.Windows.Forms.Button
    $toggle.Text = 'Show'
    $toggle.Dock = 'Fill'
    $toggle.Margin = New-Object System.Windows.Forms.Padding(0,6,0,6)
    $toggle.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $toggle.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(54,89,138)
    $toggle.BackColor = [System.Drawing.Color]::FromArgb(24,34,53)
    $toggle.ForeColor = [System.Drawing.Color]::White
    $toggle.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $passwordRow.Controls.Add($toggle,1,0)

    $lblMessage = New-Object System.Windows.Forms.Label
    $lblMessage.Text = 'Authorization is required for this deployment role.'
    $lblMessage.Dock = 'Fill'
    $lblMessage.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $lblMessage.ForeColor = [System.Drawing.Color]::FromArgb(143,227,255)
    $lblMessage.TextAlign = 'MiddleLeft'
    $layout.Controls.Add($lblMessage,0,4)

    $buttonRow = New-Object System.Windows.Forms.TableLayoutPanel
    $buttonRow.Dock = 'Fill'
    $buttonRow.ColumnCount = 2
    $buttonRow.RowCount = 1
    $buttonRow.BackColor = [System.Drawing.Color]::Transparent
    [void]$buttonRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,50)))
    [void]$buttonRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,50)))
    $layout.Controls.Add($buttonRow,0,6)
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'BACK'
    $cancel.Dock = 'Fill'
    $cancel.Margin = New-Object System.Windows.Forms.Padding(0,0,8,0)
    $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancel.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(90,110,140)
    $cancel.BackColor = [System.Drawing.Color]::FromArgb(32,44,64)
    $cancel.ForeColor = [System.Drawing.Color]::White
    $cancel.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
    $buttonRow.Controls.Add($cancel,0,0)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'UNLOCK ROLE'
    $ok.Dock = 'Fill'
    $ok.Margin = New-Object System.Windows.Forms.Padding(8,0,0,0)
    $ok.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $ok.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(114,199,255)
    $ok.BackColor = [System.Drawing.Color]::FromArgb(0,120,255)
    $ok.ForeColor = [System.Drawing.Color]::White
    $ok.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
    $buttonRow.Controls.Add($ok,1,0)

    $toggle.Add_Click({
        $textbox.UseSystemPasswordChar = -not $textbox.UseSystemPasswordChar
        $toggle.Text = if ($textbox.UseSystemPasswordChar) { 'Show' } else { 'Hide' }
        $textbox.Focus()
    })

    $submitAction = {
        if ($textbox.Text -eq 'Password') {
            $script:OemPasswordResult = $textbox.Text
            $script:OemPasswordDone = $true
        }
        else {
            $lblMessage.Text = 'Incorrect password. Try again.'
            $lblMessage.ForeColor = [System.Drawing.Color]::FromArgb(255,128,128)
            $textbox.Clear()
            $textbox.Focus()
        }
    }

    $ok.Add_Click($submitAction)
    $textbox.Add_KeyDown({
        param($sender,$e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            & $submitAction
            $e.Handled = $true
            $e.SuppressKeyPress = $true
        }
        elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $script:OemPasswordResult = 'BACK'
            $script:OemPasswordDone = $true
            $e.Handled = $true
            $e.SuppressKeyPress = $true
        }
    })
    $cancel.Add_Click({
        $script:OemPasswordResult = 'BACK'
        $script:OemPasswordDone = $true
    })

    $form.Controls.Add($overlay)
    $overlay.BringToFront()
    $form.ActiveControl = $textbox
    [void]$textbox.Focus()

    while (-not $script:OemPasswordDone -and -not $form.IsDisposed) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 25
    }

    if (-not $overlay.IsDisposed) {
        $form.Controls.Remove($overlay)
        $overlay.Dispose()
    }

    $result = $script:OemPasswordResult

    if ($ReturnSecureString -and $result -ne 'BACK' -and $null -ne $result) {
        return ConvertTo-SecureString $result -AsPlainText -Force
    }

    return $result
}

# ============================================================
# WINFORMS GUI
# ============================================================

$script:form = New-Object System.Windows.Forms.Form
$form = $script:form
$form.Text = $script:BootMenuConfig.Settings.WindowTitle
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(8,16,30)
$form.ForeColor = [System.Drawing.Color]::White
$form.KeyPreview = $true
$form.TopMost = $true
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.MinimumSize = New-Object System.Drawing.Size(1000,650)

if ($Windowed) {
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.ClientSize = New-Object System.Drawing.Size(1200,750)
    $form.TopMost = $false
}
else {
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
}

# Reduce flashing during resize and repaint.
$doubleBufferedProperty = [System.Windows.Forms.Control].GetProperty(
    'DoubleBuffered',
    [System.Reflection.BindingFlags]'NonPublic, Instance'
)
$doubleBufferedProperty.SetValue($form, $true, $null)

# Background gradient.
$form.Add_Paint({
    param($sender,$e)
    $rect = $sender.ClientRectangle
    if ($rect.Width -gt 0 -and $rect.Height -gt 0) {
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect,
            [System.Drawing.Color]::FromArgb(8,16,30),
            [System.Drawing.Color]::FromArgb(22,43,78),
            35
        )
        $e.Graphics.FillRectangle($brush,$rect)
        $brush.Dispose()
    }
})

$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = 'Fill'
$root.BackColor = [System.Drawing.Color]::Transparent
$root.Padding = New-Object System.Windows.Forms.Padding(28)
$root.ColumnCount = 2
$root.RowCount = 1
[void]$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,66)))
[void]$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,34)))
[void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$form.Controls.Add($root)

$leftCard = New-Object System.Windows.Forms.Panel
$leftCard.Dock = 'Fill'
$leftCard.Margin = New-Object System.Windows.Forms.Padding(0,0,14,0)
$leftCard.Padding = New-Object System.Windows.Forms.Padding(38)
$leftCard.BackColor = [System.Drawing.Color]::FromArgb(235,18,29,48)
$leftCard.BorderStyle = 'FixedSingle'
$root.Controls.Add($leftCard,0,0)

$rightCard = New-Object System.Windows.Forms.Panel
$rightCard.Dock = 'Fill'
$rightCard.Margin = New-Object System.Windows.Forms.Padding(14,0,0,0)
$rightCard.Padding = New-Object System.Windows.Forms.Padding(26)
$rightCard.BackColor = [System.Drawing.Color]::FromArgb(235,18,29,48)
$rightCard.BorderStyle = 'FixedSingle'
$root.Controls.Add($rightCard,1,0)

$left = New-Object System.Windows.Forms.TableLayoutPanel
$left.Dock = 'Fill'
$left.BackColor = [System.Drawing.Color]::Transparent
$left.ColumnCount = 1
$left.RowCount = 9
[void]$left.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,52)))
[void]$left.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,50)))
[void]$left.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,32)))
[void]$left.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,58)))
[void]$left.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,44)))
[void]$left.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,58)))
[void]$left.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,42)))
[void]$left.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
[void]$left.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,80)))
$leftCard.Controls.Add($left)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = $script:BootMenuConfig.Settings.MenuTitle
$lblTitle.Dock = 'Fill'
$lblTitle.Font = New-Object System.Drawing.Font('Segoe UI',23,[System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.TextAlign = 'MiddleLeft'
$left.Controls.Add($lblTitle,0,0)

$lblSubTitle = New-Object System.Windows.Forms.Label
$lblSubTitle.Text = 'DeployR Provisioning Center - 2Pint Software'
$lblSubTitle.Dock = 'Fill'
$lblSubTitle.Font = New-Object System.Drawing.Font('Segoe UI',11)
$lblSubTitle.ForeColor = [System.Drawing.Color]::FromArgb(110,161,255)
$lblSubTitle.TextAlign = 'TopLeft'
$left.Controls.Add($lblSubTitle,0,1)

$lblKommun = New-Object System.Windows.Forms.Label
$lblKommun.Text = 'Customer'
$lblKommun.Dock = 'Fill'
$lblKommun.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
$lblKommun.ForeColor = [System.Drawing.Color]::White
$lblKommun.TextAlign = 'BottomLeft'
$left.Controls.Add($lblKommun,0,2)

$cmbKommun = New-Object System.Windows.Forms.ComboBox
$cmbKommun.Dock = 'Fill'
$cmbKommun.Margin = New-Object System.Windows.Forms.Padding(0,6,0,6)
$cmbKommun.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbKommun.IntegralHeight = $false
$cmbKommun.DropDownHeight = 500
$cmbKommun.Font = New-Object System.Drawing.Font('Segoe UI',13)
$cmbKommun.BackColor = [System.Drawing.Color]::FromArgb(244,247,251)
$cmbKommun.ForeColor = [System.Drawing.Color]::FromArgb(16,24,39)
$cmbKommun.TabIndex = 0
$cmbKommun.TabStop = $true
$left.Controls.Add($cmbKommun,0,3)

$lblRoll = New-Object System.Windows.Forms.Label
$lblRoll.Text = 'Deployment role'
$lblRoll.Dock = 'Fill'
$lblRoll.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
$lblRoll.ForeColor = [System.Drawing.Color]::White
$lblRoll.TextAlign = 'BottomLeft'
$left.Controls.Add($lblRoll,0,4)

$cmbRoll = New-Object System.Windows.Forms.ComboBox
$cmbRoll.Dock = 'Fill'
$cmbRoll.Margin = New-Object System.Windows.Forms.Padding(0,6,0,6)
$cmbRoll.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbRoll.IntegralHeight = $false
$cmbRoll.DropDownHeight = 500
$cmbRoll.Font = New-Object System.Drawing.Font('Segoe UI',13)
$cmbRoll.BackColor = [System.Drawing.Color]::FromArgb(244,247,251)
$cmbRoll.ForeColor = [System.Drawing.Color]::FromArgb(16,24,39)
$cmbRoll.TabIndex = 1
$cmbRoll.TabStop = $true
$left.Controls.Add($cmbRoll,0,5)

$txtHint = New-Object System.Windows.Forms.Label
$txtHint.Text = 'Select a customer and deployment role.'
$txtHint.Dock = 'Fill'
$txtHint.Font = New-Object System.Drawing.Font('Segoe UI',10)
$txtHint.ForeColor = [System.Drawing.Color]::FromArgb(157,177,205)
$txtHint.TextAlign = 'TopLeft'
$left.Controls.Add($txtHint,0,6)

# Dynamic information panel. Hidden until a deployment role is selected.
$ProfileInfoPanel = New-Object System.Windows.Forms.Panel
$ProfileInfoPanel.Dock = 'Fill'
$ProfileInfoPanel.Margin = New-Object System.Windows.Forms.Padding(0,8,0,8)
$ProfileInfoPanel.Padding = New-Object System.Windows.Forms.Padding(18)
$ProfileInfoPanel.BackColor = [System.Drawing.Color]::FromArgb(16,24,39)
$ProfileInfoPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$ProfileInfoPanel.Visible = $false
$left.Controls.Add($ProfileInfoPanel,0,7)

$ProfileInfoLayout = New-Object System.Windows.Forms.TableLayoutPanel
$ProfileInfoLayout.Dock = 'Fill'
$ProfileInfoLayout.BackColor = [System.Drawing.Color]::Transparent
$ProfileInfoLayout.ColumnCount = 1
$ProfileInfoLayout.RowCount = 3
[void]$ProfileInfoLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,38)))
[void]$ProfileInfoLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,2)))
[void]$ProfileInfoLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$ProfileInfoPanel.Controls.Add($ProfileInfoLayout)

$lblProfileInfoTitle = New-Object System.Windows.Forms.Label
$lblProfileInfoTitle.Text = ''
$lblProfileInfoTitle.Dock = 'Fill'
$lblProfileInfoTitle.Font = New-Object System.Drawing.Font('Segoe UI',14,[System.Drawing.FontStyle]::Bold)
$lblProfileInfoTitle.ForeColor = [System.Drawing.Color]::White
$lblProfileInfoTitle.TextAlign = 'MiddleLeft'
$ProfileInfoLayout.Controls.Add($lblProfileInfoTitle,0,0)

$ProfileInfoSeparator = New-Object System.Windows.Forms.Label
$ProfileInfoSeparator.Dock = 'Fill'
$ProfileInfoSeparator.Margin = New-Object System.Windows.Forms.Padding(0)
$ProfileInfoSeparator.BackColor = [System.Drawing.Color]::FromArgb(54,89,138)
$ProfileInfoLayout.Controls.Add($ProfileInfoSeparator,0,1)

$txtProfileInfo = New-Object System.Windows.Forms.Label
$txtProfileInfo.Text = ''
$txtProfileInfo.Dock = 'Fill'
$txtProfileInfo.Padding = New-Object System.Windows.Forms.Padding(0,12,0,0)
$txtProfileInfo.Font = New-Object System.Drawing.Font('Segoe UI',10)
$txtProfileInfo.ForeColor = [System.Drawing.Color]::FromArgb(200,214,232)
$txtProfileInfo.TextAlign = 'TopLeft'
$ProfileInfoLayout.Controls.Add($txtProfileInfo,0,2)

$btnDeploy = New-Object System.Windows.Forms.Button
$btnDeploy.Dock = 'Fill'
$btnDeploy.Margin = New-Object System.Windows.Forms.Padding(0,8,0,0)
$btnDeploy.Text = 'WAITING FOR SELECTION'
$btnDeploy.Enabled = $false
$btnDeploy.UseVisualStyleBackColor = $false
$btnDeploy.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnDeploy.FlatAppearance.BorderSize = 2
$btnDeploy.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(54,89,138)
$btnDeploy.BackColor = [System.Drawing.Color]::FromArgb(24,34,53)
$btnDeploy.ForeColor = [System.Drawing.Color]::FromArgb(135,149,170)
$btnDeploy.Font = New-Object System.Drawing.Font('Segoe UI',15,[System.Drawing.FontStyle]::Bold)
$btnDeploy.TabIndex = 2
$btnDeploy.TabStop = $true
$left.Controls.Add($btnDeploy,0,8)

$right = New-Object System.Windows.Forms.TableLayoutPanel
$right.Dock = 'Fill'
$right.BackColor = [System.Drawing.Color]::Transparent
$right.ColumnCount = 1
$right.RowCount = 10
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,48)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,30)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,35)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,47)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,35)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,66)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,100)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,50)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,5)))
$rightCard.Controls.Add($right)

$lblSummary = New-Object System.Windows.Forms.Label
$lblSummary.Text = 'Summary'
$lblSummary.Dock = 'Fill'
$lblSummary.Font = New-Object System.Drawing.Font('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
$lblSummary.ForeColor = [System.Drawing.Color]::White
$right.Controls.Add($lblSummary,0,0)

$separator = New-Object System.Windows.Forms.Label
$separator.Dock = 'Top'
$separator.Height = 1
$separator.Margin = New-Object System.Windows.Forms.Padding(0,12,0,12)
$separator.BackColor = [System.Drawing.Color]::FromArgb(54,89,138)
$right.Controls.Add($separator,0,1)

$labelSummaryKommun = New-Object System.Windows.Forms.Label
$labelSummaryKommun.Text = 'Customer'
$labelSummaryKommun.Dock = 'Fill'
$labelSummaryKommun.Font = New-Object System.Drawing.Font('Segoe UI',11)
$labelSummaryKommun.ForeColor = [System.Drawing.Color]::FromArgb(157,177,205)
$labelSummaryKommun.TextAlign = 'BottomLeft'
$right.Controls.Add($labelSummaryKommun,0,2)

$txtKommun = New-Object System.Windows.Forms.Label
$txtKommun.Text = 'Not selected'
$txtKommun.Dock = 'Fill'
$txtKommun.Font = New-Object System.Drawing.Font('Segoe UI',16)
$txtKommun.ForeColor = [System.Drawing.Color]::White
$txtKommun.TextAlign = 'TopLeft'
$right.Controls.Add($txtKommun,0,3)

$labelSummaryRoll = New-Object System.Windows.Forms.Label
$labelSummaryRoll.Text = 'Deployment role'
$labelSummaryRoll.Dock = 'Fill'
$labelSummaryRoll.Font = New-Object System.Drawing.Font('Segoe UI',11)
$labelSummaryRoll.ForeColor = [System.Drawing.Color]::FromArgb(157,177,205)
$labelSummaryRoll.TextAlign = 'BottomLeft'
$right.Controls.Add($labelSummaryRoll,0,4)

$txtRoll = New-Object System.Windows.Forms.Label
$txtRoll.Text = 'Not selected'
$txtRoll.Dock = 'Fill'
$txtRoll.Font = New-Object System.Drawing.Font('Segoe UI',16)
$txtRoll.ForeColor = [System.Drawing.Color]::White
$txtRoll.TextAlign = 'TopLeft'
$txtRoll.AutoEllipsis = $true
$right.Controls.Add($txtRoll,0,5)

$StatusPanel = New-Object System.Windows.Forms.Panel
$StatusPanel.Dock = 'Fill'
$StatusPanel.Margin = New-Object System.Windows.Forms.Padding(0,8,0,8)
$StatusPanel.Padding = New-Object System.Windows.Forms.Padding(14)
$StatusPanel.BackColor = [System.Drawing.Color]::FromArgb(74,29,29)
$right.Controls.Add($StatusPanel,0,6)

$txtStatus = New-Object System.Windows.Forms.Label
$txtStatus.Text = 'WAITING'
$txtStatus.Dock = 'Top'
$txtStatus.Height = 32
$txtStatus.Font = New-Object System.Drawing.Font('Segoe UI',14,[System.Drawing.FontStyle]::Bold)
$txtStatus.ForeColor = [System.Drawing.Color]::FromArgb(255,128,128)
$StatusPanel.Controls.Add($txtStatus)

$txtStatusDetail = New-Object System.Windows.Forms.Label
$txtStatusDetail.Text = 'DeployR is waiting for your selection.'
$txtStatusDetail.Dock = 'Fill'
$txtStatusDetail.Font = New-Object System.Drawing.Font('Segoe UI',9)
$txtStatusDetail.ForeColor = [System.Drawing.Color]::White
$StatusPanel.Controls.Add($txtStatusDetail)
$txtStatusDetail.BringToFront()

$lblVariables = New-Object System.Windows.Forms.Label
$lblVariables.Text = 'Computer information'
$lblVariables.Dock = 'Fill'
$lblVariables.Font = New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold)
$lblVariables.ForeColor = [System.Drawing.Color]::White
$lblVariables.TextAlign = 'BottomLeft'
$right.Controls.Add($lblVariables,0,7)

$txtVariables = New-Object System.Windows.Forms.TextBox
$txtVariables.Dock = 'Fill'
$txtVariables.Multiline = $true
$txtVariables.ReadOnly = $true
$txtVariables.ScrollBars = 'None'
$txtVariables.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtVariables.BackColor = [System.Drawing.Color]::FromArgb(16,24,39)
$txtVariables.ForeColor = [System.Drawing.Color]::FromArgb(143,227,255)
$txtVariables.Font = New-Object System.Drawing.Font('Consolas',10)
$txtVariables.Text = 'Waiting for selection...'
$right.Controls.Add($txtVariables,0,8)

$script:SelectedMunicipality = $null
$script:SelectedRole = $null
$script:SelectedRoleCode = $null
$script:SelectedRoleItem = $null

function Get-KommunrollCode {
    param($RoleItem)
    if ($RoleItem.Code) { return [string]$RoleItem.Code }
    return $null
}

function Update-VariablePreview {
try {
    $RamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $Ram = "$RamGB GB"
}
catch {
    $Ram = "Unknown"
}
function Get-WinPEPrimaryDisk {
    [CmdletBinding()]
    param()

    $PhysicalDisks = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MediaType -notmatch 'Removable' -and
            $_.Model -notmatch 'USB|SD|Flash' -and
            $_.Size -gt 20GB
        } |
        Sort-Object Size -Descending

    if (-not $PhysicalDisks) {
        Write-Host "No suitable physical disk was found."
    }

    return $PhysicalDisks[0]
}

function Get-WinPEDiskSize {
    [CmdletBinding()]
    param()

    $Disk = Get-WinPEPrimaryDisk

    [PSCustomObject]@{
        DiskNumber = $Disk.Index
        Model      = $Disk.Model
        SizeGB     = [math]::Round($Disk.Size / 1GB)
        SizeTB     = [math]::Round($Disk.Size / 1TB,2)
    }
}
try {
    $DiskInfo = Get-WinPEDiskSize
}
catch {
    Write-Host "WARNING: Could not retrieve disk information."
    $DiskInfo = [PSCustomObject]@{
        DiskNumber = 'N/A'
        Model      = 'N/A'
        SizeGB     = 'N/A'
        SizeTB     = 'N/A'
    }
}
$NIC = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object IPEnabled | Select-Object -First 1
$IP  = ($NIC.IPAddress | Select-Object -First 1)
$MAC = $NIC.MACAddress

    $mod = ${TSEnv:ModelAlias}
    $sn = ${TSEnv:SerialNumber}
    $System = ${TSEnv:SystemAlias}
    $man = ${TSEnv:MakeAlias}

    $txtVariables.Text = @"
`
`Manufacturer: $man
`Model: $mod
`System: $System
`Serial number: $sn
` 
`Info
`────────────────
`Disk: $($DiskInfo.SizeGB) GB
`Memory: $Ram
`IP address: $IP
`MAC address: $MAC
"@
}

function Update-ProfileInfo {
    if (-not $script:SelectedRoleItem -or -not $script:SelectedRoleItem.Profile) {
        $lblProfileInfoTitle.Text = ''
        $txtProfileInfo.Text = ''
        $ProfileInfoPanel.Visible = $false
        return
    }
    $p = $script:SelectedRoleItem.Profile
    $c = @($p.AccentColor -split ',')
    $lblProfileInfoTitle.Text = [string]$p.Title
    $txtProfileInfo.Text = ($p.DescriptionLines -join "`r`n")
    $ProfileInfoSeparator.BackColor = [System.Drawing.Color]::FromArgb([int]$c[0],[int]$c[1],[int]$c[2])
    $ProfileInfoPanel.Visible = $true
}

function Update-UIState {
    $ready = [bool](
        $cmbKommun.SelectedItem -and
        $cmbRoll.SelectedItem -and
        $script:SelectedRoleItem
    )

    if ($ready) {
        $btnDeploy.Enabled = $true
        $btnDeploy.Text = 'START DEPLOYMENT'
        $btnDeploy.BackColor = [System.Drawing.Color]::FromArgb(0,120,255)
        $btnDeploy.ForeColor = [System.Drawing.Color]::White
        $btnDeploy.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(114,199,255)

        $txtStatus.Text = 'READY'
        $txtStatus.ForeColor = [System.Drawing.Color]::FromArgb(93,255,177)
        $txtStatusDetail.Text = 'The profile is ready. Deployment can start.'
        $StatusPanel.BackColor = [System.Drawing.Color]::FromArgb(24,51,40)
    }
    else {
        $btnDeploy.Enabled = $false
        $btnDeploy.Text = 'WAITING FOR SELECTION'
        $btnDeploy.BackColor = [System.Drawing.Color]::FromArgb(24,34,53)
        $btnDeploy.ForeColor = [System.Drawing.Color]::FromArgb(135,149,170)
        $btnDeploy.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(54,89,138)

        $txtStatus.Text = 'WAITING'
        $txtStatus.ForeColor = [System.Drawing.Color]::FromArgb(255,128,128)
        $txtStatusDetail.Text = 'DeployR is waiting. Select a customer.'
        $StatusPanel.BackColor = [System.Drawing.Color]::FromArgb(74,29,29)
    }

    Update-ProfileInfo
    Update-VariablePreview
}

foreach ($municipality in ($MainMenu | Sort-Object { $_.Text })) {
    [void]$cmbKommun.Items.Add([string]$municipality.Text)
}

$cmbKommun.Add_SelectedIndexChanged({
    $cmbRoll.Items.Clear()
    $cmbRoll.SelectedIndex = -1

    $script:SelectedMunicipality = [string]$cmbKommun.SelectedItem
    $script:SelectedRole = $null
    $script:SelectedRoleCode = $null
    $script:SelectedRoleItem = $null

    $txtKommun.Text = if ($script:SelectedMunicipality) { $script:SelectedMunicipality } else { 'Ej vald' }
    $txtRoll.Text = 'Not selected'

    $municipalityItem = $MainMenu | Where-Object { $_.Text -eq $script:SelectedMunicipality } | Select-Object -First 1
    if ($municipalityItem) {
        foreach ($roleItem in $municipalityItem.Menu) {
            [void]$cmbRoll.Items.Add([string]$roleItem.Text.Trim())
        }
    }

    $txtHint.Text = 'Customer loaded. Select a deployment role.'
    Update-UIState
})

$cmbRoll.Add_SelectedIndexChanged({
    $script:SelectedRole = [string]$cmbRoll.SelectedItem
    $script:SelectedRoleItem = $null
    $script:SelectedRoleCode = $null

    if ($script:SelectedMunicipality -and $script:SelectedRole) {
        $municipalityItem = $MainMenu | Where-Object { $_.Text -eq $script:SelectedMunicipality } | Select-Object -First 1
        $script:SelectedRoleItem = $municipalityItem.Menu | Where-Object { $_.Text.Trim() -eq $script:SelectedRole } | Select-Object -First 1
        $script:SelectedRoleCode = Get-KommunrollCode -RoleItem $script:SelectedRoleItem
    }

    $txtRoll.Text = if ($script:SelectedRole) { $script:SelectedRole } else { 'Ej vald' }

    if ($script:SelectedRole) {
        $txtHint.Text = 'Press Start Deployment when you are ready.'
    }

    Update-UIState
})

# ============================================================
# KEYBOARD NAVIGATION AND FOCUS HANDLING
# ============================================================

$normalLabelColor = [System.Drawing.Color]::White
$normalComboColor = [System.Drawing.Color]::FromArgb(244,247,251)

function Set-KeyboardHint {
    param([string]$Text)
    $txtHint.Text = $Text
}

$cmbKommun.Add_Enter({
    $lblKommun.Text = 'Customer'
    Set-KeyboardHint 'DeployR is waiting. Select a customer.'
})
$cmbKommun.Add_Leave({
    $lblKommun.Text = 'Customer'
    $lblKommun.ForeColor = $normalLabelColor
    $cmbKommun.BackColor = $normalComboColor
    $cmbKommun.ForeColor = [System.Drawing.Color]::FromArgb(16,24,39)
})

$cmbRoll.Add_Enter({
    $lblRoll.Text = 'Deployment role'
    Set-KeyboardHint 'Customer loaded. Select a deployment role.'
})
$cmbRoll.Add_Leave({
    $lblRoll.Text = 'Deployment role'
    $lblRoll.ForeColor = $normalLabelColor
    $cmbRoll.BackColor = $normalComboColor
    $cmbRoll.ForeColor = [System.Drawing.Color]::FromArgb(16,24,39)
})

$btnDeploy.Add_Enter({
    if ($btnDeploy.Enabled) {
        Set-KeyboardHint 'Press the button to start deployment.'
    }
})
$btnDeploy.Add_Leave({
    # Keep the button's normal appearance.
})

# Left and right arrows move between fields.
# Up and down arrows remain available to each ComboBox.
$cmbKommun.Add_KeyDown({
    param($sender,$e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Right) {
        [void]$cmbRoll.Focus()
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter -and -not $cmbKommun.DroppedDown) {
        $cmbKommun.DroppedDown = $true
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
})

$cmbRoll.Add_KeyDown({
    param($sender,$e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Left) {
        [void]$cmbKommun.Focus()
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Right) {
        if ($btnDeploy.Enabled) {
            [void]$btnDeploy.Focus()
        }
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter -and -not $cmbRoll.DroppedDown) {
        $cmbRoll.DroppedDown = $true
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
})

$btnDeploy.Add_KeyDown({
    param($sender,$e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Left -or
        $e.KeyCode -eq [System.Windows.Forms.Keys]::Up) {
        [void]$cmbRoll.Focus()
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
})

$btnDeploy.Add_MouseEnter({
    if ($btnDeploy.Enabled) {
        $btnDeploy.BackColor = [System.Drawing.Color]::FromArgb(20,155,255)
    }
})
$btnDeploy.Add_MouseLeave({
    if ($btnDeploy.Enabled) {
        $btnDeploy.BackColor = [System.Drawing.Color]::FromArgb(0,120,255)
    }
})

$btnDeploy.Add_Click({
    if (-not $script:SelectedRoleItem -or -not $script:SelectedRoleCode) {
        [System.Windows.Forms.MessageBox]::Show(
            'You must select both a customer and a deployment role.',
            'DeployR Provisioning Center - 2Pint Software',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    try {
        Invoke-DeployRAction -CustomerRole $script:SelectedRoleCode
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not apply the selected role:`r`n`r`n$($_.Exception.Message)",
            'DeployR Provisioning Center - 2Pint Software',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$form.Add_KeyDown({
    param($sender,$e)

    if ($e.Alt -and $e.KeyCode -eq [System.Windows.Forms.Keys]::F4) {
        $e.Handled = $true
        $e.SuppressKeyPress = $true
        return
    }

    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
        $cmbKommun.SelectedIndex = -1
        $cmbRoll.Items.Clear()
        $cmbRoll.SelectedIndex = -1
        $script:SelectedMunicipality = $null
        $script:SelectedRole = $null
        $script:SelectedRoleCode = $null
        $script:SelectedRoleItem = $null
        $txtKommun.Text = 'Not selected'
        $txtRoll.Text = 'Not selected'
        $txtHint.Text = 'Select a customer and deployment role.'
        Update-UIState
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
})

Update-UIState
$form.Add_Shown({
    $form.Activate()
    $form.BringToFront()

    $form.BeginInvoke([Action]{
        $form.Activate()
        $form.BringToFront()
        $form.ActiveControl = $cmbKommun
        [void]$cmbKommun.Focus()
        [void]$cmbKommun.Select()
    }) | Out-Null
})
[void]$form.ShowDialog()
$form.Dispose()