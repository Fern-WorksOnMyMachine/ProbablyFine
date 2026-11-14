<h1>Device Model Explorer</h1>

<p><strong>Device Model Explorer</strong> is a PowerShell 7 WPF utility for looking up HP and Lenovo device models and their deployment identifiers.</p>

<p>It is useful when building model lists, driver-pack automation, deployment rules, or CSV input where a friendly model name must be matched to an HP SystemID or Lenovo machine type/model identifier.</p>

<br>

<h2>Supported vendors</h2>

<ul>
  <li><strong>HP:</strong> Search by model name or four-character HP SystemID. HP results are retrieved through HP Client Management Script Library (HP CMSL).</li>
  <li><strong>Lenovo:</strong> Search by friendly model name, machine type/model (MTM), catalog code, or product ID. Lenovo data is retrieved from Lenovo's public <code>allModels.json</code> catalog.</li>
</ul>

<p><strong>Designed for HP and Lenovo.</strong><br>
Other manufacturers are not supported by this version.</p>

<br>

<h2>Features</h2>

<ul>
  <li>Modern graphical interface for Windows.</li>
  <li>Search by model name or vendor identifier.</li>
  <li>Automatic detection of common HP SystemID and Lenovo MTM searches.</li>
  <li>Copy individual values or complete model details.</li>
  <li>Export search results to CSV.</li>
  <li>Generate script-ready CSV-style model strings.</li>
  <li>Store deployment-string settings in the current user's application-data folder.</li>
  <li>Run vendor searches in a separate PowerShell process so the interface remains responsive.</li>
</ul>

<br>

<h2>Requirements</h2>

<ul>
  <li>Windows 10 or Windows 11, 64-bit.</li>
  <li>PowerShell 7 or later.</li>
  <li>Internet access to the HP and Lenovo catalog services.</li>
  <li>HP CMSL is required for HP searches.</li>
</ul>

<br>

<h3>Install PowerShell 7</h3>

<p>Install PowerShell 7 with Windows Package Manager:</p>

<pre><code>winget install --id Microsoft.PowerShell --source winget</code></pre>

<br>

<h3>Install HP CMSL</h3>

<p>Open PowerShell 7 and run:</p>

<pre><code>Install-Module -Name HPCMSL -Scope CurrentUser -Force -AcceptLicense</code></pre>

<p>Confirm that the required command is available:</p>

<pre><code>Get-Command Get-HPDeviceDetails</code></pre>

<p><em>Lenovo searches do not require an additional PowerShell module.</em></p>

<br>

<h2>Running the script</h2>

<ol>
  <li>Save the script as <code>Device-Model-Explorer.ps1</code>.</li>
  <li>Open PowerShell 7.</li>
  <li>Run the script:</li>
</ol>

<pre><code>pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\Tools\Device-Model-Explorer\Device-Model-Explorer.ps1"</code></pre>

<p>Replace the example path with the actual location of the script.</p>

<br>

<h2>Create a desktop shortcut</h2>

<ol>
  <li>Right-click the desktop and select <strong>New &gt; Shortcut</strong>.</li>
  <li>Enter the following as the location:</li>
</ol>

<pre><code>"C:\Program Files\PowerShell \pwsh.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Tools\Device-Model-Explorer\Device-Model-Explorer.ps1"</code></pre>

<ol start="3">
  <li>Select <strong>Next</strong>.</li>
  <li>Name the shortcut <strong>Device Model Explorer</strong>.</li>
  <li>Select <strong>Finish</strong>.</li>
</ol>

<p>If the PowerShell console briefly appears, remove <code>-WindowStyle Hidden</code while troubleshooting so startup errors remain visible.</p>

<br>

<h3>Optional: create the shortcut with PowerShell</h3>

<pre><code>$ShortcutPath = "$env:USERPROFILE\Desktop\Device Model Explorer.lnk"
$PowerShellPath = "C:\Program Files\PowerShell \pwsh.exe"
$ScriptPath = "C:\Tools\Device-Model-Explorer\Device-Model-Explorer.ps1"

$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $PowerShellPath
$Shortcut.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
$Shortcut.WorkingDirectory = "C:\Tools\Device-Model-Explorer"
$Shortcut.Description = "Search HP and Lenovo device models and identifiers"
$Shortcut.Save()</code></pre>

<br>

<h2>Deployment-string settings</h2>

<p>The settings button lets you define the operating system, architecture, build, and release used in generated model strings.</p>

<p>Settings are stored per user in:</p>

<pre><code>%APPDATA%\DeviceModelExplorer\settings.json</code></pre>

<p>The generated values are formatting inputs. They do not certify that a selected model supports the configured Windows release.</p>

<br>

<h2>Data sources and network access</h2>

<ul>
  <li>HP searches use commands provided by HP CMSL.</li>
  <li>Lenovo searches download the public catalog from <code>https://download.lenovo.com/bsco/public/allModels.json</code>.</li>
</ul>

<p>No credentials, API keys, tokens, internal server names, or organization-specific paths are required by the script.</p>

<br>

<h2>Notes</h2>

<ul>
  <li>This is a community utility and is not an official HP, Lenovo, or Microsoft product.</li>
  <li>Catalog data is controlled by the respective vendor and may change without notice.</li>
  <li>Review generated identifiers before using them in production deployment automation.</li>
</ul>

<br>

<h2>License</h2>

<p>Add the license that applies to your repository, for example MIT, before publishing or redistributing the script.</p>
