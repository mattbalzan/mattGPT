## Invoke-ServicingBaselinePreflight.ps1

Detects and repairs a damaged Windows servicing baseline (WinSxS component store) before a Feature Update, with a Windows Update repair tier for estates locked to WSUS.

### The problem it solves

Windows stores components as differential payload plus a reverse delta against a baseline. If the matching baseline directory is missing from WinSxS, the servicing stack can't reconstruct the full binary — so cumulative updates fail, and Windows Setup's migration phase fails when it tries to load components from the source OS.

Typical signatures:

**`C:\Windows\Logs\CBS\CBS.log`**
```
Hydration failed ... NTSTATUS_FROM_WIN32(774)
Component directory missing. Dir: \SystemRoot\WinSxS\amd64_microsoft-windows-...
Error 0x800f0983  (PSFX_E_MATCHING_COMPONENT_DIRECTORY_MISSING)
```

**`C:\$WINDOWS.~BT\Sources\Panther\setuperr.log`**
```
Failed to load migration plugin ... 0x8007007F
ProvMigration failed ... 0x80070003
```

### Why the Windows Update tier exists

`DISM /RestoreHealth` needs a source of replacement component payload. Two things commonly stop it finding one in a managed enterprise:

1. **WSUS doesn't host component-store repair content.** A client pointed at WSUS with `UseWUServer=1` has no reachable source for repair payload.
2. **`/LimitAccess` explicitly forbids DISM from contacting Windows Update** — so the most commonly copy-pasted repair command is also the one least likely to work on a locked-down estate.

The documented override is:

```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing
    RepairContentServerSource (DWORD) = 2
        -> download repair content from Windows Update instead of WSUS
```

Tier 1 sets that override, runs `DISM /RestoreHealth` with **no** `/Source` and **no** `/LimitAccess`, verifies the outcome, then restores every original value.

Fetching from Windows Update is often **more precise** than a staged WIM, because a WIM only contains the component versions that shipped in that media build, whereas Windows Update can supply the exact version the servicing stack is asking for.

> **Useful diagnostic signal:** if devices with direct internet access to Windows Update succeed while WSUS-managed devices fail with identical hardware and image, suspect the update-source policy — not the image.

### Repair tiers

| Tier | Source | Notes |
|---|---|---|
| 1 | Windows Update | Default. Disable with `-SkipWindowsUpdate` |
| 2 | Staged `install.wim` / `install.esd` | Fallback, or primary if Tier 1 is off |
| 3 | Neither worked | Sets `CanUpgrade=False` — escalate to in-place repair upgrade or reimage |

Both tiers go through the same verification: are the named component directories back, **and** does `DISM /CheckHealth` report clean? A device only passes if both are true.

### Usage

**Detection only — safe to run estate-wide, makes no changes:**
```powershell
.\Invoke-ServicingBaselinePreflight.ps1 -SkipRepair -Verbose
```

**Single device — try Windows Update, fall back to mounted ISO:**
```powershell
.\Invoke-ServicingBaselinePreflight.ps1 -SourcePath D:\ -Verbose
```

**Air-gapped or endpoint-blocked site — staged media only:**
```powershell
.\Invoke-ServicingBaselinePreflight.ps1 -SkipWindowsUpdate -SourcePath \\server\share\media
```

**Target a component named in your own CBS log:**
```powershell
.\Invoke-ServicingBaselinePreflight.ps1 -ComponentPattern 'amd64_microsoft-windows-servicingstack*'
```

**Inside a ConfigMgr task sequence:**
```powershell
.\Invoke-ServicingBaselinePreflight.ps1 -SourceVariable RepairSrc01 -SuspendBitLocker
```

Add a **Download Package Content** step before it, with *Save path as a variable* set to `RepairSrc` — ConfigMgr creates `RepairSrc01`. Gate your Upgrade OS step on `PFCanUpgrade equals True`.

**Intune detection output — clean JSON on STDOUT for a Proactive Remediation detection script:**
```powershell
.\Invoke-ServicingBaselinePreflight.ps1 -IntuneDetection -SkipRepair
```

`-IntuneDetection` suppresses all host output and emits a single flat JSON object — `{ "CanUpgrade": <Boolean> }` — then maps the readiness gate to the Intune exit-code convention: `0` when `CanUpgrade` is `True` (compliant), `1` when `False` (remediate). Use it as an Intune Proactive Remediation detection script, a Win32 app detection source, or a Custom Compliance input.

### Key parameters

