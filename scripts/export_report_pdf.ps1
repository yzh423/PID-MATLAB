param(
    [string]$DocxPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'docs\report\technical_report.docx'),
    [string]$PdfPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'docs\report\technical_report.pdf')
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Split-Path -Parent $PSScriptRoot)).Path
$reportRoot = (Resolve-Path (Join-Path $projectRoot 'docs\report')).Path
$resolvedDocx = (Resolve-Path -LiteralPath $DocxPath).Path
$resolvedPdf = [IO.Path]::GetFullPath($PdfPath)
$resolvedPdfParent = [IO.Path]::GetDirectoryName($resolvedPdf)

if ([IO.Path]::GetExtension($resolvedDocx) -ine '.docx') {
    throw 'Input path must use the .docx extension.'
}
if ([IO.Path]::GetExtension($resolvedPdf) -ine '.pdf') {
    throw 'Output path must use the .pdf extension.'
}
if ([StringComparer]::OrdinalIgnoreCase.Equals($resolvedDocx, $resolvedPdf)) {
    throw 'DOCX input and PDF output paths must differ.'
}
if (-not [StringComparer]::OrdinalIgnoreCase.Equals($resolvedPdfParent, $reportRoot)) {
    throw "PDF output must stay directly inside $reportRoot"
}

$temporaryPdf = Join-Path $reportRoot ('.technical_report.' + [Guid]::NewGuid().ToString('N') + '.tmp.pdf')
$normalizedPdf = Join-Path $reportRoot ('.technical_report.' + [Guid]::NewGuid().ToString('N') + '.normalized.pdf')
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
    if ($null -ne $document) {
        $document.Close(0)
    }
    if ($null -ne $word) {
        $word.Quit()
    }
    if ($null -ne $document) {
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)
    }
    if ($null -ne $word) {
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()

    if (-not $exportSucceeded -and (Test-Path -LiteralPath $temporaryPdf)) {
        $failedFile = Get-Item -LiteralPath $temporaryPdf
        if ($failedFile.Length -eq 0) {
            [IO.File]::Delete($temporaryPdf)
        }
    }
}

$temporaryFile = Get-Item -LiteralPath $temporaryPdf
if ($temporaryFile.Length -le 0) {
    throw 'Word created an empty PDF.'
}
$pythonExecutable = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path -LiteralPath $pythonExecutable -PathType Leaf)) {
    throw "Bundled Python executable not found: $pythonExecutable"
}
& $pythonExecutable (Join-Path $PSScriptRoot 'normalize_report_pdf.py') `
    --input $temporaryPdf `
    --output $normalizedPdf `
    --project-root $projectRoot
if ($LASTEXITCODE -ne 0) {
    throw "PDF normalization failed with exit code $LASTEXITCODE"
}
[IO.File]::Delete($temporaryPdf)
[IO.File]::Move($normalizedPdf, $resolvedPdf, $true)

$manifestPath = Join-Path $reportRoot 'build_manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Build manifest does not exist: $manifestPath"
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or $null -eq $manifest.outputs) {
    throw 'Build manifest has an unsupported structure.'
}
$relativePdf = [IO.Path]::GetRelativePath($projectRoot, $resolvedPdf).Replace('\', '/')
$pdfRecord = [PSCustomObject]@{
    path = $relativePdf
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPdf).Hash.ToLowerInvariant()
}
$manifest.outputs = @($manifest.outputs | Where-Object { $_.path -ne $relativePdf }) + @($pdfRecord)
$temporaryManifest = Join-Path $reportRoot ('.build_manifest.' + [Guid]::NewGuid().ToString('N') + '.tmp.json')
$encoding = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText(
    $temporaryManifest,
    (($manifest | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"),
    $encoding
)
[IO.File]::Move($temporaryManifest, $manifestPath, $true)

Write-Output "Exported report PDF: $resolvedPdf"
