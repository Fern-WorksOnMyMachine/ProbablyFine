# Generic Avalonia BootMenu GUI for DeployR. Optional logo: logo.png.
# DeployR Avalonia 12 BootMenu - no C# compilation, no custom executable.
# Bootstrap follows Johan Arwidmark's SampleAvaloniaFrontend.ps1.
$ErrorActionPreference = 'Stop'
$script:DeployAccepted = $false
$script:PasswordResult = $null

$DeployRoot = [string]${TSEnv:DEPLOYRROOT}
if ([string]::IsNullOrWhiteSpace($DeployRoot)) { throw 'TSEnv:DEPLOYRROOT is missing.' }
$AvaloniaPath = "$DeployRoot\Client"
if (-not (Test-Path -LiteralPath $AvaloniaPath)) { throw "Avalonia client directory not found: $AvaloniaPath" }
$Wanted = @('Avalonia.Base.dll','Avalonia.dll','Avalonia.Controls.dll','Avalonia.Desktop.dll',
 'Avalonia.Dialogs.dll','Avalonia.Fonts.Inter.dll','Avalonia.Markup.dll',
 'Avalonia.Markup.Xaml.dll','Avalonia.Markup.Xaml.Loader.dll','Avalonia.Metal.dll',
 'Avalonia.MicroCom.dll','Avalonia.OpenGL.dll','Avalonia.Remote.Protocol.dll',
 'Avalonia.Skia.dll','Avalonia.Themes.Fluent.dll','Avalonia.Themes.Simple.dll',
 'HarfBuzzSharp.dll','SkiaSharp.dll','Avalonia.Win32.dll')
foreach ($dll in $Wanted) {
    $full = "$AvaloniaPath\$dll"
    if (Test-Path -LiteralPath $full) {
        try { [System.Reflection.Assembly]::LoadFrom($full) | Out-Null }
        catch { Write-Warning "Could not load $dll : $($_.Exception.Message)" }
    }
}
foreach ($required in @('Avalonia.Base.dll','Avalonia.Controls.dll','Avalonia.Desktop.dll',
 'Avalonia.Markup.Xaml.Loader.dll','Avalonia.Themes.Fluent.dll','Avalonia.Win32.dll')) {
    if (-not (Test-Path -LiteralPath "$AvaloniaPath\$required")) { throw "Missing Avalonia dependency: $required" }
}
$builder = [Avalonia.AppBuilder]::Configure[Avalonia.Application]()
$builder = [Avalonia.AppBuilderDesktopExtensions]::UsePlatformDetect($builder)
try {
    $options = [Avalonia.Win32PlatformOptions]::new()
    $modes = [System.Collections.Generic.List[Avalonia.Win32RenderingMode]]::new()
    $modes.Add([Avalonia.Win32RenderingMode]::Software)
    $options.RenderingMode = $modes
    $builder = $builder.With[Avalonia.Win32PlatformOptions]($options)
} catch { Write-Warning "Software rendering preference unavailable: $($_.Exception.Message)" }
try { $builder = [Avalonia.InterFontApplicationBuilderExtension]::WithInterFont($builder) } catch {}
$builder.SetupWithoutStarting() | Out-Null
[Avalonia.Application]::Current.Styles.Add([Avalonia.Themes.Fluent.FluentTheme]::new())