| Parameter | Default | Purpose |
|---|---|---|
| `-SourcePath` | — | Folder containing `\sources\install.wim` for Tier 2 |
| `-SourceVariable` | `RepairSrc01` | TS variable holding the staged media path |
| `-SkipWindowsUpdate` | off | Disable Tier 1 entirely |
| `-WindowsUpdateTimeoutMinutes` | `45` | Abort Tier 1 and fall through to Tier 2 |
| `-RestoreUpdatePolicy` | `$true` | Restore original policy after the repair attempt |
| `-ComponentPattern` | 3 common components | WinSxS patterns to test for presence |
| `-MinimumFreeSpaceGB` | `25` | Abort before repairing below this threshold |
| `-SkipRepair` | off | Detection only |
| `-RemoveBlockingDrivers` | off | Remove `BlockMigration=True` and unsigned `oem*.inf` |
| `-SuspendBitLocker` | off | Suspend for 3 reboots when a PIN protector is present |
| `-IntuneDetection` | off | Emit clean `{ "CanUpgrade": <Boolean> }` JSON on STDOUT and exit `0`/`1` for Intune |

### Output

Writes CSV and JSON to `$LogPath` (defaults to `C:\Windows\Temp`, or the TS log folder inside a task sequence), plus a human-readable `ServicingPreflight.log`. Full DISM output lands in `dism-wu.log` / `dism-wim.log` alongside it.

With `-IntuneDetection`, all host output is suppressed and a single compact JSON object is written to STDOUT for the Intune agent to parse:

```json
{ "CanUpgrade": true }
```

Standalone exit codes are overridden to the Intune convention in this mode: `0` = compliant (`CanUpgrade` True), `1` = remediate (`CanUpgrade` False).

**Task sequence variables:**

| Variable | Values |
|---|---|
| `PFCanUpgrade` | `True` / `False` — gate your Upgrade OS step on this |
| `PFRepairTier` | `WindowsUpdate` / `StagedWIM` / `Both` / `None` |
| `PFRepairResult` | `Verified` / `Incomplete` / `NotAttempted` / `SourceMissing` / `InsufficientSpace` |
| `PFWuRepairResult` | `Success` / `Failed` / `Blocked` / `Skipped` / `TimedOut` |
| `PFBucket` | `A` (baseline damaged) / `B` (migration failure) / `Z` (no known defect) |
| `PFDefectFound`, `PFRepairAttempted`, `PFDetail` | Classification and free-text diagnostics |

**Exit codes** (standalone only — always `0` inside a task sequence, so the script never fails your deployment):

| Code | Meaning |
|---|---|
| `0` | Healthy, or repair verified |
| `1` | Defect detected, detection-only mode |
| `2` | Repair attempted but verification failed |
| `3` | No usable repair source |
| `20` | Not elevated |

---

### ⚠️ Read before running

**Tier 1 temporarily modifies Windows Update policy.** It sets `RepairContentServerSource=2` and relaxes `UseWUServer`, `DisableWindowsUpdateAccess` and `DoNotConnectToWindowsUpdateInternetLocations` for the duration of the repair.

The script backs up every value it touches, restores them in the exit path even on early failure, and triggers `gpupdate /force` afterwards. But you should still understand what it does before running it:

- **In regulated or air-gapped environments, use `-SkipWindowsUpdate`.** Relaxing update-source policy may breach your change control or security baseline, even briefly. Read `Set-RepairPolicy` and `Restore-RepairPolicy` in the script first.
- **The relaxation is scoped to component repair**, not general Windows Update behaviour — but it does allow the device to reach Microsoft endpoints for the duration.
- **If the machine loses power mid-repair**, policy may be left relaxed. Re-running the script or a `gpupdate /force` will correct it, and GPO/Intune will reassert on the next policy cycle.
- **Test on a single device first.** Always.

**Other things to know:**

- Requires **elevation**. SYSTEM is fine.
- `DISM /RestoreHealth` can take **20–60 minutes**. This is why it belongs in a task sequence or Win32 app rather than an Intune remediation script, which has a much shorter execution window.
- `-RemoveBlockingDrivers` **uninstalls driver packages**. It's off by default for good reason — run once without it, review what it reports, then enable.
- Driver detection reads `CompatData*.xml`, which only exists after an upgrade attempt has run. On a device that's never attempted the upgrade, that check returns nothing — that's expected, not a false negative.
- **Staged media must be at or above the target OS patch level.** Per Microsoft's guidance on configuring a repair source: if the target OS is patched higher than the source, repair may fail because the target needs files the source doesn't have. Refresh your staged media every patch cycle.

### Requirements

- PowerShell 5.1+
- Windows 10 / 11
- Elevated
- No external modules

### Licence

MIT. This sample script is not supported under any Microsoft standard support program or service, and is provided AS IS without warranty of any kind. Test before production use.
