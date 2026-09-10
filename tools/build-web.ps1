param(
    [string]$Godot = 'C:\Users\immuS\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force (Join-Path $projectRoot 'build') | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot 'build/.gdignore') -Value ''
$template = Join-Path $projectRoot 'build/templates/web_nothreads_release.zip'
if (-not (Test-Path -LiteralPath $template)) {
    & (Join-Path $PSScriptRoot 'fetch-web-template.ps1')
}
$webRoot = Join-Path $projectRoot 'build/web'
New-Item -ItemType Directory -Force $webRoot | Out-Null
& $Godot --headless --path $projectRoot --export-release Web (Join-Path $webRoot 'index.html') --log-file (Join-Path $projectRoot 'build/web-export.log')
if ($LASTEXITCODE -ne 0) { throw "Godot export failed: $LASTEXITCODE" }
foreach ($required in @('index.html', 'index.js', 'index.wasm', 'index.pck')) {
    if (-not (Test-Path -LiteralPath (Join-Path $webRoot $required))) { throw "Missing export file: $required" }
}
$archive = Join-Path $projectRoot 'build/NEATDrone-itch-web.zip'
$files = Get-ChildItem -LiteralPath $webRoot -File | Where-Object { $_.Extension -in @('.html', '.js', '.wasm', '.pck', '.png', '.svg') }
Compress-Archive -LiteralPath $files.FullName -DestinationPath $archive -Force
Write-Output "itch.io upload: $archive"
