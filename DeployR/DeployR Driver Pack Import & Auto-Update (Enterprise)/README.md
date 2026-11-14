<h1>DeployR Driver Pack Import and Auto-Update Script</h1>

  <p>
    This is a new PowerShell script for DeployR Enterprise customers to import OEM driver packs into 2Pint DeployR and keep
    existing Driver Pack Content Items aligned with the 2Pint driver catalog.
  </p>

  <div class="callout warning">
    <strong>Early release:</strong> Tested only with HP and Lenovo models. The script has received basic testing, but it appears to work
    correctly in my environment. Test it in a non-production environment first, review the output,
    and keep a backup. In other words: tested enough to be useful, not enough to blame the laws of
    physics if your driver catalog has opinions of its own.
  </div>

  <h2>🔐 DeployR Enterprise Only</h2>
  <div class="callout warning">
    <strong>Requires 2Pint DeployR Enterprise.</strong> This script relies on access to the 2Pint OEM Driver Catalog API and is not intended for DeployR Community.
  </div>
  <ul>
    <li>✅ DeployR Enterprise with valid Driver Catalog API access.</li>
    <li>❌ DeployR Community is not supported.</li>
    <li>🧪 Basic testing has been performed with HP and Lenovo only.</li>
    <li>❓ Dell and other manufacturers have not been tested.</li>
  </ul>

  <h2>What is new?</h2>

  <blockquote>
    I've now extended it to also check the 2Pint driver catalog for changes, comparing package IDs
    and hashes. If something has changed, it updates the existing Content Item without creating a
    new version. Unchanged packages are skipped.
  </blockquote>

  <p>
    The purpose is to support both initial imports and later maintenance from the same model list.
    On the first run, the script can download and publish missing driver packs. On later runs, it can
    detect catalog changes and refresh only the affected DeployR Content Items.
  </p>

  <h2>Exactly what the script does</h2>

  <ol>
    <li>Reads device definitions from <code>Models.csv</code>.</li>
    <li>Uses each row to query the 2Pint driver-pack catalog by system alias, manufacturer, model, operating system, architecture, build, and release ID.</li>
    <li>Checks whether a matching DeployR Content Item already exists using the name <code>Driver Pack - Manufacturer - Model</code>.</li>
    <li>Collects the package ID and content hash for every package returned by the catalog.</li>
    <li>Compares the current package signature with the last successfully stored signature in <code>DriverPackVersions.json</code>.</li>
    <li>Skips existing packages when the package IDs and hashes are unchanged.</li>
    <li>Downloads packages when the Content Item is missing, when catalog content has changed, or when an existing item requires its initial tracked baseline.</li>
    <li>Extracts supported CAB, ZIP, EXE, and MSI packages.</li>
    <li>Combines multiple catalog packages for the same model into one clean staging folder.</li>
    <li>Rejects an extraction if no files were produced, preventing an empty staging folder from being uploaded.</li>
    <li>Creates a new DeployR Driver Pack Content Item when one does not already exist.</li>
    <li>Updates the active content of an existing Content Item when a catalog change is detected. It does not intentionally create a new Content Item version for that update.</li>
    <li>Saves state only after a successful publish and prints a final summary of imported, updated, unchanged, and failed models.</li>
    <li>Continues with the next model if one model fails, while reporting the failure under <code>Needs review</code> or <code>Failed</code>.</li>
  </ol>

  <h2>Update behavior</h2>

  <table>
    <thead>
      <tr>
        <th>Situation</th>
        <th>Result</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>No matching DeployR Content Item exists</td>
        <td>The driver pack is downloaded, extracted, validated, and imported as a new Driver Pack Content Item.</td>
      </tr>
      <tr>
        <td>An item exists, but no local baseline has been recorded</td>
        <td>The content is refreshed once, when package IDs and hashes are available, and the resulting catalog signature is stored.</td>
      </tr>
      <tr>
        <td>The stored package IDs and hashes match the catalog</td>
        <td>The model is skipped and counted as unchanged.</td>
      </tr>
      <tr>
        <td>A package ID or hash differs</td>
        <td>The packages are downloaded again and the active content of the existing Content Item is updated.</td>
      </tr>
      <tr>
        <td>Required package metadata is missing</td>
        <td>The model is not automatically updated and is reported for review.</td>
      </tr>
    </tbody>
  </table>

  <div class="callout">
    <strong>Important:</strong> The catalog snapshot date is not treated as the driver package
    version. Change detection is based on package IDs and content-specific hashes instead.
  </div>

  <h2>Dependencies</h2>

  <h3>PowerShell and runtime</h3>
  <ul>
    <li><strong>PowerShell 7 or later</strong> is recommended and is required by the script's use of <code>ConvertFrom-Json -AsHashtable</code>.</li>
    <li><strong>dotnet.exe</strong> must be available when MSI packages need to be extracted through <code>TwoPint.DeployR.ExtractMSI.dll</code>.</li>
    <li><strong>expand.exe</strong> is used for CAB extraction and is normally included with Windows.</li>
  </ul>

  <h3>DeployR.Utility</h3>
  <p>
    The DeployR PowerShell module provides the commands used to connect to DeployR and manage
    Content Items, versions, and uploaded content. The default module path is:
  </p>
  <pre><code>C:\Program Files\2Pint Software\DeployR\Client\PSModules\DeployR.Utility</code></pre>
  <p>
    Change <code>$DeployRModulePath</code> in the configuration section if the module is installed elsewhere.
  </p>

  <h3>DeployRPasscode</h3>
  <p>
    <code>$DeployRPasscode</code> is used by <code>Connect-DeployR</code> to authenticate to the DeployR
    environment. Enter it only in your private local copy or provide it through your own secure
    mechanism. Do not commit a real passcode to GitHub.
  </p>

  <h3>🔑 DeployRToken (Enterprise Only)</h3>
  <p>
    <code>$DeployRToken</code> is sent as a bearer token when querying the 2Pint OEM Driver Catalog API.
    It is <strong>not</strong> the same as your <code>DeployRPasscode</code>.
  </p>
  <h4>How do I get a DeployRToken?</h4>
  <p>
    Honestly, I grabbed mine from a log file generated by DeployR's built-in driver pack download
    functionality. 😁 If you're an Enterprise customer, try downloading a driver pack using the
    built-in feature and check the related logs for the API token.
  </p>
  <p>
    If you can't find it, contact 2Pint Software and ask how to obtain the token required for
    the OEM Driver Catalog API. This is how I obtained mine, not an officially documented procedure.
  </p>
  <pre><code>$DeployRToken = 'YOUR_TOKEN_HERE'</code></pre>

  <p>I borrowed mine from a log file. Let's call it creative troubleshooting. ProbablyFine™ 😎</p>

  <h3>7za.exe</h3>
  <p>
    <code>7za.exe</code> is used to extract HP SoftPaq-style executable packages. The default expected
    location is:
  </p>
  <pre><code>Tools\x64\7za.exe</code></pre>

  <h3>innoextract.exe</h3>
  <p>
    <code>innoextract.exe</code> is used to extract supported Lenovo executable driver packages that use
    an Inno Setup-based wrapper. The default expected location is:
  </p>
  <pre><code>Tools\x64\innoextract.exe</code></pre>

  <h3>TwoPint.DeployR.ExtractMSI.dll</h3>
  <p>
    <code>TwoPint.DeployR.ExtractMSI.dll</code> is used with <code>dotnet.exe</code> to extract MSI-based
    driver packages. By default, the DLL is expected in the same directory as the script.
  </p>

  <h2>Expected folder structure</h2>

  <pre><code>CloudDrivers/
