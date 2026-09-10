param([string]$Version = '4.7.2-stable')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.IO.Compression
$projectRoot = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $projectRoot 'build/templates'
New-Item -ItemType Directory -Force $destination | Out-Null
$release = Invoke-RestMethod "https://api.github.com/repos/godotengine/godot-builds/releases/tags/$Version"
$asset = $release.assets | Where-Object { $_.name -eq "Godot_v${Version}_export_templates.tpz" }
if (-not $asset) { throw "Official export templates not found for $Version" }
$client = [Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromMinutes(5)
function Read-Range([long]$Start, [long]$End) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, $asset.browser_download_url)
    $request.Headers.Range = [Net.Http.Headers.RangeHeaderValue]::new($Start, $End)
    $response = $client.SendAsync($request, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    try {
        if ([int]$response.StatusCode -ne 206) { throw "Server did not accept partial download: $($response.StatusCode)" }
        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        if ($bytes.Length -ne $End - $Start + 1) { throw 'Incomplete partial download' }
        return ,$bytes
    } finally { $response.Dispose(); $request.Dispose() }
}
try {
    # Read ZIP central directory, then fetch only the nested Web release ZIP.
    # Avoids downloading the 1.2 GB package for unrelated export platforms.
    $tailStart = [long]$asset.size - 131072
    $tail = Read-Range $tailStart ($asset.size - 1)
    $endRecord = $tail.Length - 22
    while ($endRecord -ge 0 -and [BitConverter]::ToUInt32($tail, $endRecord) -ne 0x06054b50) { $endRecord-- }
    if ($endRecord -lt 0) { throw 'ZIP central directory not found' }
    $directoryOffset = [BitConverter]::ToUInt32($tail, $endRecord + 16)
    $cursor = [int]($directoryOffset - $tailStart)
    $found = $false
    while ($cursor -ge 0 -and $cursor -lt $endRecord -and [BitConverter]::ToUInt32($tail, $cursor) -eq 0x02014b50) {
        $nameLength = [BitConverter]::ToUInt16($tail, $cursor + 28)
        $extraLength = [BitConverter]::ToUInt16($tail, $cursor + 30)
        $commentLength = [BitConverter]::ToUInt16($tail, $cursor + 32)
        $name = [Text.Encoding]::UTF8.GetString($tail, $cursor + 46, $nameLength)
        if ($name -eq 'templates/web_nothreads_release.zip') {
            $compressedLength = [BitConverter]::ToUInt32($tail, $cursor + 20)
            $method = [BitConverter]::ToUInt16($tail, $cursor + 10)
            $localOffset = [BitConverter]::ToUInt32($tail, $cursor + 42)
            $header = Read-Range $localOffset ($localOffset + 29)
            $dataOffset = $localOffset + 30 + [BitConverter]::ToUInt16($header, 26) + [BitConverter]::ToUInt16($header, 28)
            $payload = Read-Range $dataOffset ($dataOffset + $compressedLength - 1)
            $outputPath = Join-Path $destination 'web_nothreads_release.zip'
            if ($method -eq 0) {
                [IO.File]::WriteAllBytes($outputPath, $payload)
            } elseif ($method -eq 8) {
                $source = [IO.MemoryStream]::new($payload, $false)
                $inflate = [IO.Compression.DeflateStream]::new($source, [IO.Compression.CompressionMode]::Decompress)
                $file = [IO.File]::Create($outputPath)
                try { $inflate.CopyTo($file) } finally { $file.Dispose(); $inflate.Dispose(); $source.Dispose() }
            } else { throw "Unsupported ZIP method $method" }
            Write-Output "Web template: $outputPath"
            $found = $true
            break
        }
        $cursor += 46 + $nameLength + $extraLength + $commentLength
    }
    if (-not $found) { throw 'Single-threaded Web release template missing in official archive' }
} finally { $client.Dispose() }
