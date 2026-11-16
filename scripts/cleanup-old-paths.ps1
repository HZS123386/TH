$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$desktop = Split-Path -Parent $repository
$names = @('TH', 'western-astrology-h5 4', 'TH-H-publish-20261109')
$blocked = 0
foreach ($name in $names) {
    $candidate = [IO.Path]::GetFullPath((Join-Path $desktop $name))
    if (!(Test-Path -LiteralPath $candidate)) { continue }
    if ((Split-Path -Parent $candidate) -ne $desktop -or $candidate -eq $repository) {
        throw 'Unexpected old project path'
    }
    $item = Get-Item -LiteralPath $candidate -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Leave linked directories unchanged'
    }
    $contents = @(Get-ChildItem -LiteralPath $candidate -Force)
    $marker = Join-Path $candidate 'AGENTS.md'
    if ($contents.Count -ne 1 -or $contents[0].Name -ne 'AGENTS.md' -or $contents[0].PSIsContainer) {
        Write-Warning "Preserved a nonempty old directory: $candidate"
        $blocked++
        continue
    }
    $notice = Get-Content -LiteralPath $marker -Raw -Encoding utf8
    if (!$notice.Contains(($repository -replace '\\', '/'))) {
        throw 'Unrecognized migration notice; leave it unchanged'
    }
    # These directories contain only our notice; never recursively remove a project.
    Remove-Item -LiteralPath $marker
    try {
        Remove-Item -LiteralPath $candidate -ErrorAction Stop
        Write-Output "Removed old empty path: $candidate"
    } catch {
        if (Test-Path -LiteralPath $candidate) {
            if (!(Test-Path -LiteralPath $marker)) {
                Set-Content -LiteralPath $marker -Value $notice -Encoding utf8
            }
        }
        Write-Warning "Still in use by an old session: $candidate"
        $blocked++
    }
}
if ($blocked) { exit 1 }
