param(
    [Parameter(Mandatory = $true)]
    [string]$Aiif,

    [string]$Checklist = "AIIF-Conformance-Checklist.json",

    [switch]$StrictShould
)

if (-not (Test-Path -Path $Aiif)) {
    Write-Error "AIIF file not found: $Aiif"
    exit 2
}

if (-not (Test-Path -Path $Checklist)) {
    Write-Error "Checklist file not found: $Checklist"
    exit 2
}

try {
    $doc = Get-Content -Path $Aiif -Raw | ConvertFrom-Json
    $checklistDoc = Get-Content -Path $Checklist -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Invalid JSON input: $($_.Exception.Message)"
    exit 2
}

$checkMap = @{}
foreach ($c in ($checklistDoc.checks | Where-Object { $_ -ne $null })) {
    if ($c.id) {
        $checkMap[$c.id] = $c
    }
}

$results = @()

function Add-CheckResult {
    param(
        [string]$Id,
        [bool]$Passed,
        [string]$Message
    )
    $level = "INFO"
    if ($checkMap.ContainsKey($Id) -and $checkMap[$Id].level) {
        $level = [string]$checkMap[$Id].level
    }
    $script:results += [PSCustomObject]@{
        id      = $Id
        level   = $level
        passed  = $Passed
        message = $Message
    }
}

function Get-Endpoints {
    if ($null -eq $doc.endpoints) { return @() }
    if ($doc.endpoints -is [System.Array]) { return $doc.endpoints }
    return @($doc.endpoints)
}

$endpoints = Get-Endpoints

# impl.top_level.required_fields
$missing = @()
if ($null -eq $doc.aiif_version) { $missing += "aiif_version" }
if ($null -eq $doc.info) { $missing += "info" }
if ($null -eq $doc.endpoints) { $missing += "endpoints" }
$aiifVersionOk = ($doc.aiif_version -is [string]) -and (-not [string]::IsNullOrWhiteSpace([string]$doc.aiif_version))
$topOk = ($missing.Count -eq 0) -and $aiifVersionOk -and ($doc.info -is [psobject]) -and ($doc.endpoints -is [System.Array] -or $doc.endpoints -is [System.Collections.IEnumerable])
if ($topOk) {
    Add-CheckResult "impl.top_level.required_fields" $true "top-level required fields present"
}
else {
    if (-not $aiifVersionOk) { $missing += "aiif_version (must be non-empty string)" }
    Add-CheckResult "impl.top_level.required_fields" $false "missing/invalid top-level fields: $($missing -join ', ')"
}

# impl.endpoint_name.unique + impl.method_path.unique
$nameSet = @{}
$dupNames = New-Object System.Collections.Generic.List[string]
$methodPathSet = @{}
$dupMethodPaths = New-Object System.Collections.Generic.List[string]

foreach ($ep in $endpoints) {
    if ($null -eq $ep) { continue }
    $name = [string]$ep.name
    if ($name) {
        if ($nameSet.ContainsKey($name)) {
            [void]$dupNames.Add($name)
        }
        $nameSet[$name] = $true
    }
    $method = [string]$ep.method
    $path = [string]$ep.path
    if ($method -and $path) {
        $key = "$method|$path"
        if ($methodPathSet.ContainsKey($key)) {
            [void]$dupMethodPaths.Add($key)
        }
        $methodPathSet[$key] = $true
    }
}

Add-CheckResult "impl.endpoint_name.unique" ($dupNames.Count -eq 0) $(if ($dupNames.Count -eq 0) { "endpoint names are unique" } else { "duplicate endpoint names: $($dupNames -join ', ')" })
Add-CheckResult "impl.method_path.unique" ($dupMethodPaths.Count -eq 0) $(if ($dupMethodPaths.Count -eq 0) { "(method,path) pairs are unique" } else { "duplicate (method,path) pairs: $($dupMethodPaths -join ', ')" })

# impl.params.unique_by_name_location
$dupParams = New-Object System.Collections.Generic.List[string]
foreach ($ep in $endpoints) {
    if ($null -eq $ep) { continue }
    $epName = if ($ep.name) { [string]$ep.name } else { "<unknown>" }
    $seen = @{}
    $params = @()
    if ($ep.params) {
        if ($ep.params -is [System.Array]) { $params = $ep.params } else { $params = @($ep.params) }
    }
    foreach ($p in $params) {
        if ($null -eq $p) { continue }
        $pn = if ($p.name) { [string]$p.name } else { "<unknown>" }
        $pl = if ($p.location) { [string]$p.location } else { "<unknown>" }
        $key = "$pn|$pl"
        if ($seen.ContainsKey($key)) {
            [void]$dupParams.Add("${epName}:$key")
        }
        $seen[$key] = $true
    }
}
Add-CheckResult "impl.params.unique_by_name_location" ($dupParams.Count -eq 0) $(if ($dupParams.Count -eq 0) { "params are unique by (name,location)" } else { "duplicate params: $($dupParams -join ', ')" })

