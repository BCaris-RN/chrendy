param(
    [string]$RootDir = ".",
    [int]$SpikeStaleHours = 48,
    [switch]$FailOnStaleSpike
)

function Get-RelativeDisplayPath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $base = $BasePath.TrimEnd('\', '/')
    if ($TargetPath.ToLowerInvariant().StartsWith($base.ToLowerInvariant())) {
        return $TargetPath.Substring($base.Length).TrimStart('\', '/').Replace('\', '/')
    }

    return $TargetPath.Replace('\', '/')
}

$resolvedRoot = Resolve-Path -LiteralPath $RootDir -ErrorAction SilentlyContinue
if (-not $resolvedRoot) {
    Write-Error "Root directory '$RootDir' was not found."
    exit 2
}

if (-not $PSBoundParameters.ContainsKey('SpikeStaleHours') -and $env:CARIS_SPIKE_STALE_HOURS) {
    $parsedHours = 0
    if ([int]::TryParse($env:CARIS_SPIKE_STALE_HOURS, [ref]$parsedHours) -and $parsedHours -gt 0) {
        $SpikeStaleHours = $parsedHours
    }
}

$rg = Get-Command rg -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Error "ripgrep (rg) is required for exclusion checks."
    exit 2
}

$pattern = 'legacy_api_folder|deprecated_utils'

$args = @(
    '--line-number',
    '--with-filename',
    '--color', 'never',
    '--glob', '*.dart',
    '--glob', '*.js',
    '--glob', '*.jsx',
    '--glob', '*.ts',
    '--glob', '*.tsx',
    '--glob', '*.py',
    '--glob', '*.go',
    '--glob', '*.rs',
    '--glob', '*.java',
    '--glob', '*.kt',
    '--glob', '*.swift',
    '--glob', '*.yml',
    '--glob', '*.yaml',
    '--glob', '!**/node_modules/**',
    '--glob', '!**/.git/**',
    '--glob', '!**/dist/**',
    '--glob', '!**/build/**',
    '--glob', '!**/.next/**',
    '--glob', '!**/coverage/**',
    '--glob', '!**/templates/guardrails/**',
    '--glob', '!**/experimental/**',
    '--glob', '!experimental/**',
    '--glob', '!**/*.proto.*',
    '--glob', '!**/*.md',
    '-e', $pattern,
    $resolvedRoot.Path
)

$results = & rg @args
$scanExitCode = $LASTEXITCODE
if ($scanExitCode -gt 1) {
    Write-Error "Exclusion scan failed with exit code $scanExitCode."
    exit $scanExitCode
}

$rootPath = $resolvedRoot.Path.TrimEnd('\', '/')
$now = Get-Date
$staleSpikeArtifacts = @()
$allFiles = Get-ChildItem -Path $rootPath -Recurse -File -Force -ErrorAction SilentlyContinue

foreach ($file in $allFiles) {
    $full = $file.FullName
    if (
        $full -match '[\\/]\.git([\\/]|$)' -or
        $full -match '[\\/]node_modules([\\/]|$)' -or
        $full -match '[\\/]dist([\\/]|$)' -or
        $full -match '[\\/]build([\\/]|$)' -or
        $full -match '[\\/]\.next([\\/]|$)' -or
        $full -match '[\\/]coverage([\\/]|$)' -or
        $full -match '[\\/]templates[\\/]guardrails([\\/]|$)'
    ) {
        continue
    }

    $isExperimental = $full -match '(^|[\\/])experimental([\\/]|$)'
    $isProto = $file.Name -match '\.proto\.[^\\/\.]+$'
    if (-not ($isExperimental -or $isProto)) {
        continue
    }

    $ageHours = ($now - $file.LastWriteTime).TotalHours
    if ($ageHours -lt $SpikeStaleHours) {
        continue
    }

    $staleSpikeArtifacts += [PSCustomObject]@{
        Path = Get-RelativeDisplayPath -BasePath $rootPath -TargetPath $full
        AgeHours = [int][Math]::Floor($ageHours)
        LastWriteTime = $file.LastWriteTime
    }
}

$hasViolation = ($scanExitCode -eq 0 -and $results)
if ($hasViolation) {
    Write-Error "Exclusion zone violation detected. Remove deprecated imports/references before commit or merge."
    $results | ForEach-Object { Write-Host $_ }
}

$failOnStale = $FailOnStaleSpike.IsPresent -or ($env:CARIS_FAIL_ON_STALE_SPIKES -eq '1')
if ($staleSpikeArtifacts.Count -gt 0) {
    Write-Warning "Spike Protocol staleness detected ($($staleSpikeArtifacts.Count) file(s) older than $SpikeStaleHours hours)."
    Write-Host "[WARN] Spike artifacts are temporary. Refactor or delete stale prototypes before they become shadow code."
    Write-Host "[WARN] Suggested next step: extract core logic, write failing tests, migrate to production path, then delete spike."

    foreach ($artifact in ($staleSpikeArtifacts | Sort-Object AgeHours -Descending)) {
        Write-Host ("[WARN] {0} (age: {1}h, last touch: {2})" -f $artifact.Path, $artifact.AgeHours, $artifact.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"))
    }
}

if ($hasViolation) {
    exit 1
}

if ($staleSpikeArtifacts.Count -gt 0 -and $failOnStale) {
    Write-Error "Stale Spike Protocol artifacts found and fail mode is enabled (CARIS_FAIL_ON_STALE_SPIKES=1 or -FailOnStaleSpike)."
    exit 1
}

Write-Host '[OK] No exclusion zone violations detected.'
if ($staleSpikeArtifacts.Count -eq 0) {
    Write-Host ("[OK] No stale Spike Protocol artifacts older than {0} hours detected." -f $SpikeStaleHours)
}
exit 0
