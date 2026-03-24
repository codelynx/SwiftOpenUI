# Capture screenshots of all examples on Windows (Win32 backend).
# Uses Win32 FindWindow + GDI+ CopyFromScreen to capture windows as PNG.
#
# Usage:
#   .\screenshots\capture-windows.ps1
#   .\screenshots\capture-windows.ps1 HelloWorld    # capture one example

param(
    [string]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load System.Drawing from the Windows Forms assembly (includes GDI+ Bitmap/PNG support)
Add-Type -AssemblyName System.Windows.Forms

# Win32 API for finding windows and capturing
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32Window {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);

    [DllImport("dwmapi.dll")]
    public static extern int DwmGetWindowAttribute(IntPtr hwnd, int dwAttribute, out RECT pvAttribute, int cbAttribute);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left, Top, Right, Bottom;
    }
}
"@

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outDir = Join-Path $repoRoot "screenshots\windows"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$delay = 5  # seconds to wait for window to appear

# Map of target name -> (screenshot filename, window title)
# Matches macOS capture-macos.sh naming convention
$examples = [ordered]@{
    # Showcase
    "HelloWorld"  = @{ File = "showcase-HelloWorld";  Title = "Hello World" }
    "Stopwatch"   = @{ File = "showcase-Stopwatch";   Title = "Stopwatch" }
    "ColorMixer"  = @{ File = "showcase-ColorMixer";  Title = "Color Studio" }
    "Calculator"  = @{ File = "showcase-Calculator";  Title = "Calculator" }
    "SimplePaint" = @{ File = "showcase-SimplePaint"; Title = "SimplePaint" }
    # Parity
    "ParityViewsBasic"      = @{ File = "parity-ViewsBasic";      Title = "Parity: Views Basic" }
    "ParityViewsLayout"     = @{ File = "parity-ViewsLayout";     Title = "Parity: Views Layout" }
    "ParityViewsContainers" = @{ File = "parity-ViewsContainers"; Title = "Parity: Views Containers" }
    "ParityModifiers"       = @{ File = "parity-Modifiers";       Title = "Parity: Modifiers" }
    "ParityStateData"       = @{ File = "parity-StateData";       Title = "Parity: State & Data" }
    "ParityNavigation"      = @{ File = "parity-Navigation";      Title = "Parity: Navigation" }
    "ParityEnvironment"     = @{ File = "parity-Environment";     Title = "Parity: Environment" }
    "ParityGestures"        = @{ File = "parity-Gestures";        Title = "Parity: Gestures" }
    "ParityAnimation"       = @{ File = "parity-Animation";       Title = "Parity: Animation" }
    "ParityFocus"           = @{ File = "parity-Focus";           Title = "Parity: Focus" }
    "ParityAppStructure"    = @{ File = "parity-AppStructure";    Title = "Parity: App Structure" }
}

function Capture-WindowToPng {
    param([IntPtr]$hwnd, [string]$outPath)

    # GetWindowRect includes the DWM shadow; PrintWindow renders it.
    # DwmGetWindowAttribute(EXTENDED_FRAME_BOUNDS) gives the visible
    # window bounds without shadow. We capture the full window via
    # PrintWindow then crop to the extended frame bounds to remove shadow.
    $fullRect = New-Object Win32Window+RECT
    [Win32Window]::GetWindowRect($hwnd, [ref]$fullRect) | Out-Null

    $fullW = $fullRect.Right - $fullRect.Left
    $fullH = $fullRect.Bottom - $fullRect.Top
    if ($fullW -le 0 -or $fullH -le 0) { return $false }

    # Capture the full window (including shadow) via PrintWindow
    $fullBmp = New-Object System.Drawing.Bitmap($fullW, $fullH)
    $graphics = [System.Drawing.Graphics]::FromImage($fullBmp)
    $hdc = $graphics.GetHdc()
    [Win32Window]::PrintWindow($hwnd, $hdc, 2) | Out-Null
    $graphics.ReleaseHdc($hdc)
    $graphics.Dispose()

    # Get the visible bounds (no shadow) via DWM
    $visRect = New-Object Win32Window+RECT
    $hr = [Win32Window]::DwmGetWindowAttribute($hwnd, 9, [ref]$visRect,
        [System.Runtime.InteropServices.Marshal]::SizeOf($visRect))

    if ($hr -eq 0) {
        # Crop to visible bounds (remove DWM shadow)
        $cropX = $visRect.Left - $fullRect.Left
        $cropY = $visRect.Top - $fullRect.Top
        $cropW = $visRect.Right - $visRect.Left
        $cropH = $visRect.Bottom - $visRect.Top

        if ($cropW -gt 0 -and $cropH -gt 0) {
            $cropRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
            $croppedBmp = $fullBmp.Clone($cropRect, $fullBmp.PixelFormat)
            $croppedBmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $croppedBmp.Dispose()
            $fullBmp.Dispose()
            return $true
        }
    }

    # Fallback: save with shadow
    $fullBmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $fullBmp.Dispose()
    return $true
}

