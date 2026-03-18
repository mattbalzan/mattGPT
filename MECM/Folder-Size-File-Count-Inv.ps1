<#
.SYNOPSIS
    Generates a recursive, staggered tree-view of folder sizes and file counts.

.DESCRIPTION
    This script traverses a specified directory (defaulting to SCCM inboxes) and 
    calculates the disk footprint and file count for each subfolder. It uses 
    dynamic indentation to align branch characters with the end of parent folder 
    names, creating a cascading visual hierarchy.

.PARAMETER folderPath
    The root directory to begin the inventory. 

.EXAMPLE
    Runs the inventory on the hardcoded path defined in the script.

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2026-03-18 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
    Author: Matt Balzan | mattGPT

    Thresholds:
    - Alert character ([char]9888) indicates a folder contains more than 100 files.
    - Sizes are automatically converted to the most readable unit (B, KB, MB, GB).
#>

# --------------------------------------------
# CONFIGURATION
# --------------------------------------------
$folderPath = "C:\temp"
$escChar    = "%E2%94%94%E2%94%80%E2%94%80%20"
$branchChar = [uri]::UnescapeDataString($escChar)
$alert      = [char]9888

# --------------------------------------------
# FUNCTION: GET SIZE IN UNITS (B, KB, MB, GB)
# --------------------------------------------
function Get-FriendlySize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { "{0}GB" -f [Math]::Round($Bytes / 1GB, 2) }
    elseif ($Bytes -ge 1MB) { "{0}MB" -f [Math]::Round($Bytes / 1MB, 2) }
    elseif ($Bytes -ge 1KB) { "{0}KB" -f [Math]::Round($Bytes / 1KB, 2) }
    else { "{0}B" -f $Bytes }
}

# --------------------------------------------
# FUNCTION: GET FOLDER TREE
# --------------------------------------------
function Get-FolderTree {
    param(
        [string]$Path,
        [int]$Depth = 0
    )

    $items = Get-ChildItem -Path $Path -Directory
    $results = foreach ($item in $items) {
        # --[ Create visual indent ]
        $indent = if ($Depth -gt 0) { ("      " * ($Depth - 1)) + $branchChar } else { "" }
        
        # --[ Get files in THIS specific folder ]
        $files = Get-ChildItem -Path $item.FullName -File
        $folderSize = ($files | Measure-Object -Property Length -Sum).Sum

        if($files.Count -gt 100){ $warning = "     $alert" } else{ $warning = "" }

        # --[ Output this folder ]
        [pscustomobject]@{
            'Folders + Subfolders' = "$indent$($item.Name)"
            'Folder Size'          = Get-FriendlySize -Bytes $folderSize
            'File Count'           = $files.Count
            'Threshold'            = $warning
        }

        # --[ RECURSE: Go deeper into subfolders ]
        Get-FolderTree -Path $item.FullName -Depth ($Depth + 1)
    }
    return $results
}

# --------------------------------------------
# EXECUTE FUNCTION
# --------------------------------------------
$inventory = Get-FolderTree -Path $folderPath
$inventory | Format-Table -AutoSize

# --------------------------------------------
# DISPLAY SUMMARY
# --------------------------------------------
$totalFiles = Get-ChildItem -Path $folderPath -File -Recurse
$totalSize = ($totalFiles | Measure-Object -Property Length -Sum).Sum
Write-Host "Total System Size: $(Get-FriendlySize -Bytes $totalSize)"

# --------------------------------------------
# END OF SCRIPT
# --------------------------------------------
