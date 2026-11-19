# 🚨 DeployR OSD Failure Monitor

> **DeployR 1.4 migration note** | Scheduled Task action update

The DeployR OSD Failure Monitor watches the `TwoPintSoftware-DeployR-Audit/Operational` Windows event log for **Event ID 17004** (failed task sequence) and sends an alert to Microsoft Teams using `D:\Monitoring\teams-osd-error.ps1`.

## ⚠️ Action required after upgrading to DeployR 1.4

In our setup, the scheduled task stopped sending automatic notifications. During troubleshooting, a manual run failed with exit code `1` when the action included an event-record argument. Removing that argument allowed the script to send a Teams notification successfully.

**Previous arguments:**

```powershell
-NoProfile -ExecutionPolicy Bypass -File "D:\Monitoring\teams-osd-error.ps1" -EventRecordId "$(EventRecordID)"
```

**Updated arguments:**

```powershell
-NoProfile -ExecutionPolicy Bypass -File "D:\Monitoring\teams-osd-error.ps1"
```

> [!IMPORTANT]
> This is a **tested workaround for our monitor script**, not a confirmed DeployR 1.4 breaking change. The script can look up the latest relevant event itself. Removing the parameter fixed a **manual execution** test; automatic event-trigger behavior still needs to be verified with a **new** Event ID 17004.

## 🛠️ Update an existing scheduled task

1. Open **Task Scheduler**.
2. Find **DeployR - OSD Failure Monitor**.
3. Open **Properties → Actions → Edit**.
4. Keep the executable as `C:\Program Files\PowerShell\7\pwsh.exe`.
5. Replace **Add arguments** with the updated arguments above.
6. Save the task.

Alternatively, run the updated installer script `Install-DeployR-OSDFailureMonitor.ps1` as administrator. It replaces the task with the same event filter and updated action.

## ✅ Validation

- Confirm the script exists at `D:\Monitoring\teams-osd-error.ps1`.
- Test a manual run only if sending a Teams notification is acceptable.
- Confirm a Teams alert arrives and contains the expected Event ID and record details.
- Enable `Microsoft-Windows-TaskScheduler/Operational` logging if needed for diagnosis.
- Confirm that a **new** Event ID `17004` triggers the scheduled task automatically. A successful manual run alone does not prove the event subscription works.

## ℹ️ Notes

- The task subscribes to **new** matching events; it does not replay old failures.
- The task does not delete or modify Windows Event Log entries.
- Removing the record ID parameter means the script chooses which event to report. If several failures occur close together, check that the script handles this as intended.
- The installer uses PowerShell 7 and runs the task as `SYSTEM`.

---

*Less clicking. More deploying. ProbablyFine™*
