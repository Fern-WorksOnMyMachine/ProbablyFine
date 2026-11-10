<h1>Model Certification Check</h1>

A simple DeployR Task Sequence popup for devices that are not certified for OS deployment.
Built for DeployR task sequences using the Avalonia runtime already shipped with the DeployR client. Probably works. Definitely looks better than a MessageBox. 😎

The script itself does not perform any hardware certification or validation. Hardware certification needs to be handled separately, for example by using DeployR Task Sequence variables and conditions to determine whether a device model is approved.

When triggered, the script simply displays a clean warning popup with useful hardware information such as manufacturer, model aliases and serial number, making it slightly easier to figure out what questionable piece of hardware just showed up.

After the popup has been acknowledged, the Task Sequence can handle what happens next. For example, add a wpeutil shutdown step directly afterwards to shut down the device and prevent the deployment from continuing.

In short: certification logic outside, useful popup inside, unsupported hardware goes no further.

<img width="902" height="602" alt="image" src="https://github.com/user-attachments/assets/41726607-1c2b-49e7-a044-a28b43fce8bf" />
