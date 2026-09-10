param([int]$Port = 8765, [int]$DebugPort = 9223)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $projectRoot 'build'
$profile = Join-Path $buildRoot ('browser-test-' + [Guid]::NewGuid().ToString('N'))
$downloads = Join-Path $profile 'downloads'
New-Item -ItemType Directory -Force $downloads | Out-Null
$server = $null
$browser = $null
$socket = $null
$script:messageId = 0
$script:browserErrors = [Collections.Generic.List[string]]::new()
$script:consoleMessages = [Collections.Generic.List[string]]::new()
function Send-CDP([string]$Method, [hashtable]$Parameters = @{}) {
    $script:messageId++
    $id = $script:messageId
    $payload = [Text.Encoding]::UTF8.GetBytes((@{id=$id;method=$Method;params=$Parameters} | ConvertTo-Json -Depth 20 -Compress))
    $timeout = [Threading.CancellationTokenSource]::new(30000)
    try {
        $socket.SendAsync([ArraySegment[byte]]::new($payload), [Net.WebSockets.WebSocketMessageType]::Text, $true, $timeout.Token).GetAwaiter().GetResult() | Out-Null
        while ($true) {
            $memory = [IO.MemoryStream]::new()
            try {
                do {
                    $buffer = [byte[]]::new(65536)
                    $received = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $timeout.Token).GetAwaiter().GetResult()
                    $memory.Write($buffer, 0, $received.Count)
                } while (-not $received.EndOfMessage)
                $message = [Text.Encoding]::UTF8.GetString($memory.ToArray()) | ConvertFrom-Json
            } finally { $memory.Dispose() }
            if ($message.method -eq 'Runtime.exceptionThrown') {
                $script:browserErrors.Add(($message.params | ConvertTo-Json -Depth 12 -Compress))
            }
            if ($message.method -eq 'Runtime.consoleAPICalled') {
                $entry = ($message.params.args | ForEach-Object { $_.value }) -join ' '
                $script:consoleMessages.Add($entry)
                if ($message.params.type -eq 'error') { $script:browserErrors.Add($entry) }
            }
            if ($message.id -eq $id) {
                if ($message.error) { throw ($message.error | ConvertTo-Json -Compress) }
                return $message.result
            }
        }
    } finally { $timeout.Dispose() }
}
function Wait-Page([int]$Milliseconds) {
    Send-CDP 'Runtime.evaluate' @{expression="new Promise(resolve => setTimeout(resolve, $Milliseconds))";awaitPromise=$true} | Out-Null
}
function Press-Key([string]$Key, [string]$Code, [int]$VirtualKey) {
    Send-CDP 'Input.dispatchKeyEvent' @{type='keyDown';key=$Key;code=$Code;windowsVirtualKeyCode=$VirtualKey} | Out-Null
    Send-CDP 'Input.dispatchKeyEvent' @{type='keyUp';key=$Key;code=$Code;windowsVirtualKeyCode=$VirtualKey} | Out-Null
    Wait-Page 150
}
try {
    $serverScript = Join-Path $PSScriptRoot 'serve-web.ps1'
    $server = Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', ('"' + $serverScript + '"'), '-Port', $Port) -WindowStyle Hidden -PassThru
    $browser = Start-Process 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' -ArgumentList @('--headless=new', '--no-first-run', '--no-default-browser-check', "--remote-debugging-port=$DebugPort", ('--user-data-dir="' + $profile + '"'), '--window-size=1280,800', 'about:blank') -WindowStyle Hidden -PassThru
    $pages = $null
    for ($attempt=0; $attempt -lt 40; $attempt++) {
        try { $pages = Invoke-RestMethod "http://127.0.0.1:$DebugPort/json/list"; break } catch { Start-Sleep -Milliseconds 250 }
    }
    if (-not $pages) { throw 'Browser debugging interface did not start' }
    $page = $pages | Where-Object { $_.type -eq 'page' } | Select-Object -First 1
    $socket = [Net.WebSockets.ClientWebSocket]::new()
    $socket.ConnectAsync([Uri]$page.webSocketDebuggerUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
    Send-CDP 'Runtime.enable' | Out-Null
    Send-CDP 'Page.enable' | Out-Null
    Send-CDP 'Emulation.setDeviceMetricsOverride' @{width=1280;height=800;deviceScaleFactor=1;mobile=$false} | Out-Null
    Send-CDP 'Browser.setDownloadBehavior' @{behavior='allow';downloadPath=$downloads} | Out-Null
    Send-CDP 'Page.navigate' @{url="http://127.0.0.1:$Port/"} | Out-Null
    Wait-Page 12000
    $state = Send-CDP 'Runtime.evaluate' @{expression='JSON.stringify({loading:!!document.getElementById("status"),canvas:!!document.getElementById("canvas"),threads:GODOT_THREADS_ENABLED})';returnByValue=$true}
    $ready = $state.result.value | ConvertFrom-Json
    if ($ready.loading -or -not $ready.canvas -or $ready.threads) { throw "Web game not ready: $($state.result.value)" }
    Send-CDP 'Runtime.evaluate' @{expression='document.getElementById("canvas").focus()'} | Out-Null
    Press-Key ' ' 'Space' 32
    Send-CDP 'Input.dispatchKeyEvent' @{type='keyDown';key='d';code='KeyD';windowsVirtualKeyCode=68} | Out-Null
    Wait-Page 500
    Send-CDP 'Input.dispatchKeyEvent' @{type='keyUp';key='d';code='KeyD';windowsVirtualKeyCode=68} | Out-Null
    Send-CDP 'Input.dispatchMouseEvent' @{type='mousePressed';x=650;y=350;button='left';clickCount=1} | Out-Null
    Wait-Page 200
    Send-CDP 'Input.dispatchMouseEvent' @{type='mouseReleased';x=650;y=350;button='left';clickCount=1} | Out-Null
    Press-Key 'v' 'KeyV' 86
    Press-Key 'n' 'KeyN' 78
    Press-Key 'n' 'KeyN' 78
    Press-Key 'e' 'KeyE' 69
    Wait-Page 1000
    $championFile = Join-Path $downloads 'neatdrone-champion.json'
    if (-not (Test-Path -LiteralPath $championFile)) { throw 'Browser champion download failed' }
    $champion = Get-Content -Raw -LiteralPath $championFile | ConvertFrom-Json
    if ($champion.inputs -ne 13 -or -not $champion.vision) { throw 'Vision upgrade did not reach the downloaded genome' }
    Press-Key 't' 'KeyT' 84
    Wait-Page 1000
    Press-Key ' ' 'Space' 32
    $shot = Send-CDP 'Page.captureScreenshot' @{format='png'}
    [IO.File]::WriteAllBytes((Join-Path $buildRoot 'web-test.png'), [Convert]::FromBase64String($shot.data))
    [IO.File]::WriteAllLines((Join-Path $buildRoot 'web-console.log'), $script:consoleMessages)
    if ($script:browserErrors.Count) { throw ($script:browserErrors -join "`n") }
    Write-Output 'WEB TEST PASSED: single-threaded startup, keyboard/mouse input, vision upgrade, JSON download and lab rendering.'
    Write-Output "Screenshot: $(Join-Path $buildRoot 'web-test.png')"
} finally {
    if ($socket) { $socket.Dispose() }
    if ($browser -and -not $browser.HasExited) { Stop-Process -Id $browser.Id -ErrorAction SilentlyContinue }
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -ErrorAction SilentlyContinue }
}
