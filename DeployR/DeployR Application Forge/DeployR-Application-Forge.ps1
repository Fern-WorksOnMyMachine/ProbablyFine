<#
.SYNOPSIS
    Creates or updates DeployR application content through a Windows Forms interface.

.DESCRIPTION
    Provides a standalone graphical interface for creating a new DeployR application
    content item or overwriting Version 1 of an existing application.

    The script uses the DeployR.Utility module and requires PowerShell 7.
    Set the DeployR passcode at the beginning of the script before running it.

    No environment-specific paths, customer information, server names, credentials,
    or other internal values are included.

.NOTES
    Requirements:
    - PowerShell 7 or later
    - DeployR.Utility
    - Access to the DeployR environment
#>

#Requires -Version 7.0

# Change this value before running the script.
$DeployRPasscode = 'CHANGE_ME'
$DeployRModulePath = 'C:\Program Files\2Pint Software\DeployR\Client\PSModules\DeployR.Utility'

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-OverwriteConfirmation {
    param(
        [Parameter(Mandatory)]
        [string]$ApplicationName
    )

    $confirmForm = New-Object System.Windows.Forms.Form
    $confirmForm.Text = 'DeployR Application Forge'
    $confirmForm.StartPosition = 'CenterParent'
    $confirmForm.Size = New-Object System.Drawing.Size(540, 245)
    $confirmForm.FormBorderStyle = 'FixedDialog'
    $confirmForm.MaximizeBox = $false
    $confirmForm.MinimizeBox = $false
    $confirmForm.ShowInTaskbar = $false
    $confirmForm.BackColor = [System.Drawing.Color]::FromArgb(20, 31, 42)
    $confirmForm.ForeColor = [System.Drawing.Color]::FromArgb(225, 232, 238)
    $confirmForm.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    $confirmAccent = New-Object System.Windows.Forms.Panel
    $confirmAccent.Location = New-Object System.Drawing.Point(25, 20)
    $confirmAccent.Size = New-Object System.Drawing.Size(5, 58)
    $confirmAccent.BackColor = [System.Drawing.Color]::FromArgb(57, 169, 220)
    $confirmForm.Controls.Add($confirmAccent)

    $confirmTitle = New-Object System.Windows.Forms.Label
    $confirmTitle.Text = 'Application already exists'
    $confirmTitle.Location = New-Object System.Drawing.Point(45, 20)
    $confirmTitle.Size = New-Object System.Drawing.Size(455, 30)
    $confirmTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 15)
    $confirmForm.Controls.Add($confirmTitle)

    $confirmText = New-Object System.Windows.Forms.Label
    $confirmText.Text = "'$ApplicationName' already exists in DeployR.`r`nDo you want to overwrite the content in Version 1?"
    $confirmText.Location = New-Object System.Drawing.Point(47, 58)
    $confirmText.Size = New-Object System.Drawing.Size(450, 55)
    $confirmText.ForeColor = [System.Drawing.Color]::FromArgb(190, 202, 212)
    $confirmForm.Controls.Add($confirmText)

    $buttonNo = New-Object System.Windows.Forms.Button
    $buttonNo.Text = 'NOPE, NOT RISKING IT'
    $buttonNo.Location = New-Object System.Drawing.Point(35, 145)
    $buttonNo.Size = New-Object System.Drawing.Size(205, 42)
    $buttonNo.BackColor = [System.Drawing.Color]::FromArgb(34, 51, 65)
    $buttonNo.ForeColor = [System.Drawing.Color]::FromArgb(210, 220, 228)
    $buttonNo.FlatStyle = 'Flat'
    $buttonNo.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(55, 78, 94)
    $buttonNo.DialogResult = [System.Windows.Forms.DialogResult]::No
    $confirmForm.Controls.Add($buttonNo)

    $buttonYes = New-Object System.Windows.Forms.Button
    $buttonYes.Text = 'HELL YEAH, OVERWRITE IT!'
    $buttonYes.Location = New-Object System.Drawing.Point(270, 145)
    $buttonYes.Size = New-Object System.Drawing.Size(225, 42)
    $buttonYes.BackColor = [System.Drawing.Color]::FromArgb(30, 108, 145)
    $buttonYes.ForeColor = [System.Drawing.Color]::White
    $buttonYes.FlatStyle = 'Flat'
    $buttonYes.FlatAppearance.BorderSize = 0
    $buttonYes.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $confirmForm.Controls.Add($buttonYes)

    $confirmForm.AcceptButton = $buttonYes
    $confirmForm.CancelButton = $buttonNo

    $result = $confirmForm.ShowDialog($form)
    $confirmForm.Dispose()
    return $result
}