├── CloudDrivers-NewAndAutoUpdate-Public.ps1
├── Models.csv
├── TwoPint.DeployR.ExtractMSI.dll
└── Tools/
    └── x64/
        ├── 7za.exe
        └── innoextract.exe</code></pre>

  <p>
    The script creates its working folders and state file beneath the configured paths. The public
    version defaults to paths relative to <code>$PSScriptRoot</code>, so no internal drive letters are required.
  </p>

  <h2>Models.csv</h2>

  <p>The CSV file must contain these columns:</p>

  <pre><code>SystemAlias,Manufacturer,Model,OS,osArch,OSBuild,OSReleaseId</code></pre>

  <p>Example:</p>

  <pre><code>SystemAlias,Manufacturer,Model,OS,osArch,OSBuild,OSReleaseId
YOUR-SYSTEM-ID,HP,Example Model,Windows 11,x64,26100,24H2</code></pre>

  <p>
    Replace the example values with identifiers and operating-system data that are valid for the
    models in your environment.
  </p>

  <h2>Configuration</h2>

  <p>Review the configuration block at the beginning of the script before running it:</p>

  <pre><code># Credentials
$DeployRPasscode = ''
$DeployRToken = ''

# Input, working, state, module, and extraction tool paths
$DeviceList = "$PSScriptRoot\Models.csv"
$DestinationRoot = "$PSScriptRoot\DriverPacks"
$TemporaryFolder = "$PSScriptRoot\Temp"
$StateFile = "$PSScriptRoot\DriverPacks\DriverPackVersions.json"
$DeployRModulePath = 'C:\Program Files\2Pint Software\DeployR\Client\PSModules\DeployR.Utility'
$ExtractMSI = "$PSScriptRoot\TwoPint.DeployR.ExtractMSI.dll"
$SevenZipPath = "$PSScriptRoot\Tools\x64\7za.exe"
$InnoExtractPath = "$PSScriptRoot\Tools\x64\innoextract.exe"</code></pre>

  <h2>Running the script</h2>

  <pre><code>pwsh.exe -NoProfile -File ".\CloudDrivers-NewAndAutoUpdate-Public.ps1"</code></pre>

  <p>
    Start with a short model list. Verify the resulting Content Items, uploaded files, state JSON,
    and console summary before running it against every supported model. Fewer surprises, fewer
    emergency meetings, and considerably less interpretive dancing around the driver repository.
  </p>

  <h2>Safety and limitations</h2>

  <ul>
    <li>This is not an official 2Pint product or a replacement for official DeployR tooling or documentation.</li>
    <li><strong>DeployR Enterprise is required;</strong> Community is not supported.</li>
    <li>A valid Driver Catalog API token is required and must be kept private.</li>
    <li><strong>Only HP and Lenovo have been tested.</strong> Dell and other manufacturers remain untested.</li>
    <li>The script has only received basic testing in one environment.</li>
    <li>Package-wrapper detection is based on file metadata and known naming patterns. OEM packaging changes may require updates.</li>
    <li>An existing Content Item is expected to have exactly one active version. The script stops that model if the condition is not met.</li>
    <li>The local JSON state file is important. Deleting it causes existing items to require a new baseline refresh.</li>
    <li>Real authentication secrets must never be committed to the repository.</li>
    <li>Always review failed and unverified models in the final summary.</li>
  </ul>

  <div class="callout success">
    <strong>Status:</strong> Basic HP and Lenovo testing completed. It works in my environment, which is the traditional
    first milestone immediately before somebody discovers a driver package wrapped inside another
    driver package wearing a fake moustache.
  </div>

  <h2>🤖 A Little Help From Copilot</h2>
  <p>The script was developed and refined with assistance from Microsoft Copilot. Human testing included. AI assistance included. Unexpected driver package behavior probably included.</p>

  <h2>Disclaimer</h2>
  <p>
    Use at your own risk. Test carefully, keep backups, and confirm the resulting DeployR content
    before relying on it in production. Contributions, testing results, and improvements are welcome.
  </p>

  <p class="muted"><strong>Less clicking. More deploying. ProbablyFine™</strong></p>