function Capture-One {
    param([string]$TargetName)

    $info = $examples[$TargetName]
    if (-not $info) {
        Write-Host "  Unknown target: $TargetName" -ForegroundColor Red
        return
    }

    $filename = $info.File
    $windowTitle = $info.Title
    $outFile = Join-Path $outDir "$filename.png"

    Write-Host "==> Capturing $TargetName -> $outFile"

    # Build
    Write-Host "    Building..."
    Push-Location $repoRoot
    & swift build --product $TargetName 2>&1 | Out-Null
    Pop-Location

    # Launch the exe directly (swift run wraps it and delays window creation)
    Write-Host "    Launching..."
    $exePath = Join-Path $repoRoot ".build\aarch64-unknown-windows-msvc\debug\$TargetName.exe"
    if (-not (Test-Path $exePath)) {
        $exePath = Join-Path $repoRoot ".build\debug\$TargetName.exe"
    }
    if (-not (Test-Path $exePath)) {
        Write-Host "    ERROR: Binary not found at $exePath" -ForegroundColor Red
        return
    }
    $proc = Start-Process -FilePath $exePath -PassThru -WindowStyle Normal

    # Wait for window to appear
    Start-Sleep -Seconds $delay

    # Find the window by class name + title (avoids matching VS Code tabs)
    $hwnd = [Win32Window]::FindWindow("SwiftOpenUIMainWindow", $windowTitle)
    if ($hwnd -eq [IntPtr]::Zero) {
        # Fallback: try by title only
        $hwnd = [Win32Window]::FindWindow([NullString]::Value, $windowTitle)
    }
    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Host "    Window '$windowTitle' not found, trying process window" -ForegroundColor Yellow
        $proc.Refresh()
        $hwnd = $proc.MainWindowHandle
    }

    if ($hwnd -ne [IntPtr]::Zero) {
        # Bring window to front and give it a moment to render
        [Win32Window]::SetForegroundWindow($hwnd) | Out-Null
        Start-Sleep -Milliseconds 500

        $ok = Capture-WindowToPng -hwnd $hwnd -outPath $outFile
        if ($ok -and (Test-Path $outFile)) {
            $size = (Get-Item $outFile).Length / 1KB
            Write-Host "    Saved: $outFile ($([math]::Round($size, 1)) KB)" -ForegroundColor Green
        } else {
            Write-Host "    WARNING: Failed to capture window" -ForegroundColor Yellow
        }
    } else {
        Write-Host "    WARNING: No window found" -ForegroundColor Yellow
    }

    # Kill the process
    try {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    } catch {}
    Start-Sleep -Milliseconds 500
}

# Main
if ($Target) {
    Capture-One $Target
} else {
    foreach ($name in $examples.Keys) {
        Capture-One $name
        Start-Sleep -Seconds 1
    }
    Write-Host ""
    Write-Host "Done. Screenshots saved to $outDir\"
    Get-ChildItem $outDir -Filter "*.png" | Format-Table Name, @{N="Size";E={"{0:N1} KB" -f ($_.Length/1KB)}}
}