function Get-BootControl {
    param($Root,[string]$Name)
    $scope = [Avalonia.Controls.NameScope]::GetNameScope($Root)
    if (-not $scope) { throw 'Avalonia name scope missing' }
    $control = $scope.Find($Name)
    if (-not $control) { throw "Missing GUI control: $Name" }
    return $control
}
function Set-Brush { param($Control,[string]$Property,[string]$Hex)
    $Control.$Property = [Avalonia.Media.Brush]::Parse($Hex)
}
function Convert-Accent { param([string]$Rgb)
    try {
        $c = @($Rgb.Split(',') | ForEach-Object { [Math]::Max(0,[Math]::Min(255,[int]$_.Trim())) })
        if ($c.Count -eq 3) { return ('#{0:X2}{1:X2}{2:X2}' -f $c[0],$c[1],$c[2]) }
    } catch {}
    return '#36598A'
}
function Show-BootMenuMessage { param([string]$Message)
    $script:ErrorText.Text = $Message
    $script:ErrorPanel.IsVisible = $true
}
function global:ShowMaskedInputWithGif {
    [CmdletBinding()]param([string]$GifPath="$PSScriptRoot\dennis-nedry.gif",
        [string]$Title='Password', [string]$Prompt="Ah ah ah! You didn't say the Magic Word!",
        [Parameter(Mandatory)][string]$ExpectedPassword,[switch]$ReturnSecureString)
    $script:PasswordResult = $null
    $script:ExpectedPassword = $ExpectedPassword
    $script:PasswordTitle.Text = $Title
    $script:PasswordHint.Text = $Prompt
    $script:PasswordError.Text = 'Authorization is required for this deployment role.'
    $script:PasswordBox.Text = ''
    $script:PasswordPanel.IsVisible = $true
    # The overlay is not laid out yet. Focus after the UI dispatcher has processed
    # visibility/layout, otherwise the first click only activates the TextBox.
    $script:PasswordWait = [System.Threading.CancellationTokenSource]::new()
    [Avalonia.Threading.Dispatcher]::UIThread.Post(
        [System.Action]{
            if ($script:PasswordPanel.IsVisible) {
                $script:PasswordBox.Focus() | Out-Null
            }
        },
        [Avalonia.Threading.DispatcherPriority]::Input
    )
    # Nested dispatcher frame is needed because Invoke-BootMenuRole is called synchronously.
    try { [Avalonia.Threading.Dispatcher]::UIThread.MainLoop($script:PasswordWait.Token) }
    catch [System.OperationCanceledException] {}
    finally { $script:PasswordPanel.IsVisible = $false; $script:PasswordWait.Dispose(); $script:PasswordWait = $null }
    $value = $script:PasswordResult
    if ($ReturnSecureString -and $value -ne $script:BootMenuConfig.Settings.OemBackValue -and $null -ne $value) {
        return ConvertTo-SecureString $value -AsPlainText -Force
    }
    return $value
}
function Complete-Password { param([bool]$Accept)
    if ($Accept -and $script:PasswordBox.Text -cne $script:ExpectedPassword) {
        $script:PasswordError.Text = 'Incorrect password. Please try again.'
        Set-Brush $script:PasswordError Foreground '#FF8080'
        $script:PasswordBox.Text = ''
        $script:PasswordBox.Focus() | Out-Null
        return
    }
    $script:PasswordResult = if ($Accept) { [string]$script:PasswordBox.Text } else { [string]$script:BootMenuConfig.Settings.OemBackValue }
    # Finish the click/keyboard event before terminating the nested UI loop.
    # Cancelling synchronously inside Click can interfere with routed focus/click handling.
    [Avalonia.Threading.Dispatcher]::UIThread.Post(
        [System.Action]{
            if ($script:PasswordWait) { $script:PasswordWait.Cancel() }
        },
        [Avalonia.Threading.DispatcherPriority]::Background
    )
}

