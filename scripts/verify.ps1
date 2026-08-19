$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$matlabExecutable = 'E:\MATLAB2026\bin\matlab.exe'
if (-not (Test-Path -LiteralPath $matlabExecutable)) {
    throw "MATLAB executable not found at $matlabExecutable"
}

$matlabProjectRoot = $projectRoot.Replace('\', '/').Replace("'", "''")
$matlabCommand = @"
cd('$matlabProjectRoot');
addpath(pwd);
results = runtests('tests', 'IncludeSubfolders', true);
assertSuccess(results);
run('experiments/run_nominal_pid.m');
"@ -replace "`r?`n", ' '

& $matlabExecutable -batch $matlabCommand
if ($LASTEXITCODE -ne 0) {
    throw "MATLAB verification failed with exit code $LASTEXITCODE"
}