function Show-UpdateInformation {
    $infoForm = New-Object System.Windows.Forms.Form
    $infoForm.Text = 'DeployR Application Forge'
    $infoForm.StartPosition = 'CenterParent'
    $infoForm.Size = New-Object System.Drawing.Size(620, 330)
    $infoForm.FormBorderStyle = 'FixedDialog'
    $infoForm.MaximizeBox = $false
    $infoForm.MinimizeBox = $false
    $infoForm.ShowInTaskbar = $false
    $infoForm.BackColor = [System.Drawing.Color]::FromArgb(20, 31, 42)
    $infoForm.ForeColor = [System.Drawing.Color]::FromArgb(225, 232, 238)
    $infoForm.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    $infoAccent = New-Object System.Windows.Forms.Panel
    $infoAccent.Location = New-Object System.Drawing.Point(25, 20)
    $infoAccent.Size = New-Object System.Drawing.Size(5, 65)
    $infoAccent.BackColor = [System.Drawing.Color]::FromArgb(93, 166, 126)
    $infoForm.Controls.Add($infoAccent)

    $infoTitle = New-Object System.Windows.Forms.Label
    $infoTitle.Text = 'DeployR did its thing. Almost.'
    $infoTitle.Location = New-Object System.Drawing.Point(45, 20)
    $infoTitle.Size = New-Object System.Drawing.Size(500, 30)
    $infoTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 15)
    $infoForm.Controls.Add($infoTitle)

    $infoText = New-Object System.Windows.Forms.Label
    $infoText.Text = "The content has been updated successfully, but a little manual DeployR magic remains.`r`n`r`nPlease review and update:`r`n  - Content item details > Description`r`n  - Version 1 > Description (application name and version)`r`n  - Version 1 > Installation command line"
    $infoText.Location = New-Object System.Drawing.Point(47, 65)
    $infoText.Size = New-Object System.Drawing.Size(530, 150)
    $infoText.ForeColor = [System.Drawing.Color]::FromArgb(190, 202, 212)
    $infoForm.Controls.Add($infoText)

    $buttonGotIt = New-Object System.Windows.Forms.Button
    $buttonGotIt.Text = 'GOT IT!'
    $buttonGotIt.Location = New-Object System.Drawing.Point(380, 235)
    $buttonGotIt.Size = New-Object System.Drawing.Size(190, 42)
    $buttonGotIt.BackColor = [System.Drawing.Color]::FromArgb(30, 108, 145)
    $buttonGotIt.ForeColor = [System.Drawing.Color]::White
    $buttonGotIt.FlatStyle = 'Flat'
    $buttonGotIt.FlatAppearance.BorderSize = 0
    $buttonGotIt.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $infoForm.Controls.Add($buttonGotIt)

    $infoForm.AcceptButton = $buttonGotIt
    [void]$infoForm.ShowDialog($form)
    $infoForm.Dispose()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'DeployR Application Forge'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(780, 680)
$form.MinimumSize = New-Object System.Drawing.Size(780, 680)
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$form.BackColor = [System.Drawing.Color]::FromArgb(20, 31, 42)

$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Text = 'DeployR Application Forge'
$labelTitle.Location = New-Object System.Drawing.Point(25, 20)
$labelTitle.Size = New-Object System.Drawing.Size(680, 35)
$labelTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
$labelTitle.ForeColor = [System.Drawing.Color]::FromArgb(225, 232, 238)
$form.Controls.Add($labelTitle)

$labelDescription = New-Object System.Windows.Forms.Label
$labelDescription.Text = 'Feed DeployR the good stuff. PowerShell 7 handles the mildly dangerous bits.'
$labelDescription.Location = New-Object System.Drawing.Point(28, 58)
$labelDescription.Size = New-Object System.Drawing.Size(680, 25)
$labelDescription.ForeColor = [System.Drawing.Color]::FromArgb(145, 163, 178)
$form.Controls.Add($labelDescription)

