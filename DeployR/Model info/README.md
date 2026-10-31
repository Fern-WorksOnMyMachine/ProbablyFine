Model Certification Check

A simple DeployR Task Sequence popup for devices that are not certified for OS deployment.

The script itself does not perform any hardware certification or validation. Hardware certification needs to be handled separately, for example by using DeployR Task Sequence variables and conditions to determine whether a device model is approved.

When triggered, the script simply displays a clean warning popup with useful hardware information such as manufacturer, model aliases and serial number, making it slightly easier to figure out what questionable piece of hardware just showed up.

After the popup has been acknowledged, the Task Sequence can handle what happens next. For example, add a wpeutil shutdown step directly afterwards to shut down the device and prevent the deployment from continuing.

In short: certification logic outside, useful popup inside, unsupported hardware goes no further.

<img width="917" height="605" alt="image" src="https://github.com/user-attachments/assets/419b9978-6e09-4c2b-9aff-22042a2bc152" />

