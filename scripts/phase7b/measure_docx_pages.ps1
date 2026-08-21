param(
    [Parameter(Mandatory = $true)][string]$DocxPath,
    [ValidateRange(1, 300)][int]$TimeoutSeconds = 45,
    [switch]$Worker,
    [string]$OwnedPidPath,
    [string]$ResultPath,
    [string]$ErrorPath,
    [string]$PreexistingWordPids,
    [string]$ReadyPath,
    [string]$JobName,
    [ValidateSet('None', 'ActivationHang', 'AfterCreationBeforePid', 'AfterDocumentOpen')]
    [string]$FaultStage = 'None'
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
        Stop-Process -Id $ownedWordPid -Force -ErrorAction SilentlyContinue
    }
}

function Initialize-JobApi {
    if ('Phase7B.JobApi' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Phase7B {
  public static class JobApi {
    public const UInt32 JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000;
    [StructLayout(LayoutKind.Sequential)] public struct IO_COUNTERS {
      public UInt64 ReadOperationCount, WriteOperationCount, OtherOperationCount;
      public UInt64 ReadTransferCount, WriteTransferCount, OtherTransferCount;
    }
    [StructLayout(LayoutKind.Sequential)] public struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
      public Int64 PerProcessUserTimeLimit, PerJobUserTimeLimit;
      public UInt32 LimitFlags;
      public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize;
      public UInt32 ActiveProcessLimit;
      public Int64 Affinity;
      public UInt32 PriorityClass, SchedulingClass;
    }
    [StructLayout(LayoutKind.Sequential)] public struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
      public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
      public IO_COUNTERS IoInfo;
      public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr OpenJobObject(UInt32 access, bool inherit, string name);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, UInt32 length);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool TerminateJobObject(IntPtr job, UInt32 exitCode);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool IsProcessInJob(IntPtr process, IntPtr job, out bool result);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(UInt32 access, bool inherit, UInt32 processId);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr handle);
  }
}
'@
}