$xaml = @'
<Window xmlns="https://github.com/avaloniaui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Width="1120" Height="710" MinWidth="860" MinHeight="570" WindowStartupLocation="CenterScreen"
 Background="#080F1D" Foreground="#F2F7FF" Topmost="True" FontFamily="Segoe UI">
 <Window.Styles>
  <Style Selector="Button#DeployButton:disabled">
   <Setter Property="Opacity" Value="1"/>
   <Setter Property="Background" Value="#1C2D43"/>
   <Setter Property="Foreground" Value="#C1D0E3"/>
   <Setter Property="BorderBrush" Value="#3B5777"/>
  </Style>
  <Style Selector="Button#DeployButton:pointerover">
   <Setter Property="Background" Value="#238DFF"/>
  </Style>
 </Window.Styles>
 <Grid Margin="22" ColumnDefinitions="1.72*,18,1*">
  <Border Grid.Column="0" Background="#111E32" BorderBrush="#304E73" BorderThickness="1" CornerRadius="14" Padding="28,24">
   <Grid RowDefinitions="Auto,Auto,Auto,Auto,Auto,Auto,Auto,*,Auto" RowSpacing="9">
    <Grid Grid.Row="0" ColumnDefinitions="*,Auto" Margin="0,0,0,8">
     <StackPanel Grid.Column="0" Spacing="5">
      <TextBlock x:Name="MenuTitle" FontSize="27" FontWeight="Bold" TextWrapping="Wrap"/>
      <TextBlock Text="DeployR Provisioning Center - 2Pint Software" Foreground="#73A8FF" FontSize="13"/>
     </StackPanel>
     <Image x:Name="BrandLogo" Grid.Column="1" Width="48" Height="48" Margin="12,0,0,0"
            VerticalAlignment="Center" HorizontalAlignment="Right" Stretch="Uniform"/>
    </Grid>
    <Border Grid.Row="1" Height="2" Background="#2874D9" CornerRadius="1" Margin="0,0,0,9"/>
    <TextBlock Grid.Row="2" Text="CUSTOMER" Foreground="#A9BFDC" FontWeight="SemiBold" FontSize="12"/>
    <ComboBox x:Name="MunicipalityCombo" Grid.Row="3" Height="46" FontSize="16" HorizontalAlignment="Stretch" HorizontalContentAlignment="Stretch" Background="#F1F5FB" Foreground="#12213A" BorderBrush="#56769C" BorderThickness="1" MaxDropDownHeight="450"/>
    <TextBlock Grid.Row="4" Text="DEPLOYMENT ROLE" Foreground="#A9BFDC" FontWeight="SemiBold" FontSize="12" Margin="0,8,0,0"/>
    <ComboBox x:Name="RoleCombo" Grid.Row="5" Height="46" FontSize="16" HorizontalAlignment="Stretch" HorizontalContentAlignment="Stretch" Background="#F1F5FB" Foreground="#12213A" BorderBrush="#56769C" BorderThickness="1" MaxDropDownHeight="450"/>
    <TextBlock x:Name="HintText" Grid.Row="6" Text="Select a customer to get started." Foreground="#8FA9C9" TextWrapping="Wrap" FontSize="13" Margin="0,6,0,5"/>
    <Border x:Name="ProfilePanel" Grid.Row="7" IsVisible="False" Background="#102338" BorderBrush="#3A638D" BorderThickness="1" CornerRadius="11" Padding="19" Margin="0,5,0,12">
     <Grid RowDefinitions="Auto,2,*" RowSpacing="12">
      <TextBlock x:Name="ProfileTitle" Grid.Row="0" FontSize="18" FontWeight="SemiBold" TextWrapping="Wrap"/>
      <Border x:Name="ProfileAccent" Grid.Row="1" Background="#36598A" CornerRadius="2" HorizontalAlignment="Stretch" Height="2"/>
      <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto"><TextBlock x:Name="ProfileText" TextWrapping="Wrap" FontSize="14" Foreground="#BED1E8" LineHeight="22"/></ScrollViewer>
     </Grid>
    </Border>
    <Button x:Name="DeployButton" Grid.Row="8" Height="58" FontSize="18" FontWeight="Bold" Content="WAITING FOR SELECTION" IsEnabled="False" Background="#1C2D43" Foreground="#A7BCD5" BorderBrush="#3B5777" BorderThickness="1" CornerRadius="11" HorizontalAlignment="Stretch" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" Padding="16,0"/>
   </Grid>
  </Border>
  <Border Grid.Column="2" Background="#111E32" BorderBrush="#304E73" BorderThickness="1" CornerRadius="14" Padding="23,24">
   <Grid RowDefinitions="Auto,2,Auto,Auto,Auto,Auto,Auto,Auto,Auto,* ,Auto" RowSpacing="10">
    <TextBlock Grid.Row="0" Text="Summary" FontSize="21" FontWeight="Bold" Margin="0,0,0,6"/>
    <Border Grid.Row="1" Background="#304E73" CornerRadius="1"/>
    <TextBlock Grid.Row="2" Text="CUSTOMER" Foreground="#8FA9C9" FontSize="11" FontWeight="SemiBold" Margin="0,5,0,0"/>
    <TextBlock x:Name="SummaryMunicipality" Grid.Row="3" Text="Not selected" FontSize="18" FontWeight="SemiBold" TextWrapping="Wrap"/>
    <TextBlock Grid.Row="4" Text="DEPLOYMENT ROLE" Foreground="#8FA9C9" FontSize="11" FontWeight="SemiBold" Margin="0,7,0,0"/>
    <TextBlock x:Name="SummaryRole" Grid.Row="5" Text="Not selected" FontSize="18" FontWeight="SemiBold" TextWrapping="Wrap"/>
    <Border x:Name="StatusPanel" Grid.Row="6" Background="#33262F" CornerRadius="10" Padding="15" Margin="0,8,0,10">
     <StackPanel Spacing="5">
      <StackPanel Orientation="Horizontal" Spacing="8">
       <Ellipse x:Name="StatusDot" Width="8" Height="8" Fill="#FF9B9B" VerticalAlignment="Center"/>
       <TextBlock x:Name="StatusText" Text="WAITING" FontSize="14" FontWeight="Bold" Foreground="#FF9B9B"/>
      </StackPanel>
      <TextBlock x:Name="StatusDetail" Text="DeployR is waiting for your selection." TextWrapping="Wrap" FontSize="13" Foreground="#E6EDF8"/>
     </StackPanel>
    </Border>
    <TextBlock Grid.Row="7" Text="COMPUTER INFORMATION" Foreground="#A9BFDC" FontSize="12" FontWeight="SemiBold" Margin="0,2,0,0"/>
    <Border Grid.Row="8" MaxHeight="295" Background="#0D1B2D" BorderBrush="#304E73" BorderThickness="1" CornerRadius="10" Padding="13">
     <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
      <TextBlock x:Name="ComputerInfo" FontSize="12.5" FontFamily="Consolas" Foreground="#A0E4F9" TextWrapping="Wrap" LineHeight="19"/>
     </ScrollViewer>
    </Border>
    <TextBlock Grid.Row="10" Text="DEPLOYMENT CENTER  ·  POWERED BY DEPLOYR" FontSize="10" Foreground="#6F8AA9" HorizontalAlignment="Center" Margin="0,10,0,0"/>
   </Grid>
  </Border>
  <Border x:Name="PasswordPanel" Grid.ColumnSpan="3" IsVisible="False" Background="#F0080F1D" CornerRadius="12">
   <Border Width="530" HorizontalAlignment="Center" VerticalAlignment="Center" Background="#111E32" BorderBrush="#416B9A" BorderThickness="1" CornerRadius="14" Padding="32">
    <StackPanel Spacing="16">
     <TextBlock x:Name="PasswordTitle" Text="Say the magic word" FontSize="25" FontWeight="Bold" HorizontalAlignment="Center"/>
     <TextBlock x:Name="PasswordHint" TextWrapping="Wrap" HorizontalAlignment="Center" Foreground="#A9BFDC"/>
     <TextBox x:Name="PasswordBox" PasswordChar="●" Height="46" FontSize="16"/>
     <TextBlock x:Name="PasswordError" TextWrapping="Wrap" Foreground="#8FE3FF"/>
     <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Spacing="12">
      <Button x:Name="PasswordBack" Content="BACK" Width="130" Height="42"/>
      <Button x:Name="PasswordOk" Content="UNLOCK" Width="130" Height="42" Background="#0078FF"/>
     </StackPanel>
    </StackPanel>
   </Border>
  </Border>
  <Border x:Name="ErrorPanel" Grid.ColumnSpan="3" IsVisible="False" Background="#F0080F1D">
   <Border Width="500" HorizontalAlignment="Center" VerticalAlignment="Center" Background="#111E32" BorderBrush="#416B9A" BorderThickness="1" CornerRadius="14" Padding="30">
    <StackPanel Spacing="18"><TextBlock x:Name="ErrorText" TextWrapping="Wrap" FontSize="17"/><Button x:Name="ErrorOk" Content="OK" Width="120" HorizontalAlignment="Right"/></StackPanel>
   </Border>
  </Border>
 </Grid>
