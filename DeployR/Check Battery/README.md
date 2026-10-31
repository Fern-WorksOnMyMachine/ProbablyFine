A lightweight battery check popup for deployments.

If the laptop is running on battery power, the deployment pauses until the power adapter is connected. Once external power is detected, the popup automatically closes and the deployment continues.

It can also be closed manually, because sometimes rules are just suggestions.

Add the script as a step in your DeployR Task Sequence and use DeployR's built-in IsOnBattery variable as a condition:
IsOnBattery  Equals  True

<img width="452" height="311" alt="image" src="https://github.com/user-attachments/assets/73cbcf48-a128-4cd5-9582-804148cecc46" />

This ensures the step only runs when the device is actually running on battery power. If external power is already connected, the step is simply skipped.


<img width="797" height="381" alt="image" src="https://github.com/user-attachments/assets/c4c4eec5-d2c8-4fdc-ba61-37bf728872a6" />
