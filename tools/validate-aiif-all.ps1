param(
    [Parameter(Mandatory = $true)]
    [string]$Aiif,

    [string]$Checklist = "AIIF-Conformance-Checklist.json",

    [switch]$StrictShould,

    [switch]$RequireAll
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonValidator = Join-Path $scriptRoot "validate-aiif.py"
$pwshValidator = Join-Path $scriptRoot "validate-aiif.ps1"
$bashValidator = Join-Path $scriptRoot "validate-aiif.sh"

if (-not (Test-Path -Path $Aiif)) {
    Write-Error "AIIF file not found: $Aiif"
    exit 2
}

if (-not (Test-Path -Path $Checklist)) {
    Write-Error "Checklist file not found: $Checklist"
    exit 2
}

$results = @()

function Add-Result {
    param(
        [string]$Validator,
        [string]$Status,
        [int]$Code,
        [string]$Detail
    )
    $script:results += [PSCustomObject]@{
        validator = $Validator
        status    = $Status
        exit_code = $Code
        detail    = $Detail
    }
}

function Find-Python {
    foreach ($candidate in @("python", "py", "python3")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            return $candidate
        }
    }
    return $null
}

function Test-BashRunnable {
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bashCmd) {
        return $false
    }

    try {
        & bash --version *> $null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

Write-Output "Running AIIF validators against: $Aiif"
Write-Output ("=" * 72)

# 1) Python validator
if (-not (Test-Path -Path $pythonValidator)) {
    Add-Result -Validator "python" -Status "SKIP" -Code 2 -Detail "validator file missing"
}
else {
    $pythonCmd = Find-Python
    if (-not $pythonCmd) {
        Add-Result -Validator "python" -Status "SKIP" -Code 2 -Detail "python executable not available"
    }
    else {
        $pyParams = @($pythonValidator, "--aiif", $Aiif, "--checklist", $Checklist)
        if ($StrictShould) {
            $pyParams += "--strict-should"
        }

        & $pythonCmd @pyParams
        $pyCode = $LASTEXITCODE
        if ($pyCode -eq 0) {
            Add-Result -Validator "python" -Status "PASS" -Code $pyCode -Detail "validator succeeded"
        }
        else {
            Add-Result -Validator "python" -Status "FAIL" -Code $pyCode -Detail "validator reported non-compliance or error"
        }
    }
}

# 2) PowerShell validator
if (-not (Test-Path -Path $pwshValidator)) {
    Add-Result -Validator "powershell" -Status "SKIP" -Code 2 -Detail "validator file missing"
}
else {
    if ($StrictShould) {
        & $pwshValidator -Aiif $Aiif -Checklist $Checklist -StrictShould
    }
    else {
        & $pwshValidator -Aiif $Aiif -Checklist $Checklist
    }

    $pwCode = $LASTEXITCODE
    if ($pwCode -eq 0) {
        Add-Result -Validator "powershell" -Status "PASS" -Code $pwCode -Detail "validator succeeded"
    }
    else {
        Add-Result -Validator "powershell" -Status "FAIL" -Code $pwCode -Detail "validator reported non-compliance or error"
    }
}

# 3) Bash validator
if (-not (Test-Path -Path $bashValidator)) {
    Add-Result -Validator "bash" -Status "SKIP" -Code 2 -Detail "validator file missing"
}
else {
    if (-not (Test-BashRunnable)) {
        Add-Result -Validator "bash" -Status "SKIP" -Code 2 -Detail "bash runtime not available"
    }
    else {
        $bashParams = @($bashValidator, "--aiif", $Aiif, "--checklist", $Checklist)
        if ($StrictShould) {
            $bashParams += "--strict-should"
        }

        & bash @bashParams
        $bashCode = $LASTEXITCODE
        if ($bashCode -eq 0) {
            Add-Result -Validator "bash" -Status "PASS" -Code $bashCode -Detail "validator succeeded"
        }
        else {
            Add-Result -Validator "bash" -Status "FAIL" -Code $bashCode -Detail "validator reported non-compliance or error"
        }
    }
}

Write-Output ("=" * 72)
Write-Output "Validator Summary"
Write-Output ("-" * 72)
$results | Format-Table -AutoSize

$ranCount = @($results | Where-Object { $_.status -ne "SKIP" }).Count
$skipCount = @($results | Where-Object { $_.status -eq "SKIP" }).Count
$failCount = @($results | Where-Object { $_.status -eq "FAIL" }).Count

if ($ranCount -eq 0) {
    Write-Output "Result: NO VALIDATORS RAN"
    exit 2
}

if ($RequireAll -and $skipCount -gt 0) {
    Write-Output "Result: INCOMPLETE (RequireAll enabled and one or more validators were skipped)"
    exit 2
}

if ($failCount -gt 0) {
    Write-Output "Result: FAILED (one or more validators failed)"
    exit 1
}

Write-Output "Result: PASSED (all executed validators passed)"
exit 0