$labelAppName = New-Object System.Windows.Forms.Label
$labelAppName.Text = 'Application name'
$labelAppName.Location = New-Object System.Drawing.Point(30, 105)
$labelAppName.Size = New-Object System.Drawing.Size(680, 22)
$form.Controls.Add($labelAppName)

$textAppName = New-Object System.Windows.Forms.TextBox
$textAppName.Location = New-Object System.Drawing.Point(30, 130)
$textAppName.Size = New-Object System.Drawing.Size(680, 30)
$form.Controls.Add($textAppName)

$labelAppNameVersion = New-Object System.Windows.Forms.Label
$labelAppNameVersion.Text = 'Application name and version'
$labelAppNameVersion.Location = New-Object System.Drawing.Point(30, 175)
$labelAppNameVersion.Size = New-Object System.Drawing.Size(680, 22)
$form.Controls.Add($labelAppNameVersion)

$textAppNameVersion = New-Object System.Windows.Forms.TextBox
$textAppNameVersion.Location = New-Object System.Drawing.Point(30, 200)
$textAppNameVersion.Size = New-Object System.Drawing.Size(680, 30)
$form.Controls.Add($textAppNameVersion)

$labelCommandLine = New-Object System.Windows.Forms.Label
$labelCommandLine.Text = 'Installation command'
$labelCommandLine.Location = New-Object System.Drawing.Point(30, 245)
$labelCommandLine.Size = New-Object System.Drawing.Size(680, 22)
$form.Controls.Add($labelCommandLine)

$textCommandLine = New-Object System.Windows.Forms.TextBox
$textCommandLine.Location = New-Object System.Drawing.Point(30, 270)
$textCommandLine.Size = New-Object System.Drawing.Size(680, 30)
$form.Controls.Add($textCommandLine)

$labelSourceFolder = New-Object System.Windows.Forms.Label
$labelSourceFolder.Text = 'Source folder'
$labelSourceFolder.Location = New-Object System.Drawing.Point(30, 315)
$labelSourceFolder.Size = New-Object System.Drawing.Size(680, 22)
$form.Controls.Add($labelSourceFolder)

$textSourceFolder = New-Object System.Windows.Forms.TextBox
$textSourceFolder.Location = New-Object System.Drawing.Point(30, 340)
$textSourceFolder.Size = New-Object System.Drawing.Size(570, 30)
$form.Controls.Add($textSourceFolder)

$buttonBrowse = New-Object System.Windows.Forms.Button
$buttonBrowse.Text = 'Browse...'
$buttonBrowse.Location = New-Object System.Drawing.Point(610, 338)
$buttonBrowse.Size = New-Object System.Drawing.Size(100, 32)
$form.Controls.Add($buttonBrowse)

$buttonRun = New-Object System.Windows.Forms.Button
$buttonRun.Text = 'SEND IT TO DEPLOYR'
$buttonRun.Location = New-Object System.Drawing.Point(30, 395)
$buttonRun.Size = New-Object System.Drawing.Size(220, 42)
$buttonRun.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$buttonRun.BackColor = [System.Drawing.Color]::FromArgb(30, 108, 145)
$buttonRun.ForeColor = [System.Drawing.Color]::White
$buttonRun.FlatStyle = 'Flat'
$buttonRun.FlatAppearance.BorderSize = 0
$form.Controls.Add($buttonRun)

$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = 'Standing by. Ready when you are.'
$labelStatus.Location = New-Object System.Drawing.Point(270, 404)
$labelStatus.Size = New-Object System.Drawing.Size(440, 25)
$labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(145, 163, 178)
$form.Controls.Add($labelStatus)

$textOutput = New-Object System.Windows.Forms.TextBox
$textOutput.Location = New-Object System.Drawing.Point(30, 460)
$textOutput.Size = New-Object System.Drawing.Size(680, 120)
$textOutput.Multiline = $true
$textOutput.ScrollBars = 'Vertical'
$textOutput.ReadOnly = $true
$textOutput.BackColor = [System.Drawing.Color]::FromArgb(12, 22, 31)
$textOutput.ForeColor = [System.Drawing.Color]::FromArgb(185, 203, 215)
$textOutput.BorderStyle = 'FixedSingle'
$textOutput.Font = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($textOutput)

