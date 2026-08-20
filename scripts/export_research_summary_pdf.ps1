param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$DocxPath,
    [string]$PdfPath,
    [switch]$UseWordCom
)

$ErrorActionPreference = 'Stop'

function Close-WordDocument {
    param($Document)
    if ($null -eq $Document) { return }
    try { $Document.Close(0) } catch { Write-Verbose "Owned Word document close failed: $($_.Exception.Message)" }
}

function Quit-WordApplication {
    param($Word)
    if ($null -eq $Word) { return }
    try { $Word.Quit() } catch { Write-Verbose "Owned Word application quit failed: $($_.Exception.Message)" }
}

function Release-ComReference {
    param($Reference)
    if ($null -eq $Reference) { return }
    try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Reference) } catch { Write-Verbose "Owned COM release failed: $($_.Exception.Message)" }
}

function Remove-TaskOwnedTemporaryPdf {
    param([string]$Path, [string]$SummaryRoot)
    $resolvedRoot = [IO.Path]::GetFullPath($SummaryRoot)
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    $name = [IO.Path]::GetFileName($resolvedPath)
    if ([IO.Path]::GetDirectoryName($resolvedPath) -ine $resolvedRoot -or $name -notmatch '^\.research_summary\.[0-9a-f]{32}\.tmp\.pdf$') {
        throw "Refusing to delete a non-owned temporary PDF: $resolvedPath"
    }
    if (Test-Path -LiteralPath $resolvedPath) {
        [IO.File]::Delete($resolvedPath)
    }
}

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
try {
    if ($UseWordCom) {
        $word = $null
        $document = $null
        try {
            $word = New-Object -ComObject Word.Application
            $word.Visible = $false
            $word.DisplayAlerts = 0
            $document = $word.Documents.OpenNoRepairDialog($resolvedDocx, $false, $true, $false)
            $document.ExportAsFixedFormat($temporaryPdf, 17)
        }
        finally {
            try { Close-WordDocument -Document $document } finally {
                try { Quit-WordApplication -Word $word } finally {
                    try { Release-ComReference -Reference $document } finally {
                        Release-ComReference -Reference $word
                        [GC]::Collect()
                        [GC]::WaitForPendingFinalizers()
                    }
                }
            }
        }
    }
    else {
        $pythonExecutable = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
        if (-not (Test-Path -LiteralPath $pythonExecutable -PathType Leaf)) { throw "Bundled Python executable not found: $pythonExecutable" }
        & $pythonExecutable (Join-Path $PSScriptRoot 'build_research_summary_pdf.py') --project-root $resolvedProjectRoot --output $temporaryPdf
        if ($LASTEXITCODE -ne 0) { throw "Deterministic PDF build failed with exit code $LASTEXITCODE" }
    }

    if (-not (Test-Path -LiteralPath $temporaryPdf) -or (Get-Item -LiteralPath $temporaryPdf).Length -le 0) { throw 'PDF exporter created an empty PDF.' }
    $pythonExecutable = 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    if (-not (Test-Path -LiteralPath $pythonExecutable -PathType Leaf)) { throw "Bundled Python executable not found: $pythonExecutable" }
    & $pythonExecutable (Join-Path $PSScriptRoot 'normalize_research_summary_pdf.py') --input $temporaryPdf --output $resolvedPdf --project-root $resolvedProjectRoot
    if ($LASTEXITCODE -ne 0) { throw "PDF normalization failed with exit code $LASTEXITCODE" }
    Write-Output "Exported research summary PDF: $resolvedPdf"
}
finally {
    Remove-TaskOwnedTemporaryPdf -Path $temporaryPdf -SummaryRoot $summaryRoot
}