</Window>
'@
$script:form = [Avalonia.Markup.Xaml.AvaloniaRuntimeXamlLoader]::Parse($xaml)
foreach ($name in @('MenuTitle','BrandLogo','MunicipalityCombo','RoleCombo','HintText','ProfilePanel','ProfileTitle','ProfileAccent',
 'ProfileText','DeployButton','SummaryMunicipality','SummaryRole','StatusPanel','StatusText','StatusDetail',
 'ComputerInfo','StatusDot','PasswordPanel','PasswordTitle','PasswordHint','PasswordBox','PasswordError','PasswordBack',
 'PasswordOk','ErrorPanel','ErrorText','ErrorOk')) {
    Set-Variable -Scope Script -Name $name -Value (Get-BootControl $script:form $name)
}
$script:form.Title = [string]$script:BootMenuConfig.Settings.WindowTitle
$script:MenuTitle.Text = [string]$script:BootMenuConfig.Settings.MenuTitle
# Optional branding: keep the menu operational even if the logo is missing.
$logoPath = "$PSScriptRoot\logo.png"
if (Test-Path -LiteralPath $logoPath) {
    try {
        $script:BrandLogo.Source = [Avalonia.Media.Imaging.Bitmap]::new($logoPath)
    }
    catch {
        Write-Warning "Could not load the logo: $($_.Exception.Message)"
        $script:BrandLogo.IsVisible = $false
    }
}
else { $script:BrandLogo.IsVisible = $false }
if (-not $Windowed) {
    $script:form.SystemDecorations = 'None'
    $script:form.WindowState = 'FullScreen'
}
else { $script:form.Topmost = $false }

