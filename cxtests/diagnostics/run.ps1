# Run all negative-input tests under cxtests/diagnostics/.
#
# Three kinds of "negative" tests are supported, distinguished by
# which @expect-* header is present:
#
#   Compile-time diagnostics (Cx front-end):
#     // @expect-errors: N
#     // @expect-first-at: L:C
#
#   C-compile failure (codegen-level error surfaced by the C compiler):
#     // @expect-compile-fail-contains: <substring>
#
#   Runtime check failure:
#     // @expect-runtime-fail: N
#
# Each test declares at most one kind. Files without any header are
# reported as INFO and not counted.
#
# Usage:
#     powershell -ExecutionPolicy Bypass -File run.ps1
#
# Exit code: 0 if all annotated tests pass, 1 otherwise.

$ErrorActionPreference = 'Continue'

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $dir
try {
    $pass = 0; $fail = 0; $skip = 0

    Get-ChildItem -Filter '*.cx' | Sort-Object Name | ForEach-Object {
        $file = $_.Name

        $expErr    = $null
        $expAt     = $null
        $expRun    = $null
        $expCFail  = $null
        Get-Content $file -TotalCount 20 | ForEach-Object {
            if ($_ -match '^\s*//\s*@expect-errors:\s*(\d+)') {
                $expErr = [int]$Matches[1]
            }
            if ($_ -match '^\s*//\s*@expect-first-at:\s*(\d+):(\d+)') {
                $expAt = "$($Matches[1]):$($Matches[2])"
            }
            if ($_ -match '^\s*//\s*@expect-runtime-fail:\s*(\d+)') {
                $expRun = [int]$Matches[1]
            }
            if ($_ -match '^\s*//\s*@expect-compile-fail-contains:\s*(.+?)\s*$') {
                $expCFail = $Matches[1]
            }
        }

        $raw = & cx test $file 2>&1 | Out-String

        $gotErr = $null
        if ($raw -match 'result:\s*(\d+)\s+error') {
            $gotErr = [int]$Matches[1]
        }
        $gotAt = $null
        if ($raw -match ' --> \S+?:(\d+):(\d+)') {
            $gotAt = "$($Matches[1]):$($Matches[2])"
        }
        $gotRun = $null
        if ($raw -match '(\d+) passed,\s*(\d+) failed') {
            $gotRun = [int]$Matches[2]
        }

        # -- compile-time diagnostic test --
        if ($null -ne $expErr) {
            $okErr = ($expErr -eq $gotErr)
            $okAt  = ($null -eq $expAt) -or ($expAt -eq $gotAt)
            if ($okErr -and $okAt) {
                Write-Host ("PASS  {0,-28} errors={1} first-at={2}" -f $file, $gotErr, $gotAt) -ForegroundColor Green
                $pass++
            } else {
                Write-Host ("FAIL  {0,-28} expected errors={1} first-at={2}, got errors={3} first-at={4}" -f $file, $expErr, $expAt, $gotErr, $gotAt) -ForegroundColor Red
                Write-Host $raw
                $fail++
            }
            return
        }

        # -- C-compile failure test (codegen-level error) --
        if ($null -ne $expCFail) {
            if ($raw -like "*$expCFail*") {
                Write-Host ("PASS  {0,-28} compile-fail contains: {1}" -f $file, $expCFail) -ForegroundColor Green
                $pass++
            } else {
                Write-Host ("FAIL  {0,-28} expected compile-fail containing: {1}" -f $file, $expCFail) -ForegroundColor Red
                Write-Host $raw
                $fail++
            }
            return
        }

        # -- runtime check-failure test --
        if ($null -ne $expRun) {
            $okRun = ($expRun -eq $gotRun)
            if ($okRun) {
                Write-Host ("PASS  {0,-28} runtime-fail={1}" -f $file, $gotRun) -ForegroundColor Green
                $pass++
            } else {
                Write-Host ("FAIL  {0,-28} expected runtime-fail={1}, got {2}" -f $file, $expRun, $gotRun) -ForegroundColor Red
                Write-Host $raw
                $fail++
            }
            return
        }

        # -- no annotation --
        Write-Host ("INFO  {0,-28} errors={1} first-at={2} runtime-fail={3}" -f $file, $gotErr, $gotAt, $gotRun) -ForegroundColor DarkGray
        $skip++
    }

    Write-Host ""
    Write-Host ("=== {0} passed, {1} failed, {2} info-only ===" -f $pass, $fail, $skip)
    if ($fail -gt 0) { exit 1 } else { exit 0 }
}
finally {
    Pop-Location
}