# impl.auth_flow.structured_fields
$authOk = $true
$authMessage = "auth requirements not triggered"
if ($doc.auth) {
    $authType = [string]$doc.auth.type
    if ($authType -in @("bearer", "oauth2")) {
        $hasInstructions = ($doc.auth.instructions -is [System.Array]) -and ($doc.auth.instructions.Count -gt 0)
        $hasAcquire = $null -ne $doc.auth.acquire
        $hasApply = $null -ne $doc.auth.apply
        $authOk = $hasInstructions -and $hasAcquire -and $hasApply
        $authMessage = if ($authOk) { "bearer/oauth2 auth includes instructions+acquire+apply" } else { "bearer/oauth2 auth should include instructions, acquire, and apply" }
    }
}
Add-CheckResult "impl.auth_flow.structured_fields" $authOk $authMessage

# impl.auth_docs.required_for_protected (static)
$authTypeValue = if ($doc.auth -and $doc.auth.type) { [string]$doc.auth.type } else { "" }
if ($authTypeValue -and $authTypeValue -ne "none") {
    Add-CheckResult "impl.auth_docs.required_for_protected" $true "requires /ai-docs/auth for protected APIs (runtime endpoint verification out of scope for static document validation)"
}
else {
    Add-CheckResult "impl.auth_docs.required_for_protected" $true "auth.type is none or missing; /ai-docs/auth requirement not triggered"
}

# impl.endpoint.auth_required_supported
$missingAuthRequired = @()
foreach ($ep in $endpoints) {
    if ($null -eq $ep) { continue }
    $props = $ep.PSObject.Properties.Name
    if (-not ($props -contains "auth_required")) {
        $missingAuthRequired += $(if ($ep.name) { [string]$ep.name } else { "<unknown>" })
    }
}
Add-CheckResult "impl.endpoint.auth_required_supported" ($missingAuthRequired.Count -eq 0) $(if ($missingAuthRequired.Count -eq 0) { "all endpoints include auth_required" } else { "endpoints missing auth_required: $($missingAuthRequired -join ', ')" })

# impl.endpoint.response_content_type_supported
$missingResponseContentType = @()
foreach ($ep in $endpoints) {
    if ($null -eq $ep) { continue }
    $props = $ep.PSObject.Properties.Name
    if (-not ($props -contains "response_content_type")) {
        $missingResponseContentType += $(if ($ep.name) { [string]$ep.name } else { "<unknown>" })
    }
}
Add-CheckResult "impl.endpoint.response_content_type_supported" ($missingResponseContentType.Count -eq 0) $(if ($missingResponseContentType.Count -eq 0) { "all endpoints include response_content_type" } else { "endpoints missing response_content_type: $($missingResponseContentType -join ', ')" })

# impl.params.constraints_published
$paramsTotal = 0
$constrained = 0
foreach ($ep in $endpoints) {
    if ($null -eq $ep -or -not $ep.params) { continue }
    $params = if ($ep.params -is [System.Array]) { $ep.params } else { @($ep.params) }
    foreach ($p in $params) {
        if ($null -eq $p) { continue }
        $paramsTotal += 1
        $pProps = $p.PSObject.Properties.Name
        if (($pProps -contains "minimum") -or ($pProps -contains "maximum") -or ($pProps -contains "min_length") -or ($pProps -contains "max_length") -or ($pProps -contains "pattern") -or ($pProps -contains "format")) {
            $constrained += 1
        }
    }
}

if ($paramsTotal -eq 0) {
    Add-CheckResult "impl.params.constraints_published" $true "no params defined; constraint publication not applicable"
}
else {
    $constraintsOk = $constrained -gt 0
    Add-CheckResult "impl.params.constraints_published" $constraintsOk "$constrained/$paramsTotal params publish machine-readable constraints"
}

# impl.agent_rules.consistent
$docProps = $doc.PSObject.Properties.Name
if (-not ($docProps -contains "agent_rules")) {
    Add-CheckResult "impl.agent_rules.consistent" $true "agent_rules not present (optional)"
}
else {
    $rules = $doc.agent_rules
    $rulesOk = $true
    if (-not ($rules -is [System.Array])) {
        $rulesOk = $false
    }
    else {
        foreach ($r in $rules) {
            if (($r -isnot [string]) -or ([string]::IsNullOrWhiteSpace([string]$r))) {
                $rulesOk = $false
                break
            }
        }
    }
    Add-CheckResult "impl.agent_rules.consistent" $rulesOk $(if ($rulesOk) { "agent_rules is a non-empty string list" } else { "agent_rules should be an array of non-empty strings" })
}

$mustFailures = 0
$shouldFailures = 0

Write-Output "AIIF Conformance Report"
Write-Output ("=" * 72)

foreach ($r in $results) {
    $status = if ($r.passed) { "PASS" } else { "FAIL" }
    Write-Output "[$status] $($r.id) ($($r.level))"
    Write-Output "       $($r.message)"
    if (-not $r.passed) {
        if ($r.level -eq "MUST") { $mustFailures += 1 }
        elseif ($r.level -eq "SHOULD") { $shouldFailures += 1 }
    }
}

Write-Output ("-" * 72)
Write-Output "Total checks: $($results.Count)"
Write-Output "MUST failures: $mustFailures"
Write-Output "SHOULD failures: $shouldFailures"

if ($mustFailures -eq 0) {
    Write-Output "Result: COMPLIANT (all MUST checks passed)"
}
else {
    Write-Output "Result: NOT COMPLIANT (one or more MUST checks failed)"
}

if ($mustFailures -gt 0) { exit 1 }
if ($StrictShould -and $shouldFailures -gt 0) { exit 1 }
exit 0