$labelControls = @($labelAppName, $labelAppNameVersion, $labelCommandLine, $labelSourceFolder)
foreach ($label in $labelControls) {
    $label.ForeColor = [System.Drawing.Color]::FromArgb(190, 202, 212)
}

$textControls = @($textAppName, $textAppNameVersion, $textCommandLine, $textSourceFolder)
foreach ($textBox in $textControls) {
    $textBox.BackColor = [System.Drawing.Color]::FromArgb(29, 43, 55)
    $textBox.ForeColor = [System.Drawing.Color]::FromArgb(225, 232, 238)
    $textBox.BorderStyle = 'FixedSingle'
}

$buttonBrowse.BackColor = [System.Drawing.Color]::FromArgb(34, 51, 65)
$buttonBrowse.ForeColor = [System.Drawing.Color]::FromArgb(210, 220, 228)
$buttonBrowse.FlatStyle = 'Flat'
$buttonBrowse.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(55, 78, 94)
$buttonBrowse.FlatAppearance.BorderSize = 1

$divider = New-Object System.Windows.Forms.Panel
$divider.Location = New-Object System.Drawing.Point(30, 91)
$divider.Size = New-Object System.Drawing.Size(680, 1)
$divider.BackColor = [System.Drawing.Color]::FromArgb(45, 68, 84)
$form.Controls.Add($divider)

$accentLine = New-Object System.Windows.Forms.Panel
$accentLine.Location = New-Object System.Drawing.Point(30, 91)
$accentLine.Size = New-Object System.Drawing.Size(125, 2)
$accentLine.BackColor = [System.Drawing.Color]::FromArgb(57, 169, 220)
$form.Controls.Add($accentLine)

$labelFooter = New-Object System.Windows.Forms.Label
$labelFooter.Text = 'POWERED BY COFFEE, POWERSHELL 7 & QUESTIONABLE CONFIDENCE'
$labelFooter.Location = New-Object System.Drawing.Point(30, 596)
$labelFooter.Size = New-Object System.Drawing.Size(680, 25)
$labelFooter.TextAlign = 'MiddleCenter'
$labelFooter.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$labelFooter.ForeColor = [System.Drawing.Color]::FromArgb(82, 105, 121)
$form.Controls.Add($labelFooter)

$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = 'Select the application source folder'
$folderBrowser.ShowNewFolderButton = $false

$buttonBrowse.Add_Click({
    $currentPath = $textSourceFolder.Text.Trim()

    if (Test-Path -LiteralPath $currentPath -PathType Container) {
        $folderBrowser.SelectedPath = $currentPath
    }

    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textSourceFolder.Text = $folderBrowser.SelectedPath
    }
})

