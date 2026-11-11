<img width="968" height="478" alt="image" src="https://github.com/user-attachments/assets/9d3225a5-6647-49e0-9283-e69860006ccb" />

A lightweight battery check popup for deployments.
Built for DeployR task sequences using the Avalonia runtime already shipped with the DeployR client. Probably works. Definitely looks better than a MessageBox. 😎

If the laptop is running on battery power, the deployment pauses until the power adapter is connected. Once external power is detected, the popup automatically closes and the deployment continues.

It can also be closed manually, because sometimes rules are just suggestions.

Add the script as a step in your DeployR Task Sequence and use DeployR's built-in IsOnBattery variable as a condition:
IsOnBattery  Equals  True

<img width="452" height="311" alt="image" src="https://github.com/user-attachments/assets/73cbcf48-a128-4cd5-9582-804148cecc46" />

This ensures the step only runs when the device is actually running on battery power. If external power is already connected, the step is simply skipped.

<p>
<strong>Less clicking. More deploying. ProbablyFine&trade;</strong>
</p>

