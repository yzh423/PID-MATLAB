$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Split-Path -Parent $PSScriptRoot)).Path
$matlabExecutable = 'E:\MATLAB2026\bin\matlab.exe'
$pythonExecutable = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'

foreach ($requiredExecutable in @($matlabExecutable, $pythonExecutable)) {
    if (-not (Test-Path -LiteralPath $requiredExecutable -PathType Leaf)) {
        throw "Required executable not found: $requiredExecutable"
    }
}

$matlabProjectRoot = $projectRoot.Replace('\', '/').Replace("'", "''")
$matlabCommand = @"
cd('$matlabProjectRoot');
addpath(genpath(pwd));
run('experiments/export_report_evidence.m');
results = runtests('tests/report', 'IncludeSubfolders', true);
fprintf('REPORT_MATLAB_TESTS=%d PASSED=%d FAILED=%d INCOMPLETE=%d\n', numel(results), nnz([results.Passed]), nnz([results.Failed]), nnz([results.Incomplete]));
assertSuccess(results);
files = {'+rrm/+report/exportEvidence.m'; 'experiments/export_report_evidence.m'; 'tests/report/TestExportReportEvidence.m'};
issues = 0;
for k = 1:numel(files), issues = issues + numel(checkcode(files{k}, '-id')); end;
fprintf('REPORT_CHECKCODE_FILES=%d ISSUES=%d\n', numel(files), issues);
assert(issues == 0);
"@ -replace "`r?`n", ' '

Push-Location $projectRoot
try {
    & $matlabExecutable -batch $matlabCommand
    if ($LASTEXITCODE -ne 0) {
        throw "MATLAB report verification failed with exit code $LASTEXITCODE"
    }

    & $pythonExecutable -m unittest '.\tests\report\test_report_evidence.py' '.\tests\report\test_report_content.py'
    if ($LASTEXITCODE -ne 0) {
        throw "Pre-build Python report tests failed with exit code $LASTEXITCODE"
    }

    & $pythonExecutable '.\scripts\build_report.py' --project-root '.'
    if ($LASTEXITCODE -ne 0) {
        throw "Report build failed with exit code $LASTEXITCODE"
    }

    & (Join-Path $PSScriptRoot 'export_report_pdf.ps1')

    & $pythonExecutable -m unittest discover -s '.\tests\report' -p 'test_*.py'
    if ($LASTEXITCODE -ne 0) {
        throw "Full Python report tests failed with exit code $LASTEXITCODE"
    }

    git diff --check
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --check failed with exit code $LASTEXITCODE"
    }

    $pdfPath = Join-Path $projectRoot 'docs\report\technical_report.pdf'
    $summaryCode = @'
import json, re, sys
from pypdf import PdfReader
reader = PdfReader(sys.argv[1])
pages = [(page.extract_text() or "").strip() for page in reader.pages]
text = "\n".join(pages)
print(json.dumps({
    "pages": len(pages),
    "textPages": sum(len(page) > 40 for page in pages),
    "citations": len(re.findall(r"(?m)^\[[1-8]\] ", text)),
    "unresolved": text.count("{{") + text.count("}}"),
}))
'@
    $summary = (& $pythonExecutable -c $summaryCode $pdfPath) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "PDF summary extraction failed with exit code $LASTEXITCODE"
    }
    $manifest = Get-Content -Raw (Join-Path $projectRoot 'docs\report\build_manifest.json') | ConvertFrom-Json
    Write-Output (
        'REPORT_VERIFIED pages={0} text_pages={1} figures={2} tables={3} references={4} unresolved_tokens={5}' -f
        $summary.pages,
        $summary.textPages,
        $manifest.selectedFigures.Count,
        $manifest.document.tableCount,
        $summary.citations,
        $summary.unresolved
    )
}
finally {
    Pop-Location
}
