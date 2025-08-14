<#
.SYNOPSIS
  Prefix JPG/JPEG filenames with their relative subfolder path (underscored),
  excluding the current/root folder name. Supports -DryRun.

.EXAMPLES
  .\prefix-subfolders-jpg.ps1 -DryRun
  .\prefix-subfolders-jpg.ps1
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

# Root = current working directory (like %cd%)
$rootPath = [System.IO.Path]::GetFullPath((Get-Location).Path)

function Get-Relative-Folder-Underscored {
    param([string]$directoryFullPath)

    $dirFull = [System.IO.Path]::GetFullPath($directoryFullPath)

    # If the file's directory is inside root, strip the root prefix
    if ($dirFull.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $dirFull.Substring($rootPath.Length).TrimStart('\','/')
    } else {
        # Fallback (different drive, etc.) — just use the full path minus drive/root
        $rel = Split-Path -Path $dirFull -NoQualifier
        $rel = $rel.TrimStart('\','/')
    }

    # Turn subpath into underscore chain, e.g. "detail\apron\XINZUO brand" -> "detail_apron_XINZUO brand"
    $underscored = ($rel -replace '[\\/]+', '_').Trim('_')
    return $underscored
}

function Resolve-NameConflict {
    param(
        [string]$Directory,
        [string]$LeafName  # target name within Directory
    )
    $candidate = Join-Path $Directory $LeafName
    if (-not (Test-Path -LiteralPath $candidate)) { return $LeafName }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($LeafName)
    $ext  = [System.IO.Path]::GetExtension($LeafName)
    $i = 1
    do {
        $newLeaf = '{0} ({1}){2}' -f $base, $i, $ext
        $candidate = Join-Path $Directory $newLeaf
        $i++
    } while (Test-Path -LiteralPath $candidate)
    return $newLeaf
}

Write-Host ("Root: {0}" -f $rootPath) -ForegroundColor Yellow
Write-Host ("Mode: {0}" -f ($(if ($DryRun) {'DRY RUN'} else {'EXECUTE'}))) -ForegroundColor Yellow
Write-Host ""

# Collect jpg/jpeg files recursively (case-insensitive)
$files = Get-ChildItem -Path $rootPath -Recurse -File -Force |
         Where-Object { $_.Extension -match '^\.(jpe?g)$' }

if (-not $files) {
    Write-Host "No JPG/JPEG files found under current directory." -ForegroundColor DarkYellow
    return
}

foreach ($f in $files) {
    $prefix = Get-Relative-Folder-Underscored -directoryFullPath $f.DirectoryName

    # If prefix exists, add it + underscore; if file is in the root, keep original name
    $targetLeaf = if ($prefix) { "${prefix}_$($f.Name)" } else { $f.Name }

    if ($targetLeaf -eq $f.Name) { continue }

    if ($DryRun) {
        Write-Host "[Would rename]" -ForegroundColor Cyan
        Write-Host (" From: {0}" -f (Join-Path $f.DirectoryName $f.Name)) -ForegroundColor DarkGray
        Write-Host ("   To: {0}" -f (Join-Path $f.DirectoryName $targetLeaf)) -ForegroundColor White
    } else {
        $finalLeaf = Resolve-NameConflict -Directory $f.DirectoryName -LeafName $targetLeaf
        try {
            Rename-Item -LiteralPath $f.FullName -NewName $finalLeaf -ErrorAction Stop
            Write-Host ("[Renamed] {0} -> {1}" -f $f.Name, $finalLeaf) -ForegroundColor Green
        } catch {
            Write-Host ("[Error] Failed to rename '{0}': {1}" -f $f.Name, $_) -ForegroundColor Red
        }
    }
}

if ($DryRun) {
    Write-Host "`nDRY RUN complete. No changes were made." -ForegroundColor Yellow
} else {
    Write-Host "`nRenaming complete." -ForegroundColor Yellow
}
