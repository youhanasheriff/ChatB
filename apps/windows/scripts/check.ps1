param([string]$BinaryDir = "target/release", [string]$Output = "dist/validation")
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Output | Out-Null
$gui = (Resolve-Path "$BinaryDir/bitchat-desktop-windows.exe").Path
$cli = (Resolve-Path "$BinaryDir/bitchat-scan.exe").Path
& $cli --version
if ($LASTEXITCODE -ne 0) { throw 'Version check failed' }
& $cli --scan --seconds 0
if ($LASTEXITCODE -eq 0) { throw 'Invalid duration accepted' }
$smoke = Start-Process $gui -ArgumentList '--smoke-test' -PassThru
if (-not $smoke.WaitForExit(15000)) { $smoke.Kill(); throw 'UI smoke test hung' }
if ($smoke.ExitCode -ne 0) { throw 'UI smoke test failed' }
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class NativeCheck {
 [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
 [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags);
 public struct Rect { public int Left, Top, Right, Bottom; }
}
'@
function Read-Text($h) { $s = [Text.StringBuilder]::new(2048); [NativeCheck]::GetWindowText($h,$s,$s.Capacity) | Out-Null; return $s.ToString() }
function Click($h) { [NativeCheck]::SendMessage($h,0xF5,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null; Start-Sleep -Milliseconds 500 }
function Capture($h, $path) {
 $r = [NativeCheck+Rect]::new()
 [NativeCheck]::GetWindowRect($h,[ref]$r) | Out-Null
 $bitmap = [Drawing.Bitmap]::new(($r.Right-$r.Left),($r.Bottom-$r.Top))
 $graphics = [Drawing.Graphics]::FromImage($bitmap)
 $dc = $graphics.GetHdc()
 try { if (-not [NativeCheck]::PrintWindow($h,$dc,2)) { throw 'PrintWindow failed' } }
 finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
 try { $bitmap.Save([IO.Path]::GetFullPath($path),[Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
}
$app = Start-Process $gui -PassThru
try {
 $deadline = [DateTime]::UtcNow.AddSeconds(15)
 do { Start-Sleep -Milliseconds 200; $app.Refresh() } while ($app.MainWindowHandle -eq 0 -and [DateTime]::UtcNow -lt $deadline -and -not $app.HasExited)
 $h = $app.MainWindowHandle
 if ($h -eq 0) { throw 'Native window did not appear' }
 $button = [NativeCheck]::GetDlgItem($h,13)
 $network = [NativeCheck]::GetDlgItem($h,12)
 $status = [NativeCheck]::GetDlgItem($h,14)
 $list = [NativeCheck]::GetDlgItem($h,15)
 if ((Read-Text $status) -notmatch '^Ready') { throw 'Missing initial state' }
 if ((Read-Text $button) -ne '&Start scan') { throw 'Missing scan button' }
 Capture $h "$Output/windows-discovery.png"
 Click $network
 if ([NativeCheck]::SendMessage($network,0xF0,[IntPtr]::Zero,[IntPtr]::Zero).ToInt64() -ne 1) { throw 'Testnet toggle failed' }
 Click $network
 if ([NativeCheck]::SendMessage($network,0xF0,[IntPtr]::Zero,[IntPtr]::Zero).ToInt64() -ne 0) { throw 'Mainnet toggle failed' }
 # Exercise actual WinRT start/error/stop and retry on the hosted runner. It
 # normally has no radio; this check also supports a runner with a working one.
 foreach ($attempt in 1..2) {
   Click $button
   Start-Sleep -Seconds 2
   $text = Read-Text $status
   Write-Host "Scan attempt ${attempt}: $text"
   if ($text -match '^Scanning') {
     if ([NativeCheck]::IsWindowEnabled($network)) { throw 'Network can change during scan' }
     Click $button
     if ((Read-Text $status) -notmatch '^Scan stopped') { throw 'Stop did not complete' }
   } elseif ($text -notmatch '(?i)bluetooth|adapter|discovery failed') { throw "Unexpected scan outcome: $text" }
   if (-not [NativeCheck]::IsWindowEnabled($network)) { throw 'Network disabled after stop/failure' }
   if ((Read-Text $button) -ne '&Start scan') { throw 'Cannot restart scan' }
 }
 Capture $h "$Output/windows-radio-state.png"
 [NativeCheck]::SetWindowPos($h,[IntPtr]::Zero,0,0,760,560,6) | Out-Null
 Start-Sleep -Milliseconds 500
 Capture $h "$Output/windows-minimum.png"
 [NativeCheck]::PostMessage($h,0x10,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null
 if (-not $app.WaitForExit(10000)) { throw 'Window teardown hung' }
 if ($app.ExitCode -ne 0) { throw 'Window teardown failed' }
} finally { if (-not $app.HasExited) { $app.Kill() } }
Write-Host 'Windows launch, controls, radio outcome, retry, resize and teardown checks passed.'
