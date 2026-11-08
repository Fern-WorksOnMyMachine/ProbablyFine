
<h1>DeployR Boot Menu<br></h1>
One menu. Many variables.<br>

<img width="998" height="740" alt="image" src="https://github.com/user-attachments/assets/e9c3d072-dce7-4291-ab38-9bce0960552a" />
<img width="1000" height="738" alt="image" src="https://github.com/user-attachments/assets/68145e04-f4e9-46ae-bec9-e09d78904315" />
<img width="961" height="700" alt="image" src="https://github.com/user-attachments/assets/90e6e1a5-576c-4c84-bba0-6177f0955051" />



A configurable PowerShell boot menu for DeployR that provides a simple graphical front end for selecting a customer and deployment role before starting a Task Sequence.
The Boot Menu does not install applications, configure Windows, apply policies, or perform the deployment itself.<br>
It has one job:<br>
Set Task Sequence variables.<br>
What you do with those variables afterwards is entirely up to your Task Sequence.

Why?<br>
A single Task Sequence can quickly turn into a collection of conditions, customer-specific branches, operating systems, application sets, Autopilot profiles and nested Task Sequences.
Instead of creating a separate deployment workflow for every possible combination, the Boot Menu can act as the selection layer.

Customer 1<br>
└── Role 1

Customer 1<br>
└── Role 2

Customer 2<br>
└── Role 1

Customer 2<br>
└── Role 2

Each selection can populate any number of TSEnv variables.<br>
Your Task Sequence can then use those variables to decide:<br>
Which operating system to deploy<br>
Which applications to install<br>
Which configuration to apply<br>
Which customer-specific logic to execute<br>
Which sub Task Sequence to run<br>
Or pretty much anything else that can be controlled by a Task Sequence condition<br>

The particularly useful part is using the selected role to branch into different sub Task Sequences for different customers or deployment scenarios.<br>
One main deployment workflow can therefore act as the entrance to many different deployment paths.<br>

How it works<br>
The project consists of three files:

<strong><big>BootMenu.ps1</big></strong><br>
The main entry point.<br>
It:<br>
Loads the DeployR utility module<br>
Loads the configuration<br>
Loads the GUI<br>
Builds the available customer and role selections<br>
Resolves the selected role<br>
Sets the configured TSEnv variables<br>
Supports different variables for physical devices and virtual machines

<strong><big>BootMenu.Gui.ps1</big></strong><br>
Contains the Windows Forms interface.<br>
It handles:<br>
Customer selection<br>
Deployment role selection<br>
Role information<br>
Computer information<br>
Deployment confirmation<br>
Keyboard navigation<br>
Optional password-protected roles<br>
The GUI itself does not decide what gets deployed. It simply presents the choices defined in the configuration and passes the selected role back to the main Boot Menu logic.

<strong><big>BootMenu.Config.psd1</big></strong><br>
This is where you define your environment.<br>
Customers, roles, variables, descriptions and optional password protection are all defined here.<br>
Role 2 is included as an example of a password-protected deployment role.<br>
Default Password is Password 🤗<br>

<strong>BootMenu</strong><br>
Run from a DeployR Task Sequence using <code>BootMenu.ps1</code>. The menu launches fullscreen by default, because fullscreen is obviously more awesome. If you prefer a regular window, launch it with <code>BootMenu.ps1 -Windowed</code>.
