<h1 align="center">DeployR Model Not Certified Popup</h1>

<p align="center">
  An Avalonia-based device certification warning popup for 2Pint DeployR task sequences.
</p>

<p align="center">
  <strong>Community script</strong> &bull; <strong>PowerShell</strong> &bull; <strong>Avalonia UI</strong>
</p>

<hr>

<h2>Overview</h2>

<p>
  <code>ModelNotCertified-Avalonia.ps1</code> displays a modern warning dialog when a device model is not approved for OS deployment. It shows device information collected from the DeployR task sequence environment, including manufacturer, model alias, system alias, and serial number.
</p>

<p>
  The popup also includes a little deployment-team humor: the <em>Blame deployment team</em> button moves away when you try to point at it. The practical button is <em>OK, blame the hardware</em>.
</p>

<blockquote>
  <strong>Important:</strong> This script is informational only. It always exits with code <code>0</code> and does <strong>not</strong> stop the task sequence itself. Configure your DeployR task sequence to handle the unsupported model and stop deployment separately.
</blockquote>

<h2>Features</h2>

<ul>
  <li>Modern, dark-themed Avalonia warning window.</li>
  <li>Reads device details from DeployR task sequence variables.</li>
  <li>Displays Make, MakeAlias, ModelAlias, SystemAlias, and SerialNumber.</li>
  <li>Supports WinPE by launching an isolated PowerShell child process for the popup.</li>
  <li>Automatically searches common DeployR client locations for the Avalonia runtime.</li>
  <li>Falls back to sample Lenovo device data when the DeployR environment is unavailable, useful for local UI testing.</li>
  <li>Writes diagnostic messages to a local log file.</li>
  <li>Supports closing with the OK button, Enter, or Escape.</li>
</ul>

<h2>Requirements</h2>

<ul>
  <li>2Pint DeployR environment with the <code>DeployR.Utility</code> PowerShell module for real task sequence values.</li>
  <li>DeployR client files containing the required Avalonia assemblies and native runtime dependencies.</li>
  <li>A suitable PowerShell executable available to run the script and, in WinPE, the isolated child process.</li>
  <li>An interactive desktop environment capable of displaying the Avalonia window.</li>
</ul>

<p><strong>Note:</strong> The script loads Avalonia DLLs from the DeployR client installation. It does not download or install Avalonia automatically.</p>

<h2>How it works</h2>

<ol>
  <li>Attempts to import <code>DeployR.Utility</code> and read task sequence variables.</li>
  <li>If unavailable, loads clearly marked local demo values.</li>
  <li>Locates the DeployR client directory and its Avalonia DLLs.</li>
  <li>In WinPE, passes device data to an isolated PowerShell process and displays the UI there.</li>
  <li>Shows the device information and a deployment-blocked warning.</li>
  <li>Closes the popup and returns exit code <code>0</code>. The task sequence must enforce any deployment stop.</li>
</ol>

<h2>Usage</h2>

<p>Include <code>ModelNotCertified-Avalonia.ps1</code> in the appropriate branch of your DeployR task sequence, after your own model certification check has identified an unsupported device.</p>

<p>For a local UI test, run:</p>

<pre><code class="language-powershell">pwsh.exe -NoProfile -File .\ModelNotCertified-Avalonia.ps1</code></pre>

<p>If DeployR task sequence variables are not available, the popup uses demo values such as <code>ThinkPad X1 Yoga Gen 7</code> and <code>DEMO-123456</code>. This fallback is for demonstration and does not validate model support.</p>

<h3>Task sequence integration</h3>

<p>Use your existing DeployR model approval logic to decide when to call the popup. Then explicitly stop or fail the deployment in the task sequence if the model is not certified. Do not rely on the popup's exit code for enforcement.</p>

<h2>Task sequence variables</h2>

<ul>
  <li><code>Make</code></li>
  <li><code>MakeAlias</code></li>
  <li><code>ModelAlias</code></li>
  <li><code>SystemAlias</code></li>
  <li><code>SerialNumber</code></li>
</ul>

<p>Missing or blank values are displayed as <code>Not set</code>.</p>

<h2>Runtime paths and logging</h2>

<p>The script checks common DeployR client locations, including:</p>

<pre><code>C:\_2P\Client
X:\_2P\Client
C:\Program Files\2Pint Software\DeployR\Client</code></pre>

<p>Diagnostic log:</p>

<pre><code>C:\Windows\Temp\DeployR-ModelNotCertified-Avalonia.log</code></pre>

<p>The log can contain local paths and runtime errors. Review logs before sharing them publicly.</p>

<h2>Limitations</h2>

<ul>
  <li>The script does <strong>not</strong> determine whether a model is certified. That decision belongs to your deployment logic.</li>
  <li>The script does <strong>not</strong> terminate deployment. It exits successfully even when the popup cannot be displayed.</li>
  <li>When DeployR variables cannot be read, demo values are shown rather than failing closed.</li>
  <li>Runtime compatibility depends on the Avalonia assemblies and PowerShell environment available on the target machine.</li>
  <li>Test the popup in your own DeployR and WinPE environments before production use.</li>
</ul>

<h2>Disclaimer</h2>

<p>This is an independent, community-created script, not an official 2Pint Software product or supported component. Provided as-is, without warranty or official support. Validate and adapt it for your environment before using it in production.</p>

<hr>

<p align="center"><em>Less clicking. More deploying. ProbablyFine™</em></p>
