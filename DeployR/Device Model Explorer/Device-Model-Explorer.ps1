#requires -Version 7.0
<#
.SYNOPSIS
    HP and Lenovo Model Lookup GUI for PowerShell 7.
.DESCRIPTION
    Searches HP CMSL by model name or HP SystemID, and Lenovo's public allModels.json
    by friendly name, machine type/model code, or product ID.

    HP prerequisite:
        Install-Module HPCMSL -Scope CurrentUser -Force -AcceptLicense

    The Lenovo catalog is downloaded on demand and cached for the current session.
    This GUI is intended for 64-bit PowerShell 7 on Windows.
#>

param(
    [switch]$Worker,
    [string]$WorkerVendor,
    [string]$WorkerSearchType,
    [string]$WorkerQuery,
    [string]$WorkerOutput
)

# The worker runs in its own PowerShell process, never on the WPF UI thread.
if ($Worker) {
    try {
        $items = @()
        if ($WorkerVendor -eq 'HP') {
            Import-Module HPCMSL -ErrorAction Stop
            if ($WorkerSearchType -eq 'SystemID / MTM' -or
                ($WorkerSearchType -eq 'Auto detect' -and $WorkerQuery -match '^[0-9a-fA-F]{4}$')) {
                $found = @(Get-HPDeviceDetails -Platform $WorkerQuery -ErrorAction Stop)
            } else {
                $found = @(Get-HPDeviceDetails -Match $WorkerQuery -ErrorAction Stop)
            }
            foreach ($entry in $found) {
                $items += [pscustomobject]@{
                    Vendor = 'HP'; Model = [string]$entry.Name
                    Identifier = [string]$entry.SystemID; ProductId = ''
                    DriverSupport = [string]$entry.DriverPackSupport
                }
            }
        } elseif ($WorkerVendor -eq 'Lenovo') {
            # Invoke-RestMethod can return the entire JSON array as a single pipeline object.
            # Explicitly flatten it before iterating individual model entries.
            $response = Invoke-RestMethod -Uri 'https://download.lenovo.com/bsco/public/allModels.json' -TimeoutSec 40 -ErrorAction Stop
            $catalog = @($response)
            if ($catalog.Count -eq 1 -and $catalog[0] -is [array]) {
                $catalog = @($catalog[0])
            }
            foreach ($entry in $catalog) {
                $name = [string]$entry.name
                $code = [string]$entry.code
                $productId = [string]$entry.productId
                if ([string]::IsNullOrWhiteSpace($name)) { continue }
                if ($name -match '(?i)-UEFI Lenovo|dTPM|fTPM|Asset') { continue }

                # Lenovo often stores machine types only inside the friendly name,
                # e.g. ThinkPad X1 Yoga 7th Gen (21CD,21CE), with empty code/productId.
                $machineTypes = @()
                if ($name -match '\(([0-9A-Za-z]{4}(?:\s*,\s*[0-9A-Za-z]{4})+)\)') {
                    $machineTypes = @($Matches[1] -split '\s*,\s*')
                } elseif ($name -match '\(([0-9A-Za-z]{4})\)') {
                    $machineTypes = @($Matches[1])
                }
                # Keep the catalog's machine types but present the clean friendly model name.
                $cleanName = ($name -replace '\s*\([0-9A-Za-z]{4}(?:\s*,\s*[0-9A-Za-z]{4})*\)\s*$', '').Trim()
                $identifier = if ($machineTypes.Count -gt 0) { $machineTypes -join ', ' } elseif ($code) { $code } else { '' }

                $nameMatches = $name.IndexOf($WorkerQuery, [StringComparison]::OrdinalIgnoreCase) -ge 0
                $idMatches = ($code.IndexOf($WorkerQuery, [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
                    ($productId.IndexOf($WorkerQuery, [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
                    (($machineTypes -join ',').IndexOf($WorkerQuery, [StringComparison]::OrdinalIgnoreCase) -ge 0)
                $isMatch = if ($WorkerSearchType -eq 'Model name') {
                    $nameMatches
                } elseif ($WorkerSearchType -eq 'SystemID / MTM') {
                    $idMatches
                } else {
                    $nameMatches -or $idMatches
                }
                if ($isMatch) {
                    $items += [pscustomobject]@{
                        Vendor = 'Lenovo'; Model = $cleanName; Identifier = $identifier
                        ProductId = $productId; DriverSupport = 'Not reported'
                    }
                }
            }

        }
        $payload = @{ Success = $true; Rows = @($items); Error = '' }
    } catch {
        $payload = @{ Success = $false; Rows = @(); Error = $_.Exception.Message }
    }
    $payload | ConvertTo-Json -Depth 6 -Compress | Set-Content -LiteralPath $WorkerOutput -Encoding utf8
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'This GUI uses WPF and must be run on Windows.'
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$script:LenovoCatalog = $null
$script:LenovoCatalogUrl = 'https://download.lenovo.com/bsco/public/allModels.json'
$script:CurrentRows = @()

[xml]$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Device Model Explorer" Width="1180" Height="760" MinWidth="900" MinHeight="620"
        WindowStartupLocation="CenterScreen" WindowState="Maximized" Background="#0B1120" FontFamily="Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="Panel" Color="#111A2E"/>
        <SolidColorBrush x:Key="Panel2" Color="#16213A"/>
        <SolidColorBrush x:Key="Text" Color="#F4F7FB"/>
        <SolidColorBrush x:Key="Muted" Color="#9BA9C3"/>
        <SolidColorBrush x:Key="Accent" Color="#47A7FF"/>
        <SolidColorBrush x:Key="Border" Color="#2B3957"/>
        <Style TargetType="TextBlock"><Setter Property="Foreground" Value="{StaticResource Text}"/></Style>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="White"/><Setter Property="Background" Value="#2478D4"/>
            <Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="18,10"/>
            <Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                <Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#3294F5"/></Trigger>
                    <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#0D1527"/><Setter Property="Foreground" Value="#101827"/>
            <Setter Property="BorderBrush" Value="{StaticResource Border}"/><Setter Property="Padding" Value="10,8"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#0D1527"/><Setter Property="Foreground" Value="{StaticResource Text}"/>
            <Setter Property="BorderBrush" Value="{StaticResource Border}"/><Setter Property="CaretBrush" Value="White"/>
            <Setter Property="Padding" Value="13,10"/><Setter Property="FontSize" Value="15"/>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="#0D1527"/><Setter Property="Foreground" Value="{StaticResource Text}"/>
            <Setter Property="BorderBrush" Value="{StaticResource Border}"/><Setter Property="GridLinesVisibility" Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#253451"/><Setter Property="RowBackground" Value="#0D1527"/>
            <Setter Property="AlternatingRowBackground" Value="#121D33"/><Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="CanUserAddRows" Value="False"/><Setter Property="IsReadOnly" Value="True"/>
            <Setter Property="SelectionMode" Value="Single"/><Setter Property="RowHeight" Value="38"/>
        </Style>
        <!-- Keep selection dark blue even when focus moves to the details panel. -->
        <Style TargetType="DataGridRow">
            <Setter Property="Foreground" Value="#F4F7FB"/>
            <Setter Property="Background" Value="#0D1527"/>
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#174C83"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="Foreground" Value="#F4F7FB"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="5,0"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="Transparent"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                    <Setter Property="BorderThickness" Value="0"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#17243E"/><Setter Property="Foreground" Value="#C9D5E9"/>
            <Setter Property="Padding" Value="10"/><Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderBrush" Value="#2B3957"/><Setter Property="BorderThickness" Value="0,0,1,1"/>
        </Style>
    </Window.Resources>

    <Grid Margin="26">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0" Margin="0,0,0,22">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <StackPanel>
                <TextBlock Text="DEVICE MODEL EXPLORER" Foreground="#65B8FF" FontWeight="Bold" FontSize="12"/>
                <TextBlock Text="Every device has an identity. Some just hide it better." FontSize="25" FontWeight="SemiBold" Margin="0,4,0,0"/>
                <TextBlock Text="Find the model, decode the ID, and pretend you knew it all along." Foreground="{StaticResource Muted}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border Grid.Column="1" Background="#162C46" CornerRadius="10" Padding="14,9" VerticalAlignment="Center">
                <TextBlock x:Name="DependencyBadge" Text="Checking HP CMSL..." Foreground="#A9D7FF" FontWeight="SemiBold"/>
            </Border>
        </Grid>

        <Border Grid.Row="1" Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="18">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="185"/><ColumnDefinition Width="185"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Margin="0,0,14,0">
                    <TextBlock Text="VENDOR" Foreground="{StaticResource Muted}" FontSize="11" FontWeight="Bold" Margin="2,0,0,6"/>
                    <ComboBox x:Name="VendorBox" SelectedIndex="0">
                        <ComboBoxItem Content="HP"/><ComboBoxItem Content="Lenovo"/>
                    </ComboBox>
                </StackPanel>
                <StackPanel Grid.Column="1" Margin="0,0,14,0">
                    <TextBlock Text="SEARCH BY" Foreground="{StaticResource Muted}" FontSize="11" FontWeight="Bold" Margin="2,0,0,6"/>
                    <ComboBox x:Name="SearchTypeBox" SelectedIndex="0">
                        <ComboBoxItem Content="Auto detect"/><ComboBoxItem Content="Model name"/><ComboBoxItem Content="SystemID / MTM"/>
                    </ComboBox>
                </StackPanel>
                <StackPanel Grid.Column="2" Margin="0,0,14,0">
                    <TextBlock Text="QUERY" Foreground="{StaticResource Muted}" FontSize="11" FontWeight="Bold" Margin="2,0,0,6"/>
                    <TextBox x:Name="SearchBox" ToolTip="Example: EliteBook 840, 83B2, ThinkPad X1 Yoga or 21CD"/>
                </StackPanel>
                <Button x:Name="SearchButton" Grid.Column="3" Content="Search models" MinWidth="145" VerticalAlignment="Bottom"/>
            </Grid>
        </Border>

        <Grid Grid.Row="2" Margin="2,14,2,10">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <TextBlock x:Name="StatusText" Text="Ready. Search for a model name, HP SystemID, Lenovo MTM or product ID." Foreground="{StaticResource Muted}" VerticalAlignment="Center"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
                <Button x:Name="CopyButton" Content="Copy ID" Background="#283754" Margin="0,0,8,0" Padding="14,7" IsEnabled="False"/>
                <Button x:Name="CopyAllButton" Content="Copy details" Background="#283754" Margin="0,0,8,0" Padding="14,7" IsEnabled="False"/>
                <Button x:Name="ExportButton" Content="Export CSV" Background="#283754" Margin="0,0,8,0" Padding="14,7" IsEnabled="False"/>
                <Button x:Name="SettingsButton" ToolTip="Deployment string settings" Background="#283754" Margin="0,0,8,0" Width="44" Height="36" Padding="0">
                    <Viewbox Width="23" Height="23" Stretch="Uniform">
                        <Canvas Width="24" Height="24">
                            <Path Fill="#D9EDFF" Data="M19.14,12.94 C19.18,12.63 19.2,12.32 19.2,12 C19.2,11.68 19.18,11.37 19.13,11.06 L21.16,9.48 L19.16,6.02 L16.77,6.98 C16.28,6.6 15.74,6.29 15.14,6.05 L14.78,3.5 L10.78,3.5 L10.42,6.05 C9.82,6.29 9.28,6.6 8.79,6.98 L6.4,6.02 L4.4,9.48 L6.43,11.06 C6.38,11.37 6.36,11.68 6.36,12 C6.36,12.32 6.38,12.63 6.43,12.94 L4.4,14.52 L6.4,17.98 L8.79,17.02 C9.28,17.4 9.82,17.71 10.42,17.95 L10.78,20.5 L14.78,20.5 L15.14,17.95 C15.74,17.71 16.28,17.4 16.77,17.02 L19.16,17.98 L21.16,14.52 Z M12.78,15.5 A3.5,3.5 0 1 1 12.78,8.5 A3.5,3.5 0 1 1 12.78,15.5 Z"/>
                        </Canvas>
                    </Viewbox>
                </Button>
                <Button x:Name="RefreshButton" Content="Refresh catalogs" Background="#283754" Padding="14,7"/>
            </StackPanel>
        </Grid>

        <Grid Grid.Row="3">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="1" Margin="0,0,12,0">
                <DataGrid x:Name="ResultsGrid" AutoGenerateColumns="False" AlternationCount="2">
                    <DataGrid.Resources>
                        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#174C83"/>
                        <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightBrushKey}" Color="#174C83"/>
                        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="#FFFFFF"/>
                        <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightTextBrushKey}" Color="#FFFFFF"/>
                    </DataGrid.Resources>
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="Vendor" Binding="{Binding Vendor}" Width="85"/>
                        <DataGridTextColumn Header="Model" Binding="{Binding Model}" Width="*"/>
                        <DataGridTextColumn Header="SystemID / MTM" Binding="{Binding Identifier}" Width="135"/>
                        <DataGridTextColumn Header="Product ID" Binding="{Binding ProductId}" Width="130"/>
                    </DataGrid.Columns>
                </DataGrid>
            </Border>
            <Border Grid.Column="1" Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="20">
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <TextBlock Text="SELECTED MODEL" Foreground="#65B8FF" FontSize="11" FontWeight="Bold"/>
                    <DockPanel Grid.Row="1" LastChildFill="True" Margin="0,8,0,14"><Button x:Name="CopyDetailTitle" DockPanel.Dock="Right" Content="&#xE8C8;" FontFamily="Segoe MDL2 Assets" FontSize="13" Width="29" Height="28" Padding="0" Background="#243A59" ToolTip="Copy model name"/><TextBox x:Name="DetailTitle" Text="Nothing selected" FontSize="20" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,8,0" IsReadOnly="True" BorderThickness="0" Background="Transparent" Padding="0" ToolTip="Click to copy value" Cursor="Hand"/></DockPanel>
                    <Grid Grid.Row="2">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="120"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <TextBlock Text="Vendor" Foreground="{StaticResource Muted}" Margin="0,4"/><DockPanel Grid.Row="0" Grid.Column="1" LastChildFill="True">
                            <Button x:Name="CopyDetailVendor" DockPanel.Dock="Right" Content="&#xE8C8;" FontFamily="Segoe MDL2 Assets" FontSize="13" Width="27" Height="26" Padding="0" Margin="6,0,0,0" Background="#243A59" ToolTip="Copy to clipboard"/>
                            <TextBox x:Name="DetailVendor" Margin="0,4" IsReadOnly="True" BorderThickness="0" Background="Transparent" Padding="0" ToolTip="Click to copy value" Cursor="Hand"/>
                        </DockPanel>
                        <TextBlock Grid.Row="1" Text="SystemID / MTM" Foreground="{StaticResource Muted}" Margin="0,4"/><DockPanel Grid.Row="1" Grid.Column="1" LastChildFill="True">
                            <Button x:Name="CopyDetailId" DockPanel.Dock="Right" Content="&#xE8C8;" FontFamily="Segoe MDL2 Assets" FontSize="13" Width="27" Height="26" Padding="0" Margin="6,0,0,0" Background="#243A59" ToolTip="Copy to clipboard"/>
                            <TextBox x:Name="DetailId" Margin="0,4" FontWeight="SemiBold" IsReadOnly="True" BorderThickness="0" Background="Transparent" Padding="0" ToolTip="Click to copy value" Cursor="Hand"/>
                        </DockPanel>
                        <TextBlock x:Name="ProductLabel" Grid.Row="2" Text="Product ID" Foreground="{StaticResource Muted}" Margin="0,4"/><DockPanel Grid.Row="2" Grid.Column="1" LastChildFill="True">
                            <Button x:Name="CopyDetailProduct" DockPanel.Dock="Right" Content="&#xE8C8;" FontFamily="Segoe MDL2 Assets" FontSize="13" Width="27" Height="26" Padding="0" Margin="6,0,0,0" Background="#243A59" ToolTip="Copy to clipboard"/>
                            <TextBox x:Name="DetailProduct" Margin="0,4" IsReadOnly="True" BorderThickness="0" Background="Transparent" Padding="0" ToolTip="Click to copy value" Cursor="Hand"/>
                        </DockPanel>
                        <TextBlock x:Name="DriverLabel" Grid.Row="3" Text="Driver packs" Foreground="{StaticResource Muted}" Margin="0,4"/><DockPanel Grid.Row="3" Grid.Column="1" LastChildFill="True">
                            <Button x:Name="CopyDetailSupport" DockPanel.Dock="Right" Content="&#xE8C8;" FontFamily="Segoe MDL2 Assets" FontSize="13" Width="27" Height="26" Padding="0" Margin="6,0,0,0" Background="#243A59" ToolTip="Copy to clipboard"/>
                            <TextBox x:Name="DetailSupport" Margin="0,4" IsReadOnly="True" BorderThickness="0" Background="Transparent" Padding="0" ToolTip="Click to copy value" Cursor="Hand"/>
                        </DockPanel>
                    </Grid>
                    <StackPanel Grid.Row="3" Margin="0,18,0,0">
                    <StackPanel Margin="0,0,0,14">
                        <TextBlock Text="SCRIPT-READY MODEL STRINGS" Foreground="{StaticResource Muted}" FontSize="11" FontWeight="Bold" Margin="0,0,0,8"/>
                        <DockPanel LastChildFill="True">
                            <Button x:Name="CopyScriptLineButton" DockPanel.Dock="Right" Content="Copy all" Background="#2675D2" Foreground="White" Padding="14,8" Margin="8,0,0,0" IsEnabled="False" VerticalAlignment="Top" Height="36"/>
                            <ScrollViewer Height="140" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Background="#0D1527" BorderBrush="#2B3957" BorderThickness="1" Padding="6">
                                <StackPanel x:Name="ScriptLinesPanel"/>
                            </ScrollViewer>
                        </DockPanel>
                    </StackPanel>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>

        <TextBlock Grid.Row="4" Text="Less guessing. More deploying. ProbablyFine(TM)" Foreground="#71809A" HorizontalAlignment="Right" Margin="0,10,2,0"/>
    </Grid>
</Window>
'@

$Reader = [System.Xml.XmlNodeReader]::new($Xaml)
$Window = [Windows.Markup.XamlReader]::Load($Reader)

$Names = @('DependencyBadge','VendorBox','SearchTypeBox','SearchBox','SearchButton','StatusText','CopyButton','CopyAllButton','ExportButton','RefreshButton','SettingsButton','ResultsGrid','DetailTitle','DetailVendor','DetailId','DetailProduct','DetailSupport','ProductLabel','DriverLabel','CopyDetailTitle','CopyDetailVendor','CopyDetailId','CopyDetailProduct','CopyDetailSupport','ScriptLinesPanel','CopyScriptLineButton')
foreach ($Name in $Names) {
    Set-Variable -Name $Name -Value $Window.FindName($Name) -Scope Script
}

function Set-Status {
    param([string]$Text, [ValidateSet('Normal','Success','Warning','Error')][string]$Type = 'Normal')
    $StatusText.Text = $Text
    $Color = switch ($Type) {
        'Success' { '#72D6A0' }
        'Warning' { '#FFD166' }
        'Error'   { '#FF7B8B' }
        default   { '#9BA9C3' }
    }
    $StatusText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($Color)
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

function Test-HpCmsl {
    $Command = Get-Command -Name Get-HPDeviceDetails -ErrorAction SilentlyContinue
    if (-not $Command) {
        try {
            Import-Module HPCMSL -ErrorAction Stop
            $Command = Get-Command -Name Get-HPDeviceDetails -ErrorAction SilentlyContinue
        } catch { }
    }

    if ($Command) {
        $DependencyBadge.Text = 'HP CMSL ready'
        $DependencyBadge.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#72D6A0')
        return $true
    }

    $DependencyBadge.Text = 'HP CMSL not installed'
    $DependencyBadge.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFD166')
    return $false
}

function Get-LenovoCatalog {
    param([switch]$Force)
    if ($Force) { $script:LenovoCatalog = $null }
    if ($null -eq $script:LenovoCatalog) {
        Set-Status 'Downloading Lenovo model catalog...' 'Normal'
        $script:LenovoCatalog = @(Invoke-RestMethod -Uri $script:LenovoCatalogUrl -Method Get -TimeoutSec 45)
    }
    return $script:LenovoCatalog
}

function ConvertTo-TextValue {
    param($Value)
    if ($null -eq $Value) { return '' }
    return [string]$Value
}

function Search-Hp {
    param([string]$Query, [string]$SearchType)
    if (-not (Test-HpCmsl)) { return @() }

    try {
        if ($SearchType -eq 'SystemID / MTM' -or ($SearchType -eq 'Auto detect' -and $Query -match '^[0-9A-Fa-f]{4}$')) {
            $Found = @(Get-HPDeviceDetails -Platform $Query -ErrorAction Stop)
        } else {
            $Found = @(Get-HPDeviceDetails -Match $Query -ErrorAction Stop)
        }

        return @($Found | ForEach-Object {
            [pscustomobject]@{
                Vendor       = 'HP'
                Model        = ConvertTo-TextValue $_.Name
                Identifier   = ConvertTo-TextValue $_.SystemID
                ProductId    = ''
                DriverSupport = ConvertTo-TextValue $_.DriverPackSupport
                Raw          = $_
            }
        })
    } catch {
        throw "HP search failed: $($_.Exception.Message)"
    }
}

function Search-Lenovo {
    param([string]$Query, [string]$SearchType)
    try {
        $Catalog = @(Get-LenovoCatalog)
        $Escaped = [WildcardPattern]::Escape($Query)
        $Found = if ($SearchType -eq 'Model name') {
            @($Catalog | Where-Object { (ConvertTo-TextValue $_.name) -like "*$Escaped*" })
        } elseif ($SearchType -eq 'SystemID / MTM') {
            @($Catalog | Where-Object {
                (ConvertTo-TextValue $_.code) -like "*$Escaped*" -or
                (ConvertTo-TextValue $_.productId) -like "*$Escaped*"
            })
        } else {
            @($Catalog | Where-Object {
                (ConvertTo-TextValue $_.name) -like "*$Escaped*" -or
                (ConvertTo-TextValue $_.code) -like "*$Escaped*" -or
                (ConvertTo-TextValue $_.productId) -like "*$Escaped*"
            })
        }

        return @($Found | Where-Object {
            $Name = ConvertTo-TextValue $_.name
            $Name -notmatch '(?i)-UEFI Lenovo|dTPM|fTPM|Asset'
        } | ForEach-Object {
            [pscustomobject]@{
                Vendor        = 'Lenovo'
                Model         = (ConvertTo-TextValue $_.name).Trim()
                Identifier    = ConvertTo-TextValue $_.code
                ProductId     = ConvertTo-TextValue $_.productId
                DriverSupport = 'Lenovo catalog entry'
                Raw           = $_
            }
        })
    } catch {
        throw "Lenovo search failed: $($_.Exception.Message)"
    }
}

# User-specific settings. Values are intentionally not tied to the script's location.
$script:SettingsPath = "$env:APPDATA\DeviceModelExplorer\settings.json"
$script:DeploymentSettings = [ordered]@{
    OperatingSystem = 'Windows 11'
    Architecture = 'x64'
    Build = '26300'
    Release = '26H2'
}
try {
    if (Test-Path -LiteralPath $script:SettingsPath) {
        $saved = Get-Content -LiteralPath $script:SettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        foreach ($key in @('OperatingSystem','Architecture','Build','Release')) {
            if ($null -ne $saved.$key -and -not [string]::IsNullOrWhiteSpace([string]$saved.$key)) {
                $script:DeploymentSettings[$key] = [string]$saved.$key
            }
        }
    }
} catch { Write-Warning "Settings could not be loaded: $($_.Exception.Message)" }

function Show-DeploymentSettings {
    $settingsXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Deployment String Settings" Width="485" Height="390" MinWidth="430" MinHeight="370"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize" Background="#0B1324"
        Foreground="#F1F6FF" FontFamily="Segoe UI" ShowInTaskbar="False">
    <Window.Resources>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#111E34"/>
            <Setter Property="Foreground" Value="#F1F6FF"/>
            <Setter Property="BorderBrush" Value="#334966"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="Margin" Value="0,5,0,11"/>
            <Setter Property="FontSize" Value="14"/>
        </Style>
    </Window.Resources>
    <Grid Margin="25,21,25,22">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <TextBlock Text="DEPLOYMENT STRING SETTINGS" Foreground="#61AEFF" FontWeight="Bold" FontSize="13"/>
        <TextBlock Grid.Row="1" Text="Set it once. Copy it forever. ProbablyFine(TM)" Foreground="#9FAEC7" Margin="0,6,0,15"/>
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="15"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <StackPanel Grid.Column="0" Grid.Row="0"><TextBlock Text="Operating system"/><TextBox x:Name="OsInput"/></StackPanel>
            <StackPanel Grid.Column="2" Grid.Row="0"><TextBlock Text="Architecture"/><TextBox x:Name="ArchInput"/></StackPanel>
            <StackPanel Grid.Column="0" Grid.Row="1"><TextBlock Text="Build"/><TextBox x:Name="BuildInput"/></StackPanel>
            <StackPanel Grid.Column="2" Grid.Row="1"><TextBlock Text="Release"/><TextBox x:Name="ReleaseInput"/></StackPanel>
        </Grid>
        <DockPanel Grid.Row="3" LastChildFill="False" Margin="0,12,0,0">
            <TextBlock x:Name="SettingsError" DockPanel.Dock="Left" Foreground="#FF9A9A" TextWrapping="Wrap" Width="230" VerticalAlignment="Center"/>
            <Button x:Name="SaveSettings" DockPanel.Dock="Right" Content="Save settings" Padding="18,9" Background="#2675D2" Foreground="White" Margin="8,0,0,0"/>
            <Button x:Name="CancelSettings" DockPanel.Dock="Right" Content="Cancel" Padding="18,9" Background="#283754" Foreground="White"/>
        </DockPanel>
    </Grid>
</Window>
'@
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($settingsXaml))
    try { $dialog = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Dispose() }
    $dialog.Owner = $Window
    $os = $dialog.FindName('OsInput'); $arch = $dialog.FindName('ArchInput')
    $build = $dialog.FindName('BuildInput'); $release = $dialog.FindName('ReleaseInput')
    $errorLabel = $dialog.FindName('SettingsError')
    $os.Text = $script:DeploymentSettings.OperatingSystem
    $arch.Text = $script:DeploymentSettings.Architecture
    $build.Text = $script:DeploymentSettings.Build
    $release.Text = $script:DeploymentSettings.Release
    $dialog.FindName('CancelSettings').Add_Click({ $dialog.DialogResult = $false })
    $dialog.FindName('SaveSettings').Add_Click({
        $values = @($os.Text.Trim(),$arch.Text.Trim(),$build.Text.Trim(),$release.Text.Trim())
        if (@($values | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_.Contains(',') -or $_.Contains("`n") }).Count -gt 0) {
            $errorLabel.Text = 'All fields are required. Commas are not allowed.'
            return
        }
        try {
            $newSettings = [ordered]@{
                OperatingSystem = $values[0]; Architecture = $values[1]
                Build = $values[2]; Release = $values[3]
            }
            $folder = [System.IO.Path]::GetDirectoryName($script:SettingsPath)
            if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force) }
            $tempFile = "$script:SettingsPath.tmp"
            $newSettings | ConvertTo-Json | Set-Content -LiteralPath $tempFile -Encoding utf8 -ErrorAction Stop
            Move-Item -LiteralPath $tempFile -Destination $script:SettingsPath -Force -ErrorAction Stop
            $script:DeploymentSettings = $newSettings
            $dialog.DialogResult = $true
        } catch { $errorLabel.Text = "Save failed: $($_.Exception.Message)" }
    })
    if ($dialog.ShowDialog() -eq $true) {
        Update-Details
        Set-Status 'Deployment string settings saved. Future you says thanks.' 'Success'
    }
}

function Update-Details {
    $Row = $ResultsGrid.SelectedItem
    $ScriptLinesPanel.Children.Clear()
    $script:ScriptReadyLines = @()
    $CopyScriptLineButton.IsEnabled = $false
    if ($null -eq $Row) {
        $DetailTitle.Text = 'Nothing selected'
        $DetailVendor.Text = ''
        $DetailId.Text = ''
        $DetailProduct.Text = ''
        $DetailSupport.Text = ''
        $CopyButton.IsEnabled = $false
        $CopyAllButton.IsEnabled = $false
        return
    }

    $isHp = $Row.Vendor -eq 'HP'
    $DriverLabel.Visibility = if ($isHp) { 'Visible' } else { 'Collapsed' }
    $DetailSupport.Parent.Visibility = if ($isHp) { 'Visible' } else { 'Collapsed' }
    $CopyDetailSupport.Visibility = if ($isHp) { 'Visible' } else { 'Collapsed' }
    $showProduct = $isHp -or -not [string]::IsNullOrWhiteSpace($Row.ProductId)
    $ProductLabel.Visibility = if ($showProduct) { 'Visible' } else { 'Collapsed' }
    $DetailProduct.Parent.Visibility = if ($showProduct) { 'Visible' } else { 'Collapsed' }

    $DetailTitle.Text = $Row.Model
    $DetailVendor.Text = $Row.Vendor
    $DetailId.Text = $Row.Identifier
    $DetailProduct.Text = if ($Row.ProductId) { $Row.ProductId } else { 'Not provided' }
    $DetailSupport.Text = if ($Row.DriverSupport) { $Row.DriverSupport } else { 'Not reported' }
    $CopyButton.IsEnabled = $true
    # Seven CSV-style fields. Manufacturer uses the catalog's HP/Lenovo label.
    # Fixed target OS is intentional and does not imply the model is certified for it.
    $ids = if ($Row.Vendor -eq 'Lenovo') {
        @(([string]$Row.Identifier -split '\s*,\s*') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    } else { @([string]$Row.Identifier) }
    $scriptLines = @(
        foreach ($id in $ids) {
            @($id.Trim(), $Row.Vendor, $Row.Model, $script:DeploymentSettings.OperatingSystem, $script:DeploymentSettings.Architecture, $script:DeploymentSettings.Build, $script:DeploymentSettings.Release) -join ','
        }
    )
    $script:ScriptReadyLines = @($scriptLines)
    foreach ($line in $scriptLines) {
        # Each identifier gets its own independent copy button.
        $linePanel = [System.Windows.Controls.DockPanel]::new()
        $linePanel.Margin = [System.Windows.Thickness]::new(0,0,0,5)
        $copyOne = [System.Windows.Controls.Button]::new()
        $copyOne.Content = 'Copy'
        $copyOne.Tag = [string]$line
        $copyOne.MinWidth = 58
        $copyOne.Padding = [System.Windows.Thickness]::new(8,5,8,5)
        $copyOne.Margin = [System.Windows.Thickness]::new(8,0,0,0)
        $copyOne.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#243A59')
        $copyOne.Foreground = [System.Windows.Media.Brushes]::White
        $copyOne.Add_Click({
            param($sender,$eventArgs)
            [Windows.Clipboard]::SetText([string]$sender.Tag)
            Set-Status 'One model string copied. Precision deploying! ProbablyFine(TM)' 'Success'
        })
        [System.Windows.Controls.DockPanel]::SetDock($copyOne, [System.Windows.Controls.Dock]::Right)
        [void]$linePanel.Children.Add($copyOne)
        $lineText = [System.Windows.Controls.TextBox]::new()
        $lineText.Text = [string]$line
        $lineText.IsReadOnly = $true
        $lineText.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
        $lineText.Background = [System.Windows.Media.Brushes]::Transparent
        $lineText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#DDF4FF')
        $lineText.BorderThickness = [System.Windows.Thickness]::new(0)
        $lineText.Padding = [System.Windows.Thickness]::new(4,5,4,5)
        $lineText.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
        [void]$linePanel.Children.Add($lineText)
        [void]$ScriptLinesPanel.Children.Add($linePanel)
    }
    $CopyScriptLineButton.Content = if ($scriptLines.Count -gt 1) { 'Copy all' } else { 'Copy line' }
    $CopyScriptLineButton.IsEnabled = $scriptLines.Count -gt 0


}

$script:SearchProcess = $null
$script:SearchOutput = $null
$script:SearchStarted = $null
$script:OsRequestId = ''
$script:PendingOsId = ''
$script:SearchTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:SearchTimer.Interval = [TimeSpan]::FromMilliseconds(250)

function Finish-Search {
    $script:SearchTimer.Stop()
    $SearchButton.IsEnabled = $true
    $RefreshButton.IsEnabled = $true
    $VendorBox.IsEnabled = $true
    $SearchTypeBox.IsEnabled = $true
    $SearchBox.IsEnabled = $true
    if ($script:SearchProcess) { $script:SearchProcess.Dispose(); $script:SearchProcess = $null }
    if ($script:SearchOutput) {
        Remove-Item -LiteralPath $script:SearchOutput -Force -ErrorAction SilentlyContinue
        $script:SearchOutput = $null
    }
}

$script:SearchTimer.Add_Tick({
    try {
        if (-not $script:SearchProcess) { return }
        if (-not $script:SearchProcess.HasExited) {
            if (((Get-Date) - $script:SearchStarted).TotalSeconds -gt 90) {
                $script:SearchProcess.Kill()
                Set-Status 'Search timed out after 90 seconds. Try again.' 'Error'
                Finish-Search
            }
            return
        }
        if (-not (Test-Path -LiteralPath $script:SearchOutput)) {
            Set-Status 'Worker exited without results. Check PowerShell 7 and HP CMSL installation.' 'Error'
            Finish-Search
            return
        }
        $data = Get-Content -LiteralPath $script:SearchOutput -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $data.Success) {
            Set-Status "Search failed: $($data.Error)" 'Error'
        } else {
            $script:CurrentRows = @($data.Rows | Where-Object { $null -ne $_ } | Sort-Object Vendor, Model, Identifier -Unique)
            $ResultsGrid.ItemsSource = $script:CurrentRows
            if ($script:CurrentRows.Count -gt 0) {
                Set-Status "Found $($script:CurrentRows.Count) suspects. Pick your favorite." 'Success'
                $ExportButton.IsEnabled = $true
                $ResultsGrid.SelectedIndex = 0
            } else {
                $ExportButton.IsEnabled = $false
                Set-Status 'No matches. Apparently, this device does not exist. Try another identifier.' 'Warning'
            }
        }
        Finish-Search
    } catch {
        Set-Status "Result processing failed: $($_.Exception.Message)" 'Error'
        Finish-Search
    }
})

function Invoke-Search {
    if ($script:SearchProcess) { return }
    $query = $SearchBox.Text.Trim()
    if (-not $query) { Set-Status 'Enter a model name or identifier.' 'Warning'; return }
    $vendor = ([System.Windows.Controls.ComboBoxItem]$VendorBox.SelectedItem).Content.ToString()
    $searchType = ([System.Windows.Controls.ComboBoxItem]$SearchTypeBox.SelectedItem).Content.ToString()
    $ResultsGrid.ItemsSource = $null
    Update-Details
        try {
        $script:SearchOutput = [System.IO.Path]::GetTempFileName()
        Remove-Item -LiteralPath $script:SearchOutput -Force
        $pwsh = (Get-Process -Id $PID).Path
        $arguments = @(
            '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
            '-Worker', '-WorkerVendor', $vendor, '-WorkerSearchType', $searchType,
            '-WorkerQuery', $query, '-WorkerOutput', $script:SearchOutput
        )
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $pwsh
        foreach ($argument in $arguments) { [void]$psi.ArgumentList.Add($argument) }
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $script:SearchProcess = [System.Diagnostics.Process]::Start($psi)
        $script:SearchStarted = Get-Date
        $SearchButton.IsEnabled = $false
        $RefreshButton.IsEnabled = $false
        $VendorBox.IsEnabled = $false
        $SearchTypeBox.IsEnabled = $false
        $SearchBox.IsEnabled = $false
        Set-Status "Interrogating $vendor catalog for '$query'..." 'Normal'
        $script:SearchTimer.Start()
    } catch {
        Set-Status "Could not start search: $($_.Exception.Message)" 'Error'
        Finish-Search
    }
}


# All detail values are read-only, selectable, and copied with a single click.
foreach ($control in @($DetailTitle,$DetailVendor,$DetailId,$DetailProduct,$DetailSupport)) {
    $control.Add_PreviewMouseLeftButtonUp({
        param($sender,$eventArgs)
        if (-not [string]::IsNullOrWhiteSpace($sender.Text) -and $sender.Text -ne 'Not provided') {
            [Windows.Clipboard]::SetText($sender.Text)
            Set-Status "Copied: $($sender.Text)" 'Success'
        }
    })
}

function Copy-SelectedIdentifier {
    $Row = $ResultsGrid.SelectedItem
    if ($null -ne $Row -and -not [string]::IsNullOrWhiteSpace($Row.Identifier)) {
        [Windows.Clipboard]::SetText($Row.Identifier)
        Set-Status "Copied '$($Row.Identifier)' to the clipboard." 'Success'
    }
}

foreach ($pair in @(
    @($CopyDetailTitle, $DetailTitle),
    @($CopyDetailVendor, $DetailVendor),
    @($CopyDetailId, $DetailId),
    @($CopyDetailProduct, $DetailProduct),
    @($CopyDetailSupport, $DetailSupport)
)) {
    $button = $pair[0]
    $field = $pair[1]
    $button.Tag = $field
    $button.Add_Click({
        param($sender, $eventArgs)
        $value = [string]$sender.Tag.Text
        if ($value -and $value -notin @('Not provided','Not reported','Nothing selected')) {
            [Windows.Clipboard]::SetText($value)
            Set-Status "Copied: $value. Go deploy something." 'Success'
        }
    })
}

$SearchButton.Add_Click({ Invoke-Search })
$SearchBox.Add_KeyDown({ if ($_.Key -eq [Windows.Input.Key]::Enter) { Invoke-Search } })
$ResultsGrid.Add_SelectionChanged({ Update-Details })
$ResultsGrid.Add_MouseDoubleClick({ Copy-SelectedIdentifier })
$CopyButton.Add_Click({ Copy-SelectedIdentifier })
$CopyScriptLineButton.Add_Click({
    if ($script:ScriptReadyLines.Count -gt 0) {
        [Windows.Clipboard]::SetText(($script:ScriptReadyLines -join [Environment]::NewLine))
        Set-Status 'Script-ready model strings copied. Go deploy something.' 'Success'
    }
})
$CopyAllButton.Add_Click({
    $row = $ResultsGrid.SelectedItem
    if (-not $row) { return }
    $lines = @("Vendor: $($row.Vendor)", "Model: $($row.Model)", "SystemID / MTM: $($row.Identifier)", "Product ID: $($row.ProductId)", "Driver packs: $($row.DriverSupport)")
    [Windows.Clipboard]::SetText($lines -join [Environment]::NewLine)
    Set-Status 'All available details copied. Go deploy something.' 'Success'
})
$ExportButton.Add_Click({
    if (-not $script:CurrentRows -or $script:CurrentRows.Count -eq 0) { return }
    $dialog = [Microsoft.Win32.SaveFileDialog]::new()
    $dialog.Title = 'Export model search results'
    $dialog.Filter = 'CSV files (*.csv)|*.csv'
    $dialog.FileName = 'Device-Model-Explorer.csv'
    if ($dialog.ShowDialog($Window) -eq $true) {
        try {
            $script:CurrentRows | Select-Object Vendor,Model,Identifier,ProductId,DriverSupport | Export-Csv -LiteralPath $dialog.FileName -NoTypeInformation -Encoding utf8BOM
            Set-Status "Exported $($script:CurrentRows.Count) models to CSV." 'Success'
        } catch { Set-Status "Export failed: $($_.Exception.Message)" 'Error' }
    }
})
$SettingsButton.Add_Click({ Show-DeploymentSettings })
$RefreshButton.Add_Click({
    # Each lookup requests fresh vendor data; rerun the current query.
    if (-not [string]::IsNullOrWhiteSpace($SearchBox.Text)) {
        Invoke-Search
    } else {
        Set-Status 'Enter a model or ID to refresh the catalog search.' 'Normal'
    }
})
$Window.Add_Closing({
    $script:SearchTimer.Stop()
    if ($script:SearchProcess -and -not $script:SearchProcess.HasExited) {
        try { $script:SearchProcess.Kill() } catch { }
    }
    if ($script:SearchOutput) { Remove-Item -LiteralPath $script:SearchOutput -Force -ErrorAction SilentlyContinue }
})
$Window.Add_ContentRendered({
    [void](Test-HpCmsl)
    $SearchBox.Focus()
})

[void]$Window.ShowDialog()
