
<h1>DeployR Boot Menu<br></h1>
One menu. Many variables.<br>

<img width="998" height="740" alt="image" src="https://github.com/user-attachments/assets/e9c3d072-dce7-4291-ab38-9bce0960552a" />
<img width="1000" height="738" alt="image" src="https://github.com/user-attachments/assets/68145e04-f4e9-46ae-bec9-e09d78904315" />
<img width="961" height="700" alt="image" src="https://github.com/user-attachments/assets/90e6e1a5-576c-4c84-bba0-6177f0955051" />

<p>
A modern, Avalonia-based boot menu for
<strong>2Pint DeployR</strong>, designed to provide a clean
and user-friendly experience during operating system deployment.
</p>

<p>
DeployR BootMenu provides a customizable graphical interface
for deployment-related selections and actions, replacing
traditional PowerShell and Windows Forms-style dialogs
with a modern Windows-inspired design.
</p>

<hr>

<h2>Overview</h2>

<p>
The goal of this project is simple:
make the deployment experience cleaner, more intuitive,
and a little more enjoyable for technicians.
</p>

<p>
The interface is designed for use in
<strong>DeployR task sequences and WinPE</strong>,
with an emphasis on readability, simplicity,
and reliable interaction.
</p>

<hr>

<h2>Features</h2>

<ul>
    <li>Modern Avalonia-based graphical interface.</li>
    <li>Clean, dark-themed design.</li>
    <li>Designed for deployment workflows in DeployR.</li>
    <li>Suitable for WinPE environments.</li>
    <li>Clear and accessible deployment controls.</li>
    <li>Consistent visual styling.</li>
    <li>PowerShell-based implementation.</li>
</ul>

<hr>

<h2>Requirements</h2>

<ul>
    <li>2Pint DeployR.</li>
    <li>PowerShell 7.</li>
    <li>Avalonia runtime dependencies available in the environment.</li>
    <li>A compatible DeployR WinPE boot image.</li>
</ul>

<p>
<strong>Note:</strong>
Avalonia runtime setup and local offline testing
are documented separately.
</p>

<hr>

<h2>Using BootMenu in DeployR</h2>

<p>
DeployR BootMenu is intended to run as part of
a DeployR deployment workflow.
</p>

<p>
Add the BootMenu PowerShell script to a DeployR
content item and reference it from the appropriate
task sequence step.
</p>

<p>
When executed, BootMenu displays its graphical interface
and allows the technician to interact with the available
deployment options.
</p>

<p>
The exact task sequence configuration depends on
how BootMenu is integrated into your deployment workflow.
</p>

<hr>

<h2>Design Philosophy</h2>

<p>
BootMenu focuses on three principles:
</p>

<ul>
    <li>
        <strong>Simple:</strong>
        Keep the interface clean and avoid unnecessary complexity.
    </li>
    <li>
        <strong>Modern:</strong>
        Use a consistent visual design with clear typography,
        balanced spacing, and intuitive controls.
    </li>
    <li>
        <strong>Practical:</strong>
        Prioritize features that are genuinely useful
        during operating system deployment.
    </li>
</ul>

<hr>

<h2>WinPE Compatibility</h2>

<p>
BootMenu is designed with DeployR WinPE execution in mind.
</p>

<p>
When using Avalonia-based interfaces in WinPE,
runtime dependencies, process isolation, and access
to the deployment environment must be handled correctly.
</p>

<p>
Always validate BootMenu in your actual DeployR
WinPE environment before using it in production.
</p>

<hr>

<h2>Important Notes</h2>

<ul>
    <li>
        This project is intended for DeployR deployment environments.
    </li>
    <li>
        Ensure the required Avalonia dependencies are available.
    </li>
    <li>
        Test the interface at different screen resolutions.
    </li>
    <li>
        Verify all deployment actions before production use.
    </li>
    <li>
        Refer to the separate Avalonia offline testing guide
        for local development and troubleshooting.
    </li>
</ul>

<hr>

<h2>Final Words</h2>

<p>
Operating system deployment does not have to look like 2005.
</p>

<p>
DeployR BootMenu brings a modern interface to the
deployment process while keeping the focus on
practical functionality and usability.
</p>

<p>
<strong>Less clicking. More deploying. ProbablyFine&trade;</strong>
</p>