$buttonRun.Add_Click({
    $textOutput.Clear()
    $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(145, 163, 178)

    $appName = $textAppName.Text.Trim()
    $appNameVersion = $textAppNameVersion.Text.Trim()
    $commandLine = $textCommandLine.Text.Trim()
    $inputSourceFolder = $textSourceFolder.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($appName)) {
        [System.Windows.Forms.MessageBox]::Show('Application name is required.', 'Missing information', 'OK', 'Warning')
        $textAppName.Focus()
        return
    }

    if ([string]::IsNullOrWhiteSpace($appNameVersion)) {
        [System.Windows.Forms.MessageBox]::Show('Application name and version is required.', 'Missing information', 'OK', 'Warning')
        $textAppNameVersion.Focus()
        return
    }

    if ([string]::IsNullOrWhiteSpace($commandLine)) {
        [System.Windows.Forms.MessageBox]::Show('Installation command is required.', 'Missing information', 'OK', 'Warning')
        $textCommandLine.Focus()
        return
    }

    if ([string]::IsNullOrWhiteSpace($inputSourceFolder)) {
        [System.Windows.Forms.MessageBox]::Show('Source folder is required.', 'Missing information', 'OK', 'Warning')
        $textSourceFolder.Focus()
        return
    }

    if (-not (Test-Path -LiteralPath $inputSourceFolder -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show("The source folder does not exist:`r`n`r`n$inputSourceFolder", 'Source folder not found', 'OK', 'Error')
        $textSourceFolder.Focus()
        return
    }

    if ([string]::IsNullOrWhiteSpace($DeployRPasscode) -or $DeployRPasscode -eq 'CHANGE_ME') {
        [System.Windows.Forms.MessageBox]::Show('Set the DeployR passcode at the beginning of the script before running it.', 'DeployR passcode required', 'OK', 'Warning')
        return
    }

    $buttonRun.Enabled = $false
    $buttonBrowse.Enabled = $false
    $labelStatus.Text = 'Summoning PowerShell 7 and feeding DeployR...'
    $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(73, 163, 207)
    $textOutput.Text = "[FORGE] Waking PowerShell 7...`r`n[FORGE] DeployR snacks prepared...`r`n"
    $form.Refresh()

    try {
        Import-Module $DeployRModulePath -ErrorAction Stop
        Connect-DeployR -Passcode $DeployRPasscode

        $textOutput.AppendText("Source Path: $inputSourceFolder`r`n")

        $existingApplication = Get-DeployRContentItem |
            Where-Object { $_.Name -eq $appName } |
            Select-Object -First 1

        if ($existingApplication) {
            $answer = Show-OverwriteConfirmation -ApplicationName $appName

            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
                $labelStatus.Text = 'Cancelled. No DeployR content was changed.'
                $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(190, 150, 90)
                $textOutput.Text = '[FORGE] Nope, not risking it. Operation cancelled.'
                return
            }

            $contentId = $existingApplication.Id
            if ([string]::IsNullOrWhiteSpace([string]$contentId)) {
                throw "DeployR returned an empty Content Item ID for existing application '$appName'."
            }

            $labelStatus.Text = 'Hell yeah! Overwriting Version 1 content...'
            $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(73, 163, 207)
            $textOutput.Text = "[FORGE] Application already exists.`r`n[FORGE] Overwriting Version 1 content...`r`n"
            $form.Refresh()

            Update-DeployRContentItemContent `
                -ContentId $contentId `
                -ContentVersion 1 `
                -SourceFolder $inputSourceFolder `
                -ErrorAction Stop | Out-Null

            $textOutput.AppendText("Successfully overwrote Version 1 for $appName!`r`n")
            $labelStatus.Text = 'Success. Existing Version 1 was overwritten.'
            $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(93, 166, 126)
            Show-UpdateInformation
        }
        else {
            $textOutput.AppendText("Application Item does not exist for $appName. Creating new one.`r`n")
            $textOutput.AppendText("Using provided Input Source Folder: $inputSourceFolder`r`n")
            $textOutput.AppendText("Creating and uploading application to DeployR Content Item`r`n")

            $newContentItem = New-DeployRContentItem `
                -Name $appName `
                -Type Folder `
                -Purpose Application `
                -Description $inputSourceFolder `
                -ErrorAction Stop

            $contentId = $newContentItem.Id
            if ([string]::IsNullOrWhiteSpace([string]$contentId)) {
                throw 'DeployR created the Content Item but returned an empty Content Item ID.'
            }

            $textOutput.AppendText("Content Item created with ID: $contentId`r`n")

            $newVersion = New-DeployRContentItemVersion `
                -ContentItemId $contentId `
                -Status 'Active' `
                -Description $appNameVersion `
                -SourceFolder $inputSourceFolder `
                -InstallationCommandLine $commandLine `
                -ErrorAction Stop

            $contentVersion = $newVersion.VersionNo
            $textOutput.AppendText("Successfully created and uploaded Application to DeployR!`r`n")
            $textOutput.AppendText("Content Version: $contentVersion`r`n")
            $textOutput.AppendText("Status: Active`r`n")

            $labelStatus.Text = 'Success. DeployR accepted the offering.'
            $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(93, 166, 126)
        }
    }
    catch {
        $labelStatus.Text = 'Computer said no. Check the output.'
        $labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(190, 105, 105)
        $textOutput.Text = $_.Exception.Message

        [System.Windows.Forms.MessageBox]::Show(
            "The operation failed:`r`n`r`n$($_.Exception.Message)",
            'DeployR Application Creator',
            'OK',
            'Error'
        )
    }
    finally {
        $buttonRun.Enabled = $true
        $buttonBrowse.Enabled = $true
    }
})

$form.AcceptButton = $buttonRun
[void]$form.ShowDialog()
