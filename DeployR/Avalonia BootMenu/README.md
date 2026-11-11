
<h1>DeployR Boot Menu<br></h1>
One menu. Many variables.<br>

<img width="998" height="740" alt="image" src="https://github.com/user-attachments/assets/e9c3d072-dce7-4291-ab38-9bce0960552a" />
<img width="1000" height="738" alt="image" src="https://github.com/user-attachments/assets/68145e04-f4e9-46ae-bec9-e09d78904315" />
<img width="961" height="700" alt="image" src="https://github.com/user-attachments/assets/90e6e1a5-576c-4c84-bba0-6177f0955051" />

<p>
A configurable PowerShell boot menu for <strong>DeployR</strong> that provides
a simple graphical interface for selecting a customer and deployment role
before starting a Task Sequence.
</p>

<p>
The Boot Menu does not install applications, configure Windows, apply policies,
or perform the deployment itself.
</p>

<p>
It has exactly one job:<br>
<strong>Set Task Sequence variables.</strong>
</p>

<p>
What happens with those variables afterward is entirely up to your Task Sequence.
</p>

<h3>🤔 Why?</h3>

<p>
A single Task Sequence can quickly turn into a maze of conditions,
customer-specific branches, operating systems, application sets,
Autopilot profiles, and nested Task Sequences.
</p>

<p>
Instead of creating a separate deployment workflow for every possible
combination, the Boot Menu acts as a simple selection layer.
</p>

<pre>
Customer 1
├── Role 1
└── Role 2

Customer 2
├── Role 1
└── Role 2
</pre>

<p>
Each selection can populate any number of <code>TSEnv</code> variables.
</p>

<p>Your Task Sequence can then use those variables to decide:</p>

<ul>
  <li>Which operating system to deploy</li>
  <li>Which applications to install</li>
  <li>Which configuration to apply</li>
  <li>Which customer-specific logic to execute</li>
  <li>Which sub Task Sequence to run</li>
  <li>Or pretty much anything else controlled by a Task Sequence condition</li>
</ul>

<p>
One particularly useful scenario is using the selected deployment role
to branch into different sub Task Sequences for different customers
or deployment scenarios.
</p>

<p>
One main deployment workflow can therefore serve as the entry point
for many different deployment paths.
</p>

<p>
<strong>One Boot Menu. Multiple deployment paths. Less Task Sequence spaghetti.</strong> 🍝
</p>

<h3>⚙️ How It Works</h3>

<p>The project consists of three files:</p>

<h4>📄 BootMenu.ps1</h4>

<p>The main entry point.</p>

<p>It:</p>

<ul>
  <li>Loads the DeployR utility module</li>
  <li>Loads the configuration</li>
  <li>Loads the GUI</li>
  <li>Builds the available customer and role selections</li>
  <li>Resolves the selected deployment role</li>
  <li>Sets the configured <code>TSEnv</code> variables</li>
  <li>Supports different variables for physical devices and virtual machines</li>
</ul>

<h4>🖥️ BootMenu.Gui.ps1</h4>

<p>Contains the Windows Forms interface.</p>

<p>It handles:</p>

<ul>
  <li>Customer selection</li>
  <li>Deployment role selection</li>
  <li>Role information</li>
  <li>Computer information</li>
  <li>Deployment confirmation</li>
  <li>Keyboard navigation</li>
  <li>Optional password-protected roles</li>
</ul>

<p>
The GUI itself does not decide what gets deployed.
It simply presents the choices defined in the configuration
and passes the selected role back to the main Boot Menu logic.
</p>

<p>
<strong>The Boot Menu makes the selection. Your Task Sequence does the heavy lifting.</strong>
</p>

<h4>🔧 BootMenu.Config.psd1</h4>

<p>This is where you define your environment.</p>

<p>
Customers, deployment roles, variables, descriptions,
and optional password protection are all configured here.
</p>

<p>
Role 2 is included as an example of a password-protected deployment role.
</p>

<p>
<strong>Default example password:</strong> <code>Password</code> 🤗
</p>

<p>
Yes, very secure. Please change it before using it in production.
</p>

<h3>🚀 Running BootMenu</h3>

<p>
Run <code>BootMenu.ps1</code> from a DeployR Task Sequence.
</p>

<p><strong>Fullscreen mode (default):</strong></p>

<pre><code>.\BootMenu.ps1</code></pre>

<p>
The menu launches fullscreen by default,
because fullscreen is obviously more awesome.
</p>

<p><strong>Windowed mode:</strong></p>

<pre><code>.\BootMenu.ps1 -Windowed</code></pre>

<p>
<strong>That's it.</strong> Select a customer, choose a role,
set some variables, and let DeployR take care of the rest.
</p>

<p>
<em>Simple by design. Deployment complexity sold separately.</em> 😎
</p>

<p>
<strong>Less clicking. More deploying. ProbablyFine&trade;</strong>
</p>
