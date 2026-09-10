param([int]$Port = 8765)
$ErrorActionPreference = 'Stop'
$webRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path $PSScriptRoot -Parent) 'build/web'))
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Output "Preview: http://127.0.0.1:$Port"
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 5000
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
            $line = $reader.ReadLine()
            if (-not $line) { continue }
            while ($reader.ReadLine()) {}
            $relative = [Uri]::UnescapeDataString(($line.Split(' ')[1].Split('?')[0])).TrimStart('/')
            if (-not $relative) { $relative = 'index.html' }
            $path = [IO.Path]::GetFullPath((Join-Path $webRoot $relative))
            if (-not $path.StartsWith($webRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($path)) {
                $status = '404 Not Found'; $body = [Text.Encoding]::UTF8.GetBytes('Not found'); $mime = 'text/plain'
            } else {
                $status = '200 OK'; $body = [IO.File]::ReadAllBytes($path)
                $mime = switch ([IO.Path]::GetExtension($path)) {
                    '.html' { 'text/html; charset=utf-8' }
                    '.js' { 'application/javascript' }
                    '.wasm' { 'application/wasm' }
                    '.png' { 'image/png' }
                    default { 'application/octet-stream' }
                }
            }
            $header = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: $mime`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nCache-Control: no-cache`r`n`r`n")
            $stream.Write($header, 0, $header.Length)
            if (-not $line.StartsWith('HEAD ')) { $stream.Write($body, 0, $body.Length) }
        } catch { Write-Warning $_.Exception.Message } finally { $client.Dispose() }
    }
} finally { $listener.Stop() }
