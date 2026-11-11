Testing DeployR Avalonia Scripts Locally (Offline)
DeployR Avalonia-based PowerShell scripts can be tested locally on a Windows computer without running a task sequence or booting into WinPE.

1. Copy the DeployR runtime files
On a computer with the DeployR Client installed, locate the default installation directory:

C:\Program Files\2Pint Software\DeployR\Client
Copy the entire Client directory, including all Avalonia DLLs, dependencies, and the runtimes subfolder, to your local test computer.

Place the files here:

C:\_2P\Client
Make sure the following directory exists:

C:\_2P\Client\runtimes\win-x64\native
Important: Copy the complete directory structure. Do not copy individual DLL files or flatten the folders.

2. Run PowerShell 7
Open PowerShell 7 (pwsh.exe).

The Avalonia scripts use the runtime libraries provided by DeployR, so no separate Avalonia installation should be necessary when all required dependencies are present.

3. Run an Avalonia script
For scripts that automatically configure the native runtime path:

pwsh.exe -NoProfile -File "C:\Scripts\DeployR-BatteryWarning-Avalonia.ps1"
For scripts that require the native library path to be configured manually:

pwsh.exe -NoProfile -Command '$env:PATH="C:\_2P\Client\runtimes\win-x64\native;$env:PATH"; & "C:\Scripts\TS-Fireworks-Avalonia.ps1" -DurationSeconds 15'
4. Testing without a DeployR task sequence
Some scripts support a built-in demo mode.

When DeployR.Utility or the task sequence environment is unavailable, these scripts can display sample values instead of actual DeployR variables.

This allows you to test the interface, layout, buttons, and other UI functionality without starting a deployment.

Note: Demo mode depends on the individual script. Not all scripts automatically provide sample data.

5. Important notes
Windows and PowerShell 7 are recommended for local testing.
Keep the original DeployR directory structure intact.
Use the same DeployR runtime version as your deployment environment.
Local testing verifies the UI but does not guarantee WinPE compatibility.
Always perform a final test inside a real DeployR task sequence before production use.
That's it! You can now develop and test Avalonia-based DeployR interfaces locally without rebooting into WinPE every time.

Less rebooting. More debugging. ProbablyFine™ 😄