function New-KillOnCloseJob {
    param([string]$Name)
    Initialize-JobApi
    $job = [Phase7B.JobApi]::CreateJobObject([IntPtr]::Zero, $Name)
    if ($job -eq [IntPtr]::Zero) { throw "CreateJobObject failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
    $information = [Phase7B.JobApi+JOBOBJECT_EXTENDED_LIMIT_INFORMATION]::new()
    $information.BasicLimitInformation.LimitFlags = [Phase7B.JobApi]::JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    $size = [Runtime.InteropServices.Marshal]::SizeOf($information)
    $pointer = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
    try {
        [Runtime.InteropServices.Marshal]::StructureToPtr($information, $pointer, $false)
        if (-not [Phase7B.JobApi]::SetInformationJobObject($job, 9, $pointer, $size)) {
            throw "SetInformationJobObject failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
        return $job
    }
    catch {
        [void][Phase7B.JobApi]::CloseHandle($job)
        throw
    }
    finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($pointer) }
}

function Add-ProcessToNamedJob {
    param([string]$Name, [int]$ProcessId)
    Initialize-JobApi
    $job = [Phase7B.JobApi]::OpenJobObject(5, $false, $Name)
    if ($job -eq [IntPtr]::Zero) { throw "OpenJobObject failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
    $process = [Phase7B.JobApi]::OpenProcess(0x1501, $false, [uint32]$ProcessId)
    if ($process -eq [IntPtr]::Zero) {
        [void][Phase7B.JobApi]::CloseHandle($job)
        throw "OpenProcess for job assignment failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }
    try {
        [bool]$alreadyOwned = $false
        if (-not [Phase7B.JobApi]::IsProcessInJob($process, $job, [ref]$alreadyOwned)) {
            throw "IsProcessInJob failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
        if ($alreadyOwned) { return }
        if (-not [Phase7B.JobApi]::AssignProcessToJobObject($job, $process)) {
            throw "AssignProcessToJobObject for WINWORD failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
    }
    finally {
        [void][Phase7B.JobApi]::CloseHandle($process)
        [void][Phase7B.JobApi]::CloseHandle($job)
    }
}

function Stop-OnlyProcessesInOwnedJob {
    param([IntPtr]$Job, [int[]]$PreexistingWordPids)
    foreach ($candidate in @(Get-Process -Name WINWORD -ErrorAction SilentlyContinue | Where-Object { $_.Id -notin $PreexistingWordPids })) {
        $processHandle = [Phase7B.JobApi]::OpenProcess(0x1001, $false, [uint32]$candidate.Id)
        if ($processHandle -eq [IntPtr]::Zero) { continue }
        try {
            [bool]$isMember = $false
            if ([Phase7B.JobApi]::IsProcessInJob($processHandle, $Job, [ref]$isMember) -and $isMember) {
                Stop-Process -Id $candidate.Id -Force -ErrorAction Stop
            }
        }
        finally { [void][Phase7B.JobApi]::CloseHandle($processHandle) }
    }
}

if ($Worker) {
    $resolvedDocx = (Resolve-Path -LiteralPath $DocxPath -ErrorAction Stop).Path
    $preexistingWordPids = @(
        ($PreexistingWordPids -split '[,;\s]+') |
            Where-Object { $_ -ne '' } |
            ForEach-Object { [int]$_ }
    )
    $word = $null
    $document = $null
    [int]$ownedWordPid = 0
    $exitCode = 0
    try {
        $readyDeadline = [DateTime]::UtcNow.AddSeconds(30)
        while (-not (Test-Path -LiteralPath $ReadyPath)) {
            if ([DateTime]::UtcNow -ge $readyDeadline) { throw 'Supervisor did not publish the job-ownership ready marker.' }
            Start-Sleep -Milliseconds 25
        }
        if ($FaultStage -eq 'ActivationHang') { Start-Sleep -Seconds 600 }
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
        Add-ProcessToNamedJob -Name $JobName -ProcessId $ownedWordPid
        if ($FaultStage -eq 'AfterCreationBeforePid') { Start-Sleep -Seconds 600 }
        [IO.File]::WriteAllText($OwnedPidPath, [string]$ownedWordPid, [Text.UTF8Encoding]::new($false))
        $document = $word.Documents.OpenNoRepairDialog($resolvedDocx, $false, $true, $false)
        foreach ($additionalWord in @(Get-Process -Name WINWORD -ErrorAction SilentlyContinue | Where-Object { $_.Id -notin $preexistingWordPids -and $_.Id -ne $ownedWordPid })) {
            Add-ProcessToNamedJob -Name $JobName -ProcessId ([int]$additionalWord.Id)
        }
        if ($FaultStage -eq 'AfterDocumentOpen') { Start-Sleep -Seconds 600 }
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
$readyPath = Join-Path $taskRoot 'job-ready.txt'
$workerProcess = $null
$jobHandle = [IntPtr]::Zero
$jobName = 'Local\phase7b-word-pagination-' + [Guid]::NewGuid().ToString('N')
$trackedWordPids = [System.Collections.Generic.HashSet[int]]::new()
$trackingStarted = [DateTime]::Now.AddSeconds(-1)
$currentSessionId = (Get-Process -Id $PID).SessionId
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
        '-PreexistingWordPids', (& $quoted ($preexistingWordPids -join ',')),
        '-ReadyPath', (& $quoted $readyPath),
        '-JobName', (& $quoted $jobName),
        '-FaultStage', $FaultStage
    ) -join ' '
    $workerProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $jobHandle = New-KillOnCloseJob -Name $jobName
    if (-not [Phase7B.JobApi]::AssignProcessToJobObject($jobHandle, $workerProcess.Handle)) {
        throw "AssignProcessToJobObject failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }
    [IO.File]::WriteAllText($readyPath, 'ready', [Text.UTF8Encoding]::new($false))
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $workerProcess.WaitForExit(100) -and [DateTime]::UtcNow -lt $deadline) {
        foreach ($candidate in @(Get-CimInstance Win32_Process -Filter "Name='WINWORD.EXE'" -ErrorAction SilentlyContinue)) {
            if (
                $candidate.ProcessId -notin $preexistingWordPids -and
                $candidate.CreationDate -ge $trackingStarted -and
                $candidate.CommandLine -match '(?i)[/-]Automation\s+[/-]Embedding' -and
                (Get-Process -Id $candidate.ProcessId -ErrorAction SilentlyContinue).SessionId -eq $currentSessionId
            ) {
                [void]$trackedWordPids.Add([int]$candidate.ProcessId)
            }
        }
    }
    if (-not $workerProcess.HasExited) {
        if ($jobHandle -ne [IntPtr]::Zero) {
            [void][Phase7B.JobApi]::TerminateJobObject($jobHandle, 124)
            Stop-OnlyProcessesInOwnedJob -Job $jobHandle -PreexistingWordPids $preexistingWordPids
            foreach ($trackedWordPid in $trackedWordPids) {
                Stop-OnlyOwnedWordProcess -ownedWordPid $trackedWordPid -preexistingWordPids $preexistingWordPids
            }
            if (Test-Path -LiteralPath $ownedPidPath) {
                [int]$publishedOwnedPid = [int](Get-Content -Raw -LiteralPath $ownedPidPath)
                Stop-OnlyOwnedWordProcess -ownedWordPid $publishedOwnedPid -preexistingWordPids $preexistingWordPids
            }
            [void][Phase7B.JobApi]::CloseHandle($jobHandle)
            $jobHandle = [IntPtr]::Zero
        }
        for ($attempt = 0; $attempt -lt 50; $attempt++) {
            $remainingOwned = @(Get-Process -Name WINWORD -ErrorAction SilentlyContinue | Where-Object { $_.Id -notin $preexistingWordPids })
            if ($remainingOwned.Count -eq 0) { break }
            Start-Sleep -Milliseconds 100
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
    if ($jobHandle -ne [IntPtr]::Zero) {
        [void][Phase7B.JobApi]::CloseHandle($jobHandle)
        $jobHandle = [IntPtr]::Zero
    }
    if ($null -ne $workerProcess -and -not $workerProcess.HasExited) {
        Stop-Process -Id $workerProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $taskRoot) {
        Remove-Item -LiteralPath $taskRoot -Force -Recurse
    }
}
