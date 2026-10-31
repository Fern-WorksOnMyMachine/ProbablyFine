DeployR Application Forge

DeployR Application Forge is a lightweight PowerShell 7 GUI for creating and updating application content in DeployR in a simple and consistent way.<br>
Fill in the application details, point it at your source folder and let the Forge do the repetitive work.

✨ What it does<br>
The Forge provides a simple interface for entering:<br>
Application name<br>
Application name and version<br>
Installation command<br>
Source folder<br>

When you hit:<br>
SEND IT TO DEPLOYR<br>
The script connects to DeployR and checks whether the application already exists.<br>

New application<br>
If the application does not exist, the Forge:<br>
Creates a new DeployR Application Content Item<br>
Uploads the selected source folder<br>
Creates an active content version<br>
Sets the version description<br>
Sets the installation command line<br>
Pretends this was always the plan<br>
Existing application<br>

If an application with the same name already exists, the Forge stops and asks before doing anything destructive.<br>
You can either:<br>
NOPE, NOT RISKING IT<br>
or:<br>
HELL YEAH, OVERWRITE IT!<br>
If overwrite is confirmed, the existing Version 1 content is replaced with the files from the selected source folder.<br>
Because blindly overwriting production content seemed slightly too exciting.

🚀 Requirements<br>
PowerShell 7 or later<br>
DeployR.Utility PowerShell module<br>
Access to your DeployR environment<br>
A valid DeployR passcode<br>
Enough confidence to click SEND IT TO DEPLOYR<br>

<img width="957" height="842" alt="image" src="https://github.com/user-attachments/assets/99ec2710-d12c-45fd-bc39-f53a63754db6" />
