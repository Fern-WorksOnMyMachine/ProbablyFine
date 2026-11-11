<h1>Testing DeployR Avalonia Scripts Locally (Offline)</h1>

<p>
DeployR Avalonia-based PowerShell scripts can be tested locally on a
Windows computer without running a task sequence or booting into WinPE.
</p>

<p>
This is especially useful when developing custom deployment interfaces,
testing layouts, troubleshooting Avalonia dependencies, or simply avoiding
another trip through the PXE boot process.
</p>

<hr>

<h2>1. Copy the Required Files from the DeployR Server</h2>

<p>
On your <strong>DeployR Server</strong>, navigate to the default
installation directory:
</p>

<pre><code>C:\Program Files\2Pint Software\DeployR</code></pre>

<p>
Locate the following two directories:
</p>

<pre><code>C:\Program Files\2Pint Software\DeployR\Client
C:\Program Files\2Pint Software\DeployR\Runtimes</code></pre>

<p>
Copy the contents of the <strong>Client</strong> directory to:
</p>

<pre><code>C:\_2P\Client</code></pre>

<p>
Copy the contents of the <strong>Runtimes</strong> directory to:
</p>

<pre><code>C:\_2P\Runtimes</code></pre>

<p>
The resulting directory structure should look similar to:
</p>

<pre><code>C:\_2P\Client\
    Avalonia.Base.dll
    Avalonia.Controls.dll
    Avalonia.Desktop.dll
    Avalonia.Markup.Xaml.dll
    Avalonia.Markup.Xaml.Loader.dll
    ...
C:\_2P\Client\runtimes\
    win-x64\
    native\
    ...</code></pre>

<p>
<strong>Important:</strong>
Keep the original directory structure intact.
Do not flatten folders or copy only individual Avalonia DLL files.
</p>

<p>
The native runtime dependencies are just as important as the
managed Avalonia assemblies.
</p>

<hr>

<h2>2. Requirements</h2>

<ul>
    <li>Windows 10 or Windows 11</li>
    <li>PowerShell 7 (64-bit)</li>
    <li>DeployR Client and Runtimes files copied from the DeployR Server</li>
    <li>The Avalonia-based PowerShell script you want to test</li>
</ul>

<p>
A separate Avalonia installation is normally unnecessary when the
required libraries are already available in the copied DeployR files.
</p>

<p>
For best compatibility, use runtime files from the same DeployR version
as your actual deployment environment.
</p>

<hr>

<h2>3. Configure the Native Runtime Path</h2>

<p>
Some Avalonia scripts automatically configure the required native
runtime path. Others may require it to be set manually.
</p>

<p>
During our testing, explicitly adding the native directory to
<strong>PATH</strong> resolved cases where a script started
but failed to display its interface.
</p>

<p>
Open PowerShell 7 and run:
</p>

<pre><code>$env:PATH = "C:\_2P\Client\runtimes\win-x64\native;$env:PATH"</code></pre>

<p>
This makes the native runtime libraries available to the current
PowerShell process.
</p>

<p>
<strong>Note:</strong>
The PATH modification only applies to the current process
and any child processes started from it.
</p>

<hr>

<h2>4. Run an Avalonia Script Locally</h2>

<p>
For scripts that automatically configure their runtime dependencies,
you can normally use:
</p>

<pre><code>pwsh.exe -NoProfile -File "C:\Scripts\DeployR-BatteryWarning-Avalonia.ps1"</code></pre>

<p>
For scripts that require the native runtime path to be configured
manually, use:
</p>

<pre><code>pwsh.exe -NoProfile -Command '$env:PATH="C:\_2P\Client\runtimes\win-x64\native;$env:PATH"; &amp; "C:\Scripts\TS-Fireworks-Avalonia.ps1" -DurationSeconds 15'</code></pre>

<p>
This starts PowerShell 7, configures the native runtime path,
and launches the script.
</p>

<p>
<strong>Tip:</strong>
Always place script parameters outside the quotation marks
surrounding the script path.
</p>

<p>
Correct:
</p>

<pre><code>pwsh.exe -NoProfile -File "C:\Scripts\Example.ps1" -DurationSeconds 15</code></pre>

<p>
Incorrect:
</p>

<pre><code>pwsh.exe -NoProfile -File "C:\Scripts\Example.ps1 -DurationSeconds 15"</code></pre>

<hr>

<h2>5. Testing Without a DeployR Task Sequence</h2>

