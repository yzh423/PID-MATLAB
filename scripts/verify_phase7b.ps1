param(
    [switch]$SkipTests,
    [switch]$ManifestOnly
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked {
    param([scriptblock]$Command, [string]$Failure)
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Failure with exit code $LASTEXITCODE"
    }
}

function Get-Sha256 {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

function Get-DocxRenderedPageCount {
    param([string]$DocxPath)
    $paginationScript = Join-Path $PSScriptRoot 'phase7b\measure_docx_pages.ps1'
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $paginationScript -DocxPath $DocxPath -TimeoutSeconds 45 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Rendered DOCX pagination failed with exit code $LASTEXITCODE`: $($output -join [Environment]::NewLine)" }
    $record = $output | Where-Object { $_ -match '^DOCX_RENDERED_PAGE_COUNT=\d+$' } | Select-Object -Last 1
    if ($null -eq $record) { throw "Rendered DOCX pagination returned no count: $($output -join [Environment]::NewLine)" }
    return [int]($record -replace '^DOCX_RENDERED_PAGE_COUNT=', '')
}

function Get-RelativeHashRecord {
    param([string]$ProjectRoot, [string]$Path)
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $rootPrefix = $ProjectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest path escapes the project root: $resolved"
    }
    $relative = $resolved.Substring($rootPrefix.Length).Replace('\', '/')
    [PSCustomObject]@{
        path = $relative
        sha256 = Get-Sha256 -Path $resolved
    }
}

function Get-OrdinalSortedRecords {
    param([object[]]$Records)
    $ordered = [System.Collections.Generic.List[object]]::new()
    foreach ($record in $Records) {
        [void]$ordered.Add($record)
    }
    $comparison = [System.Comparison[object]]{
        param($left, $right)
        [System.StringComparer]::Ordinal.Compare([string]$left.path, [string]$right.path)
    }
    $ordered.Sort($comparison)
    return $ordered.ToArray()
}

function Write-Phase7BManifest {
    param([string]$ProjectRoot, [int]$DocxPageCount)
    $sourcePaths = @(
        'docs/presentation/phase7b_template.json',
        'docs/presentation/phase7b_raw_evidence.json',
        'docs/presentation/phase7b_layout_report.json',
        'docs/report/build_manifest.json',
        'results/report/report_evidence.json',
        'results/presentation/phase7b_package.json',
        'results/figures/multibody_cross_validation_tracking.png',
        'results/figures/nominal_pid_vs_fuzzy_tracking.png',
        'results/figures/pid_optimization_objective.png',
        'results/figures/deterministic_robustness_summary.png',
        'results/figures/stochastic_robustness_chattering.png',
        'results/figures/cartesian_tasks_paths.png',
        'results/data/nominal_pid_vs_fuzzy.mat',
        'results/data/pid_optimization.mat',
        'results/data/deterministic_robustness.mat',
        'results/data/stochastic_robustness.mat',
        'results/data/cartesian_tasks.mat',
        'results/data/simulink_cross_validation.mat',
        'results/data/multibody_cross_validation.mat',
        'results/data/deterministic_robustness_runs.csv',
        'results/data/deterministic_robustness_summary.csv',
        'results/data/stochastic_robustness_trials.csv',
        'results/data/stochastic_robustness_summary.csv',
        'results/data/cartesian_tasks_runs.csv',
        'results/data/simulink_cross_validation_runs.csv',
        'results/data/multibody_cross_validation_runs.csv',
        'scripts/build_presentation.mjs',
        'scripts/build_research_summary.py',
        'scripts/build_research_summary_pdf.py',
        'scripts/export_phase7b_package.py',
        'scripts/export_research_summary_pdf.ps1',
        'scripts/generate_phase7b_layout_report.py',
        'scripts/normalize_phase7b_office.py',
        'scripts/normalize_research_summary_pdf.py',
        'scripts/verify_phase7b.ps1',
        'scripts/verify_phase7b_audit.py',
        'scripts/phase7b/atomic_publish.mjs',
        'scripts/phase7b/audit.py',
        'scripts/phase7b/evidence.py',
        'scripts/phase7b/layout.py',
        'scripts/phase7b/measure_docx_pages.ps1',
        'scripts/phase7b/office.py',
        'scripts/phase7b/summary.py'
    )
    $outputPaths = @(
        'presentation/final_presentation.pptx',
        'docs/summary/research_summary.docx',
        'docs/summary/research_summary.pdf'
    )
    $manifest = [ordered]@{
        schemaVersion = 1
        generatedAt = '2026-08-21T00:00:00Z'
        sources = @(Get-OrdinalSortedRecords -Records @($sourcePaths | ForEach-Object { Get-RelativeHashRecord -ProjectRoot $ProjectRoot -Path (Join-Path $ProjectRoot $_) }))
        outputs = @(Get-OrdinalSortedRecords -Records @($outputPaths | ForEach-Object { Get-RelativeHashRecord -ProjectRoot $ProjectRoot -Path (Join-Path $ProjectRoot $_) }))
        document = [ordered]@{ notesCount = 10; slideCount = 10; summaryPageCount = $DocxPageCount }
    }
    $manifestRoot = Join-Path $ProjectRoot 'docs\presentation'
    $temporaryManifest = Join-Path $manifestRoot ('.phase7b_build_manifest.' + [Guid]::NewGuid().ToString('N') + '.tmp.json')
    $backupManifest = Join-Path $manifestRoot ('.phase7b_build_manifest.' + [Guid]::NewGuid().ToString('N') + '.bak.json')
    $manifestPath = Join-Path $manifestRoot 'phase7b_build_manifest.json'
    $encoding = New-Object Text.UTF8Encoding($false)
    $json = ($manifest | ConvertTo-Json -Depth 8).Replace("`r`n", "`n") + "`n"
    try {
        [IO.File]::WriteAllText($temporaryManifest, $json, $encoding)
        if (Test-Path -LiteralPath $manifestPath) {
            [IO.File]::Replace($temporaryManifest, $manifestPath, $backupManifest)
        }
        else {
            [IO.File]::Move($temporaryManifest, $manifestPath)
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryManifest) { Remove-Item -LiteralPath $temporaryManifest -Force }
        if (Test-Path -LiteralPath $backupManifest) { Remove-Item -LiteralPath $backupManifest -Force }
    }
}

$projectRoot = (Resolve-Path (Split-Path -Parent $PSScriptRoot)).Path
$bundledPython = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$bundledNode = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
$runtimeNodeModules = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules'
$runtimeBinDir = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\bin\override'
$presentationsSkillDir = 'C:\Users\14228\.codex\plugins\cache\openai-primary-runtime\presentations\26.819.11345\skills\presentations'
$documentsSkillDir = 'C:\Users\14228\.codex\plugins\cache\openai-primary-runtime\documents\26.819.11345\skills\documents'

foreach ($requiredPath in @($bundledPython, $bundledNode, $runtimeNodeModules, $runtimeBinDir, $presentationsSkillDir, $documentsSkillDir)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) { throw "Required bundled dependency not found: $requiredPath" }
}

if ($ManifestOnly) {
    $manifestDocx = Join-Path $projectRoot 'docs\summary\research_summary.docx'
    Write-Phase7BManifest -ProjectRoot $projectRoot -DocxPageCount (Get-DocxRenderedPageCount -DocxPath $manifestDocx)
    Write-Output 'PHASE7B_MANIFEST_REFRESHED'
    return
}

$originalNodePath = $env:NODE_PATH
$originalPath = $env:PATH
$originalRuntimeNode = $env:RUNTIME_NODE
$originalRuntimeNodeModules = $env:RUNTIME_NODE_MODULES
$originalRuntimeBinDir = $env:RUNTIME_BIN_DIR
Push-Location $projectRoot
try {
    $env:NODE_PATH = $runtimeNodeModules
    $env:PATH = "$runtimeBinDir;$([IO.Path]::GetDirectoryName($bundledNode));$originalPath"
    $env:RUNTIME_NODE = $bundledNode
    $env:RUNTIME_NODE_MODULES = $runtimeNodeModules
    $env:RUNTIME_BIN_DIR = $runtimeBinDir
    Invoke-Checked { & $bundledPython '.\scripts\export_phase7b_package.py' --project-root '.' } 'Phase 7B evidence export failed'
    if (-not $SkipTests) {
        Invoke-Checked { & $bundledPython -m unittest '.\tests\presentation\test_phase7b_evidence.py' '.\tests\presentation\test_phase7b_office.py' -v } 'Pre-build Phase 7B Python tests failed'
    }

    Invoke-Checked { & $bundledNode '.\scripts\build_presentation.mjs' --project-root '.' --python $bundledPython } 'Phase 7B PPTX build failed'

    $rebuildRoot = Join-Path $projectRoot 'tmp\phase7b\rebuild'
    if (Test-Path -LiteralPath $rebuildRoot) { Remove-Item -LiteralPath $rebuildRoot -Force -Recurse }
    New-Item -ItemType Directory -Path $rebuildRoot -Force | Out-Null
    $rebuiltDocx = Join-Path $rebuildRoot 'research_summary.docx'
    try {
        Invoke-Checked { & $bundledPython '.\scripts\build_research_summary.py' --project-root '.' --output $rebuiltDocx } 'Phase 7B DOCX rebuild failed'
        $finalDocx = Join-Path $projectRoot 'docs\summary\research_summary.docx'
        if ((Get-Sha256 -Path $rebuiltDocx) -ne (Get-Sha256 -Path $finalDocx)) {
            throw 'Rebuilt Phase 7B DOCX does not match the reviewed final DOCX.'
        }
        $docxPageCount = Get-DocxRenderedPageCount -DocxPath $rebuiltDocx
    }
    finally {
        if (Test-Path -LiteralPath $rebuildRoot) { Remove-Item -LiteralPath $rebuildRoot -Force -Recurse }
    }

    $summaryRoot = Join-Path $projectRoot 'docs\summary'
    $rebuiltPdf = Join-Path $summaryRoot '.phase7b_rebuild.tmp.pdf'
    $normalizedPdf = Join-Path $summaryRoot '.phase7b_rebuild.normalized.pdf'
    try {
        Invoke-Checked { & $bundledPython '.\scripts\build_research_summary_pdf.py' --project-root '.' --output $rebuiltPdf } 'Phase 7B PDF rebuild failed'
        Invoke-Checked { & $bundledPython '.\scripts\normalize_research_summary_pdf.py' --input $rebuiltPdf --output $normalizedPdf --project-root '.' } 'Phase 7B PDF normalization failed'
        $finalPdf = Join-Path $summaryRoot 'research_summary.pdf'
        if ((Get-Sha256 -Path $normalizedPdf) -ne (Get-Sha256 -Path $finalPdf)) {
            throw 'Rebuilt Phase 7B PDF does not match the reviewed final PDF.'
        }
    }
    finally {
        foreach ($ownedTemporary in @($rebuiltPdf, $normalizedPdf)) {
            if (Test-Path -LiteralPath $ownedTemporary) { Remove-Item -LiteralPath $ownedTemporary -Force }
        }
    }

    Write-Phase7BManifest -ProjectRoot $projectRoot -DocxPageCount $docxPageCount
    Invoke-Checked { & $bundledPython '.\scripts\verify_phase7b_audit.py' --project-root '.' --audit '.\docs\presentation\PHASE7B_CLAIM_AUDIT.json' } 'Canonical Phase 7B claim audit gate failed'

    if (-not $SkipTests) {
        Invoke-Checked { & $bundledPython -m unittest discover -s '.\tests\presentation' -p 'test_*.py' -v } 'Full Phase 7B presentation tests failed'
        Invoke-Checked { & $bundledPython (Join-Path $presentationsSkillDir 'container_tools\render_slides.py') '.\presentation\final_presentation.pptx' --output_dir '.\tmp\phase7b\rendered-slides' } 'Phase 7B PPTX render failed'
        if (Get-Command soffice -ErrorAction SilentlyContinue) {
            Invoke-Checked { & $bundledPython (Join-Path $documentsSkillDir 'render_docx.py') '.\docs\summary\research_summary.docx' --output_dir '.\tmp\phase7b\rendered-docx' --emit_pdf } 'Phase 7B DOCX render failed'
        }
        else {
            Write-Warning 'LibreOffice is unavailable; DOCX visual rendering is skipped after the real Word pagination gate passes. The reviewed final PDF is rendered below.'
        }
        Invoke-Checked { & $bundledPython (Join-Path $presentationsSkillDir 'container_tools\render_slides.py') '.\docs\summary\research_summary.pdf' --output_dir '.\tmp\phase7b\rendered-pdf' } 'Phase 7B PDF render failed'
        Invoke-Checked { & $bundledPython (Join-Path $presentationsSkillDir 'container_tools\slides_test.py') '.\presentation\final_presentation.pptx' } 'Phase 7B slide overflow check failed'
    }

    $summaryCode = @'
import json
import re
import sys
from pathlib import Path
from xml.etree import ElementTree
from zipfile import ZipFile
from pypdf import PdfReader

root = Path(sys.argv[1])
pptx = root / 'presentation/final_presentation.pptx'
docx = root / 'docs/summary/research_summary.docx'
pdf = root / 'docs/summary/research_summary.pdf'
with ZipFile(pptx) as archive:
    names = archive.namelist()
    slides = [name for name in names if re.fullmatch(r'ppt/slides/slide\d+\.xml', name)]
    notes = [name for name in names if re.fullmatch(r'ppt/notesSlides/notesSlide\d+\.xml', name)]
    pptx_text = '\n'.join(' '.join(ElementTree.fromstring(archive.read(name)).itertext()) for name in names if name.endswith('.xml'))
with ZipFile(docx) as archive:
    docx_text = '\n'.join(' '.join(ElementTree.fromstring(archive.read(name)).itertext()) for name in archive.namelist() if name.endswith('.xml'))
reader = PdfReader(pdf)
pdf_text = '\n'.join((page.extract_text() or '') for page in reader.pages)
forbidden = ('{{', '}}', 'Lorem ipsum', 'Title here', 'placeholder')
placeholders = sum(text.lower().count(token.lower()) for token in forbidden for text in (pptx_text, docx_text, pdf_text))
print(json.dumps({
    'slides': len(slides),
    'notes': len(notes),
    'notesWithSources': sum('[Sources]' in ' '.join(ElementTree.fromstring(ZipFile(pptx).read(name)).itertext()) for name in notes),
    'pdfPages': len(reader.pages),
    'placeholders': placeholders,
}))
'@
    $summary = (& $bundledPython -c $summaryCode $projectRoot) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "Phase 7B output structural summary failed with exit code $LASTEXITCODE" }
    if ($summary.slides -ne 10 -or $summary.notes -ne 10 -or $summary.notesWithSources -ne 10 -or $docxPageCount -ne 1 -or $summary.pdfPages -ne 1 -or $summary.placeholders -ne 0) {
        throw "Phase 7B output contract failed: $($summary | ConvertTo-Json -Compress)"
    }
    Write-Output 'PHASE7B_VERIFIED slides=10 notes=10 summary_docx_pages=1 summary_pdf_pages=1 placeholders=0'
}
finally {
    $env:NODE_PATH = $originalNodePath
    $env:PATH = $originalPath
    $env:RUNTIME_NODE = $originalRuntimeNode
    $env:RUNTIME_NODE_MODULES = $originalRuntimeNodeModules
    $env:RUNTIME_BIN_DIR = $originalRuntimeBinDir
    Pop-Location
}
