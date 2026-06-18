<#
.SYNOPSIS
  Compress oversized PNG illustrations under docs/images.

.DESCRIPTION
  Scans the images directory for PNG files larger than a threshold (default 2.5 MB)
  and re-encodes them using ffmpeg 256-color palette quantization with dithering
  (the same technique pngquant uses). The watercolor illustrations in this tutorial
  compress well this way with no visible banding at display size.

  Requires ffmpeg on PATH. Only replaces the original when the result is both
  smaller than the original AND under the threshold; otherwise the original is kept.

.EXAMPLE
  pwsh -File scripts/compress-images.ps1
  pwsh -File scripts/compress-images.ps1 -MaxMB 2.0 -ImagesDir docs/images
#>
[CmdletBinding()]
param(
    [string]$ImagesDir = (Join-Path $PSScriptRoot '..\docs\images'),
    [double]$MaxMB = 2.5
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    throw 'ffmpeg not found on PATH. Install it (e.g. choco install ffmpeg) and retry.'
}

$ImagesDir = (Resolve-Path $ImagesDir).Path
$threshold = $MaxMB * 1MB

$oversized = Get-ChildItem -Path $ImagesDir -Filter '*.png' -File -Recurse |
    Where-Object { $_.Length -gt $threshold } |
    Sort-Object Length -Descending

if (-not $oversized) {
    Write-Host "No PNG larger than $MaxMB MB found under $ImagesDir." -ForegroundColor Green
    return
}

Write-Host ("Found {0} image(s) over {1} MB.`n" -f $oversized.Count, $MaxMB) -ForegroundColor Cyan

foreach ($img in $oversized) {
    $palette = Join-Path $env:TEMP ("pal-" + [guid]::NewGuid().ToString('N') + '.png')
    $out     = Join-Path $env:TEMP ("out-" + [guid]::NewGuid().ToString('N') + '.png')
    try {
        & ffmpeg -y -hide_banner -loglevel error -i $img.FullName -vf 'palettegen=stats_mode=full' $palette
        & ffmpeg -y -hide_banner -loglevel error -i $img.FullName -i $palette -lavfi 'paletteuse=dither=sierra2_4a' $out

        $newLen = (Get-Item $out).Length
        $oldMB = $img.Length / 1MB
        $newMB = $newLen / 1MB

        if ($newLen -lt $img.Length -and $newLen -le $threshold) {
            Copy-Item -Path $out -Destination $img.FullName -Force
            Write-Host ("  [OK]   {0,-40} {1,6:N2} MB -> {2,6:N2} MB" -f $img.Name, $oldMB, $newMB) -ForegroundColor Green
        }
        else {
            Write-Host ("  [SKIP] {0,-40} {1,6:N2} MB -> {2,6:N2} MB (no usable gain)" -f $img.Name, $oldMB, $newMB) -ForegroundColor Yellow
        }
    }
    finally {
        Remove-Item $palette, $out -ErrorAction SilentlyContinue
    }
}

Write-Host "`nDone." -ForegroundColor Cyan
