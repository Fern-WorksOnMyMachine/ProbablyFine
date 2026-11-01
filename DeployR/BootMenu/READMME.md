

DeployR Boot Menu
One menu. Many variables.

A configurable PowerShell boot menu for DeployR that provides a simple graphical front end for selecting a customer and deployment role before starting a Task Sequence.
The Boot Menu does not install applications, configure Windows, apply policies, or perform the deployment itself.
It has one job:
Set Task Sequence variables.
What you do with those variables afterwards is entirely up to your Task Sequence.

Why?
A single Task Sequence can quickly turn into a collection of conditions, customer-specific branches, operating systems, application sets, Autopilot profiles and nested Task Sequences.
Instead of creating a separate deployment workflow for every possible combination, the Boot Menu can act as the selection layer.

Customer 1
└── Role 1

Customer 1
└── Role 2

Customer 2
└── Role 1

Customer 2
└── Role 2

Each selection can populate any number of TSEnv variables.
Your Task Sequence can then use those variables to decide:
Which operating system to deploy
Which applications to install
Which configuration to apply
Which customer-specific logic to execute
Which sub Task Sequence to run
Or pretty much anything else that can be controlled by a Task Sequence condition

The particularly useful part is using the selected role to branch into different sub Task Sequences for different customers or deployment scenarios.
One main deployment workflow can therefore act as the entrance to many different deployment paths.

How it works
The project consists of three files:

BootMenu.ps1
The main entry point.
It:
Loads the DeployR utility module
Loads the configuration
Loads the GUI
Builds the available customer and role selections
Resolves the selected role
Sets the configured TSEnv variables
Supports different variables for physical devices and virtual machines

BootMenu.Gui.ps1
Contains the Windows Forms interface.
It handles:
Customer selection
Deployment role selection
Role information
Computer information
Deployment confirmation
Keyboard navigation
Optional password-protected roles
The GUI itself does not decide what gets deployed. It simply presents the choices defined in the configuration and passes the selected role back to the main Boot Menu logic.

BootMenu.Config.psd1
This is where you define your environment.
Customers, roles, variables, descriptions and optional password protection are all defined here.
Role 2 is included as an example of a password-protected deployment role.
Default Password is Password 🤗
