param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$DocxPath,
    [string]$PdfPath,
    [switch]$UseWordCom
)

$ErrorActionPreference = 'Stop'
$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$summaryRoot = (Resolve-Path -LiteralPath (Join-Path $resolvedProjectRoot 'docs\summary')).Path
if ([string]::IsNullOrWhiteSpace($DocxPath)) {
    $DocxPath = Join-Path $summaryRoot 'research_summary.docx'
}
if ([string]::IsNullOrWhiteSpace($PdfPath)) {
    $PdfPath = Join-Path $summaryRoot 'research_summary.pdf'
}
$resolvedDocx = (Resolve-Path -LiteralPath $DocxPath).Path
$resolvedPdf = [IO.Path]::GetFullPath($PdfPath)

if ([IO.Path]::GetExtension($resolvedDocx) -ine '.docx') { throw 'Input path must use the .docx extension.' }
if ([IO.Path]::GetExtension($resolvedPdf) -ine '.pdf') { throw 'Output path must use the .pdf extension.' }
if ([StringComparer]::OrdinalIgnoreCase.Equals($resolvedDocx, $resolvedPdf)) { throw 'DOCX input and PDF output paths must differ.' }
foreach ($path in @($resolvedDocx, $resolvedPdf)) {
    $fullPath = [IO.Path]::GetFullPath($path)
    if ([IO.Path]::GetDirectoryName($fullPath) -ine $summaryRoot) { throw "Output and input paths must stay directly inside $summaryRoot" }
}

$temporaryPdf = Join-Path $summaryRoot ('.research_summary.' + [Guid]::NewGuid().ToString('N') + '.tmp.pdf')
if ($UseWordCom) {
    $word = $null
    $document = $null
    $exportSucceeded = $false
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $document = $word.Documents.OpenNoRepairDialog($resolvedDocx, $false, $true, $false)
        $document.ExportAsFixedFormat($temporaryPdf, 17)
        $exportSucceeded = $true
    }
    finally {
        if ($null -ne $document) { $document.Close(0) }
        if ($null -ne $word) { $word.Quit() }
        if ($null -ne $document) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document) }
        if ($null -ne $word) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        if (-not $exportSucceeded -and (Test-Path -LiteralPath $temporaryPdf)) {
            $failedFile = Get-Item -LiteralPath $temporaryPdf
            if ($failedFile.Length -eq 0) { [IO.File]::Delete($temporaryPdf) }
        }
    }
}
else {
    $pythonExecutable = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    if (-not (Test-Path -LiteralPath $pythonExecutable -PathType Leaf)) { throw "Bundled Python executable not found: $pythonExecutable" }
    & $pythonExecutable (Join-Path $PSScriptRoot 'build_research_summary_pdf.py') --project-root $resolvedProjectRoot --output $temporaryPdf
    if ($LASTEXITCODE -ne 0) { throw "Deterministic PDF build failed with exit code $LASTEXITCODE" }
}

if (-not (Test-Path -LiteralPath $temporaryPdf) -or (Get-Item -LiteralPath $temporaryPdf).Length -le 0) { throw 'Word created an empty PDF.' }
$pythonExecutable = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path -LiteralPath $pythonExecutable -PathType Leaf)) { throw "Bundled Python executable not found: $pythonExecutable" }
& $pythonExecutable (Join-Path $PSScriptRoot 'normalize_research_summary_pdf.py') --input $temporaryPdf --output $resolvedPdf --project-root $resolvedProjectRoot
if ($LASTEXITCODE -ne 0) { throw "PDF normalization failed with exit code $LASTEXITCODE" }
[IO.File]::Delete($temporaryPdf)
Write-Output "Exported research summary PDF: $resolvedPdf"
