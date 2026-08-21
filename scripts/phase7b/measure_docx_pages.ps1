param(
    [Parameter(Mandatory = $true)][string]$DocxPath,
    [ValidateRange(1, 300)][int]$TimeoutSeconds = 45,
    [switch]$Worker,
    [string]$OwnedPidPath,
    [string]$ResultPath,
    [string]$ErrorPath,
    [string]$PreexistingWordPids
)

$ErrorActionPreference = 'Stop'

function Release-ComReference {
    param($Reference)
    if ($null -ne $Reference) {
        try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Reference) } catch {}
    }
}

function Stop-OnlyOwnedWordProcess {
    param([int]$ownedWordPid, [int[]]$preexistingWordPids)
    if ($ownedWordPid -le 0 -or $ownedWordPid -in $preexistingWordPids) { return }
    $process = Get-Process -Id $ownedWordPid -ErrorAction SilentlyContinue
    if ($null -ne $process -and $process.ProcessName -eq 'WINWORD') {
        Stop-Process -Id $ownedWordPid -Force -ErrorAction Stop
    }
}

if ($Worker) {
    $resolvedDocx = (Resolve-Path -LiteralPath $DocxPath -ErrorAction Stop).Path
    $preexistingWordPids = @(
        $PreexistingWordPids.Split(',', [StringSplitOptions]::RemoveEmptyEntries) |
            ForEach-Object { [int]$_ }
    )
    $word = $null
    $document = $null
    [int]$ownedWordPid = 0
    $exitCode = 0
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        try { $word.AutomationSecurity = 3 } catch {}
        $owned = @(
            Get-Process -Name WINWORD -ErrorAction SilentlyContinue |
                Where-Object { $_.Id -notin $preexistingWordPids }
        )
        if ($owned.Count -ne 1) {
            throw "Expected exactly one task-owned WINWORD process; found $($owned.Count)."
        }
        $ownedWordPid = [int]$owned[0].Id
        [IO.File]::WriteAllText($OwnedPidPath, [string]$ownedWordPid, [Text.UTF8Encoding]::new($false))
        $document = $word.Documents.OpenNoRepairDialog($resolvedDocx, $false, $true, $false)
        $document.Repaginate()
        $pageCount = [int]$document.ComputeStatistics(2)
        if ($pageCount -lt 1) { throw "Word returned an invalid rendered page count: $pageCount" }
        [IO.File]::WriteAllText($ResultPath, [string]$pageCount, [Text.UTF8Encoding]::new($false))
    }
    catch {
        $exitCode = 2
        [IO.File]::WriteAllText($ErrorPath, $_.Exception.ToString(), [Text.UTF8Encoding]::new($false))
    }
    finally {
        try { if ($null -ne $document) { $document.Close(0) } } catch { $exitCode = 3 }
        try { if ($null -ne $word) { $word.Quit() } } catch { $exitCode = 3 }
        Release-ComReference -Reference $document
        Release-ComReference -Reference $word
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        if ($ownedWordPid -gt 0) {
            for ($attempt = 0; $attempt -lt 50; $attempt++) {
                if (-not (Get-Process -Id $ownedWordPid -ErrorAction SilentlyContinue)) { break }
                Start-Sleep -Milliseconds 100
            }
            if (Get-Process -Id $ownedWordPid -ErrorAction SilentlyContinue) {
                try { Stop-OnlyOwnedWordProcess -ownedWordPid $ownedWordPid -preexistingWordPids $preexistingWordPids } catch { $exitCode = 3 }
                $exitCode = 3
            }
        }
    }
    exit $exitCode
}

$resolvedDocx = (Resolve-Path -LiteralPath $DocxPath -ErrorAction Stop).Path
if ([IO.Path]::GetExtension($resolvedDocx) -ine '.docx') { throw 'DOCX pagination requires a .docx input.' }
$preexistingWordPids = @(
    Get-Process -Name WINWORD -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Id
)
$taskRoot = Join-Path ([IO.Path]::GetTempPath()) ('.phase7b-word-pagination-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($taskRoot) | Out-Null
$ownedPidPath = Join-Path $taskRoot 'owned-word-pid.txt'
$resultPath = Join-Path $taskRoot 'page-count.txt'
$errorPath = Join-Path $taskRoot 'error.txt'
$stdoutPath = Join-Path $taskRoot 'worker.stdout.txt'
$stderrPath = Join-Path $taskRoot 'worker.stderr.txt'
$workerProcess = $null
try {
    $quoted = {
        param([string]$Value)
        return '"' + $Value.Replace('"', '\"') + '"'
    }
    $arguments = @(
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', (& $quoted $PSCommandPath), '-Worker',
        '-DocxPath', (& $quoted $resolvedDocx),
        '-OwnedPidPath', (& $quoted $ownedPidPath),
        '-ResultPath', (& $quoted $resultPath),
        '-ErrorPath', (& $quoted $errorPath),
        '-PreexistingWordPids', (& $quoted ($preexistingWordPids -join ','))
    ) -join ' '
    $workerProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if (-not $workerProcess.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $workerProcess.Id -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $ownedPidPath) {
            [int]$ownedWordPid = [int](Get-Content -Raw -LiteralPath $ownedPidPath)
            Stop-OnlyOwnedWordProcess -ownedWordPid $ownedWordPid -preexistingWordPids $preexistingWordPids
        }
        throw "Word pagination timed out after $TimeoutSeconds seconds."
    }
    $workerProcess.WaitForExit()
    $workerProcess.Refresh()
    [int]$workerExitCode = $workerProcess.ExitCode
    if ($workerExitCode -ne 0) {
        $detail = if (Test-Path -LiteralPath $errorPath) { Get-Content -Raw -LiteralPath $errorPath } else { Get-Content -Raw -LiteralPath $stderrPath }
        throw "Word pagination failed closed with exit code $workerExitCode`: $detail"
    }
    if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Word pagination did not produce a page count.' }
    $pageCount = 0
    if (-not [int]::TryParse((Get-Content -Raw -LiteralPath $resultPath), [ref]$pageCount) -or $pageCount -lt 1) {
        throw 'Word pagination produced an invalid page count.'
    }
    if (Test-Path -LiteralPath $ownedPidPath) {
        $ownedWordPid = [int](Get-Content -Raw -LiteralPath $ownedPidPath)
        if (Get-Process -Id $ownedWordPid -ErrorAction SilentlyContinue) {
            Stop-OnlyOwnedWordProcess -ownedWordPid $ownedWordPid -preexistingWordPids $preexistingWordPids
            throw "Task-owned WINWORD process survived pagination cleanup: $ownedWordPid"
        }
    }
    Write-Output "DOCX_RENDERED_PAGE_COUNT=$pageCount"
}
finally {
    if ($null -ne $workerProcess -and -not $workerProcess.HasExited) {
        Stop-Process -Id $workerProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $taskRoot) {
        Remove-Item -LiteralPath $taskRoot -Force -Recurse
    }
}