<p>
Some custom DeployR Avalonia scripts include a built-in demo mode.
</p>

<p>
These scripts attempt to load:
</p>

<pre><code>Import-Module DeployR.Utility</code></pre>

<p>
When the DeployR task sequence environment is unavailable,
scripts with demo support can automatically load sample values.
</p>

<p>
For example:
</p>

<pre><code>Make:         Lenovo
MakeAlias:    Lenovo
ModelAlias:   ThinkPad X1 Yoga Gen 7
SystemAlias:  21CD
SerialNumber: DEMO-123456</code></pre>

<p>
This makes it possible to test:
</p>

<ul>
    <li>Window layout and scaling</li>
    <li>Buttons and keyboard shortcuts</li>
    <li>Countdown timers</li>
    <li>Status messages</li>
    <li>Animations and visual effects</li>
    <li>Different hardware information values</li>
</ul>

<p>
<strong>Important:</strong>
Demo mode is implemented by the individual script.
It is not a built-in feature of Avalonia or DeployR.
</p>

<p>
If a script does not include demo support, it may require
a real DeployR task sequence environment.
</p>

<hr>

<h2>6. Understanding the Difference Between Local Testing and WinPE</h2>

<p>
Local testing is excellent for validating the graphical interface,
but it does not fully reproduce the DeployR WinPE environment.
</p>

<p>
Inside a real DeployR task sequence, scripts can access
task sequence variables through:
</p>

<pre><code>Import-Module DeployR.Utility

$Make = ${TSEnv:Make}
$Model = ${TSEnv:ModelAlias}
$Serial = ${TSEnv:SerialNumber}</code></pre>

<p>
These variables are normally provided by the active
DeployR task sequence environment.
</p>

<p>
When an Avalonia interface runs in a separate PowerShell process,
task sequence variables may not automatically be available
inside that child process.
</p>

<p>
A reliable approach is to:
</p>

<ol>
    <li>Read the required task sequence variables in the original process.</li>
    <li>Store the values in a PowerShell object.</li>
    <li>Pass the values to the isolated Avalonia process.</li>
    <li>Display the values without requiring the child process to reconnect to the task sequence environment.</li>
</ol>

<p>
This approach is particularly useful when running custom Avalonia
interfaces inside WinPE.
</p>

<hr>

<h2>7. Common Troubleshooting Tips</h2>

<h3>The script runs, but no window appears</h3>

<p>
Check that the native runtime directory exists:
</p>

<pre><code>C:\_2P\Client\runtimes\win-x64\native</code></pre>

<p>
Try launching the script with the native directory explicitly
added to PATH.
</p>

<h3>Avalonia DLL loading fails</h3>

<p>
Verify that both the Client and Runtimes directories were copied
completely from the DeployR Server.
</p>

<p>
Avoid mixing libraries from different DeployR or Avalonia versions.
</p>

<h3>The window displays demo information</h3>

<p>
This is expected when the script supports demo mode and cannot access
a valid DeployR task sequence environment.
</p>

<h3>The script works locally but not in WinPE</h3>

<p>
Verify the following:
</p>

<ul>
    <li>PowerShell 7 is available in WinPE.</li>
    <li>All required Avalonia dependencies are present.</li>
    <li>Native runtime libraries can be located.</li>
    <li>The script runs in the appropriate interactive session.</li>
    <li>Required DeployR variables are read before launching an isolated GUI process.</li>
    <li>The script uses paths that are valid in the WinPE environment.</li>
</ul>

<p>
Remember that WinPE may use different drive letters and runtime
locations than your local Windows installation.
</p>

<hr>

<h2>8. Final Recommendations</h2>

<ul>
    <li>Develop and test the GUI locally whenever possible.</li>
    <li>Use PowerShell 7 and the correct runtime architecture.</li>
    <li>Keep runtime dependencies together.</li>
    <li>Use demo values for testing when no task sequence is available.</li>
    <li>Keep deployment logic separate from GUI presentation logic.</li>
    <li>Use an isolated PowerShell process when required by the WinPE environment.</li>
    <li>Test all buttons, exit codes, and timeout behavior.</li>
    <li>Always perform a final test in a real DeployR task sequence.</li>
</ul>

<hr>

<h2>Ready to Test!</h2>

<p>
You can now develop, troubleshoot, and test custom Avalonia-based
DeployR interfaces locally without booting into WinPE for every
small change.
</p>

<p>
<strong>Less clicking. More deploying. ProbablyFine&trade;</strong>
</p>
