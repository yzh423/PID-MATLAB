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
run('experiments/run_nominal_pid.m');
clear outputRoot;
run('experiments/run_nominal_pid_vs_fuzzy.m');
clear outputRoot;
run('experiments/run_pid_optimization.m');
clear outputRoot robustnessMode robustnessReference;
run('experiments/run_deterministic_robustness.m');
clear outputRoot stochasticMode stochasticReference;
run('experiments/run_stochastic_robustness.m');
clear outputRoot cartesianMode;
run('experiments/run_cartesian_tasks.m');
clear outputRoot simulinkValidationMode;
run('experiments/run_simulink_cross_validation.m');
clear outputRoot multibodyValidationMode controllerDefinitions;
run('experiments/run_multibody_cross_validation.m');
results = runtests('tests', 'IncludeSubfolders', true);
assertSuccess(results);
"@ -replace "`r?`n", ' '

& $matlabExecutable -batch $matlabCommand
if ($LASTEXITCODE -ne 0) {
    throw "MATLAB verification failed with exit code $LASTEXITCODE"
}

& (Join-Path $PSScriptRoot 'verify_report.ps1')
if ($LASTEXITCODE -ne 0) {
    throw "Report verification failed with exit code $LASTEXITCODE"
}