try {
    $ram = "$([math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB)) GB"
} catch { $ram = 'N/A' }
try {
    $disk = Get-CimInstance Win32_DiskDrive -ErrorAction Stop | Where-Object { $_.Size -gt 20GB -and $_.Model -notmatch 'USB|SD|Flash' } | Sort-Object Size -Descending | Select-Object -First 1
    $diskSize = if ($disk) { "$([math]::Round($disk.Size / 1GB)) GB" } else { 'N/A' }
} catch { $diskSize = 'N/A' }
try {
    $nic = Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction Stop | Where-Object IPEnabled | Select-Object -First 1
    $ip = $nic.IPAddress | Select-Object -First 1
    $mac = $nic.MACAddress
} catch { $ip = 'N/A'; $mac = 'N/A' }
$site = $script:BootMenuConfig.Sites | Where-Object { $ip -like $_.Pattern } | Select-Object -First 1 -ExpandProperty Name
if (-not $site) { $site = 'Unknown' }
# Long VM serial numbers are displayed in full on a separate line.
$serialNumber = [string]${TSEnv:SerialNumber}
$serialLine = if ($serialNumber.Length -gt 22) {
    "Serial number:`r`n$serialNumber"
} else {
    "Serial number: $serialNumber"
}
$script:ComputerInfo.Text = @(
    "Manufacturer: $(${TSEnv:MakeAlias})", "Model: $(${TSEnv:ModelAlias})",
    "System: $(${TSEnv:SystemAlias})", $serialLine,'',
    'Info','────────────────',"Disk: $diskSize","Memory: $ram",
    "IP address: $ip","MAC address: $mac","Site: $site") -join "`r`n"

