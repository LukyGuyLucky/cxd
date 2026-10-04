# Run all positive-input tests under cxtests/lang/.
#
# Each test is a Cx file with one or more `test "..." { ... }`
# blocks. The runner invokes `cx test <file>` and requires:
#
#   - exit code 0
#   - "N passed, 0 failed" in the output
#   - N > 0 (a file with no test blocks is a FAIL, not a pass)
#
# Two exceptions:
#
#   *  Files ending in `_probe.cx` are skipped. A probe is a
#      manual inspection file, not a test: it exists so you can
#      run `cx file.cx --emit-c` and read the generated C. It
#      has no test blocks on purpose.
#
#   *  A file may declare `// @expect-fail: N` to say it
#      intentionally has N failing checks (teaching examples,
#      self-tests of `check_fail`). The runner then requires
#      exactly N failures and exit code N.
#
# Usage:
#     powershell -ExecutionPolicy Bypass -File run.ps1
#
# Exit code: 0 if all tests pass, 1 otherwise.

$ErrorActionPreference = 'Continue'

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $dir
try {
    $pass = 0; $fail = 0; $skip = 0

    Get-ChildItem -Filter '*.cx' | Sort-Object Name | ForEach-Object {
        $file = $_.Name

        if ($file -like '*_probe.cx') {
            Write-Host ("SKIP  {0,-32} probe file" -f $file) -ForegroundColor DarkGray
            $skip++
            return
        }

        $expFail = 0
        Get-Content $file -TotalCount 20 | ForEach-Object {
            if ($_ -match '^\s*//\s*@expect-fail:\s*(\d+)') {
                $expFail = [int]$Matches[1]
            }
        }

        $raw  = & cx test $file 2>&1 | Out-String
        $code = $LASTEXITCODE

        $nPassed = $null
        $nFailed = $null
        if ($raw -match '(\d+) passed,\s*(\d+) failed') {
            $nPassed = [int]$Matches[1]
            $nFailed = [int]$Matches[2]
        }

        if ($expFail -gt 0) {
            $ok = ($nFailed -eq $expFail)
            if ($ok) {
                Write-Host ("PASS  {0,-32} {1} passed, {2} failed (expected)" -f $file, $nPassed, $nFailed) -ForegroundColor Green
                $pass++
            } else {
                Write-Host ("FAIL  {0,-32} expected {1} failures, got {2}" -f $file, $expFail, $nFailed) -ForegroundColor Red
                Write-Host $raw
                $fail++
            }
            return
        }

        $ok = ($code -eq 0) -and ($nFailed -eq 0) -and ($nPassed -gt 0)
        if ($ok) {
            Write-Host ("PASS  {0,-32} {1} passed" -f $file, $nPassed) -ForegroundColor Green
            $pass++
        } else {
            Write-Host ("FAIL  {0,-32} exit={1} passed={2} failed={3}" -f $file, $code, $nPassed, $nFailed) -ForegroundColor Red
            Write-Host $raw
            $fail++
        }
    }

    Write-Host ""
    Write-Host ("=== {0} passed, {1} failed, {2} skipped ===" -f $pass, $fail, $skip)
    if ($fail -gt 0) { exit 1 } else { exit 0 }
}
finally {
    Pop-Location
}