$script:MunicipalityMap = @{}
# Preserve existing locale-aware sorting and keep the legacy special category last.
$svCulture = [System.Globalization.CultureInfo]::GetCultureInfo('sv-SE')
$normalMunicipalities = @($MainMenu | Where-Object { [string]$_.Text -ne 'Övrigt' })
$sortedMunicipalities = @($normalMunicipalities | Sort-Object -Property Text -Culture $svCulture.Name)
$sortedMunicipalities += @($MainMenu | Where-Object { [string]$_.Text -eq 'Övrigt' })
foreach ($item in $sortedMunicipalities) {
    $script:MunicipalityMap[[string]$item.Text] = $item
    [void]$script:MunicipalityCombo.Items.Add([string]$item.Text)
}
$script:RoleMap = @{}
$script:SelectedCode = $null
function Update-BootMenuState {
    $role = $null
    if ($script:RoleCombo.SelectedItem) { $role = $script:RoleMap[[string]$script:RoleCombo.SelectedItem] }
    $ready = ($null -ne $role -and -not [string]::IsNullOrEmpty([string]$script:MunicipalityCombo.SelectedItem))
    $script:SelectedCode = if ($ready) { [string]$role.Code } else { $null }
    $script:DeployButton.IsEnabled = $ready
    $script:SummaryRole.Text = if ($role) { [string]$role.Text } else { 'Not selected' }
    $script:ProfilePanel.IsVisible = $ready
    if ($ready) {
        $script:ProfileTitle.Text = [string]$role.Profile.Title
        $script:ProfileText.Text = [string]($role.Profile.DescriptionLines -join "`r`n")
        Set-Brush $script:ProfileAccent Background (Convert-Accent ([string]$role.Profile.AccentColor))
        $script:DeployButton.Content = 'START DEPLOYMENT   →'
        Set-Brush $script:DeployButton Background '#087CFA'
        Set-Brush $script:DeployButton Foreground '#FFFFFF'
        Set-Brush $script:DeployButton BorderBrush '#439FFF'
        $script:StatusText.Text = 'READY'
        Set-Brush $script:StatusText Foreground '#5DFFB1'
        Set-Brush $script:StatusDot Fill '#5DFFB1'
        Set-Brush $script:StatusPanel Background '#173D36'
        $script:StatusDetail.Text = 'Profile selected. Deployment can be started.'
    } else {
        $script:DeployButton.Content = 'WAITING FOR SELECTION'
        Set-Brush $script:DeployButton Background '#1C2D43'
        Set-Brush $script:DeployButton Foreground '#C1D0E3'
        Set-Brush $script:DeployButton BorderBrush '#3B5777'
        $script:StatusText.Text = 'WAITING'
        Set-Brush $script:StatusText Foreground '#FF8080'
        Set-Brush $script:StatusDot Fill '#FF9B9B'
        Set-Brush $script:StatusPanel Background '#33262F'
        $script:StatusDetail.Text = 'DeployR is waiting for a selection.'
    }
}
$script:MunicipalityCombo.Add_SelectionChanged({
    $script:RoleCombo.Items.Clear()
    $script:RoleMap = @{}
    $name = [string]$script:MunicipalityCombo.SelectedItem
    $script:SummaryMunicipality.Text = if ($name) { $name } else { 'Not selected' }
    if ($name -and $script:MunicipalityMap.ContainsKey($name)) {
        foreach ($role in $script:MunicipalityMap[$name].Menu) {
            $label = [string]$role.Text
            $script:RoleMap[$label] = $role
            [void]$script:RoleCombo.Items.Add($label)
        }
    }
    $script:HintText.Text = if ($name) { 'Customer selected. Choose a deployment role.' } else { 'Select a customer to get started.' }
    Update-BootMenuState
})
$script:RoleCombo.Add_SelectionChanged({
    if ($script:RoleCombo.SelectedItem) { $script:HintText.Text = 'Ready to deploy. What could possibly go wrong?' }
    Update-BootMenuState
})
$script:DeployButton.Add_Click({
    if (-not $script:SelectedCode) { Show-BootMenuMessage 'You must select both a customer and a role.'; return }
    try { Invoke-BootMenuRole -Kommmunroll $script:SelectedCode }
    catch { Show-BootMenuMessage "Could not apply the selected role: $($_.Exception.Message)" }
})
$script:PasswordOk.Add_Click({ Complete-Password -Accept $true })
$script:PasswordBack.Add_Click({ Complete-Password -Accept $false })
$script:PasswordBox.Add_KeyDown({ param($sender,$e)
    if ($e.Key -eq [Avalonia.Input.Key]::Enter) { Complete-Password -Accept $true; $e.Handled = $true }
    elseif ($e.Key -eq [Avalonia.Input.Key]::Escape) { Complete-Password -Accept $false; $e.Handled = $true }
})
$script:ErrorOk.Add_Click({ $script:ErrorPanel.IsVisible = $false })
$script:form.Add_KeyDown({ param($sender,$e)
    if ($e.Key -eq [Avalonia.Input.Key]::Escape -and -not $script:PasswordPanel.IsVisible) {
        $script:MunicipalityCombo.SelectedIndex = -1
        $script:RoleCombo.Items.Clear()
        $script:ErrorPanel.IsVisible = $false
        Update-BootMenuState
        $e.Handled = $true
    }
    if ($e.Key -eq [Avalonia.Input.Key]::F4 -and $e.KeyModifiers.HasFlag([Avalonia.Input.KeyModifiers]::Alt)) { $e.Handled = $true }
})
$script:form.Add_Opened({ $script:MunicipalityCombo.Focus() | Out-Null })
$script:MainLoopCancel = [System.Threading.CancellationTokenSource]::new()
$script:form.Add_Closed({
    [Avalonia.Threading.Dispatcher]::UIThread.Post(
        [System.Action]{ $script:MainLoopCancel.Cancel() },
        [Avalonia.Threading.DispatcherPriority]::Background)
})
Update-BootMenuState
try {
    $script:form.Show()
    [Avalonia.Threading.Dispatcher]::UIThread.MainLoop($script:MainLoopCancel.Token)
} catch [System.OperationCanceledException] {
} finally {
    try { [Avalonia.Threading.Dispatcher]::UIThread.RunJobs() } catch {}
    $script:MainLoopCancel.Dispose()
}
if (-not $script:DeployAccepted) { throw 'BootMenu closed without confirming a deployment role.' }
