#requires -Version 5.1
<#
.SYNOPSIS
  Verifies the Vectra-style desktop widget layer on the running app.

  Checks: WS_POPUP + WS_EX_TOOLWINDOW styles, window region (card clipping),
  bottom-most Z-order, and WindowFromPoint hit-testing inside/outside the card.
#>
param()

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class DesktopProbe {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }

  public delegate bool EnumProc(IntPtr h, IntPtr l);

  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtr(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int GetWindowRgn(IntPtr h, IntPtr rgn);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateRectRgn(int l, int t, int r, int b);
  [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);
  [DllImport("gdi32.dll")] public static extern int GetRgnBox(IntPtr rgn, out RECT r);
  [DllImport("gdi32.dll")] public static extern bool PtInRegion(IntPtr rgn, int x, int y);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);

  public static string ClassOf(IntPtr h) {
    var sb = new StringBuilder(256);
    GetClassName(h, sb, 256);
    return sb.ToString();
  }

  public static List<IntPtr> VisibleTopLevel() {
    var list = new List<IntPtr>();
    EnumWindows((h, l) => { if (IsWindowVisible(h)) list.Add(h); return true; }, IntPtr.Zero);
    return list;
  }

  public static List<IntPtr> AllTopLevel() {
    var list = new List<IntPtr>();
    EnumWindows((h, l) => { list.Add(h); return true; }, IntPtr.Zero);
    return list;
  }

  public static string Describe(IntPtr h) {
    long style = GetWindowLongPtr(h, -16).ToInt64();
    long ex = GetWindowLongPtr(h, -20).ToInt64();
    IntPtr rgn = CreateRectRgn(0, 0, 0, 0);
    int regionType = GetWindowRgn(h, rgn);
    DeleteObject(rgn);
    RECT r;
    GetWindowRect(h, out r);
    return "hwnd=" + h.ToInt64() +
           " style=0x" + style.ToString("X") +
           " ex=0x" + ex.ToString("X") +
           " region=" + regionType +
           " rect=" + r.L + "," + r.T + "," + (r.R - r.L) + "x" + (r.B - r.T);
  }

  public static int RegionType(IntPtr h) {
    IntPtr rgn = CreateRectRgn(0, 0, 0, 0);
    int t = GetWindowRgn(h, rgn);
    DeleteObject(rgn);
    return t;
  }

  public static string PointTests(IntPtr h, int[] points) {
    IntPtr rgn = CreateRectRgn(0, 0, 0, 0);
    GetWindowRgn(h, rgn);
    var sb = new StringBuilder();
    for (int i = 0; i < points.Length; i += 2) {
      bool inside = PtInRegion(rgn, points[i], points[i + 1]);
      sb.Append("(" + points[i] + "," + points[i + 1] + ")=" +
                (inside ? "HIT widget" : "PASS-THROUGH to desktop") + "  ");
    }
    DeleteObject(rgn);
    return sb.ToString();
  }

  public static string RegionBox(IntPtr h) {
    IntPtr rgn = CreateRectRgn(0, 0, 0, 0);
    GetWindowRgn(h, rgn);
    RECT r;
    GetRgnBox(rgn, out r);
    DeleteObject(rgn);
    return r.L + "," + r.T + " -> " + r.R + "," + r.B;
  }

  public static string Hit(int x, int y) {
    POINT p = new POINT { X = x, Y = y };
    IntPtr h = WindowFromPoint(p);
    IntPtr root = GetAncestor(h, 2); // GA_ROOT
    return "point=(" + x + "," + y + ") hwnd=" + h.ToInt64() +
           " class=" + ClassOf(h) + " root=" + root.ToInt64();
  }
}
'@

$visible = [DesktopProbe]::VisibleTopLevel()
Write-Host "visible top-level windows: $($visible.Count)"
$allFlutters = @([DesktopProbe]::AllTopLevel() | Where-Object {
  $c = [DesktopProbe]::ClassOf($_)
  $c -eq 'FLUTTER_RUNNER_WIN32_WINDOW' -or
    $c -eq 'FLUTTER_MULTI_WINDOW_WIN32_WINDOW'
})
Write-Host "all Flutter windows (incl. hidden): $($allFlutters.Count)"
foreach ($h in $allFlutters) {
  Write-Host ("  hidden? {0} {1}" -f `
    (-not [DesktopProbe]::IsWindowVisible($h)), [DesktopProbe]::Describe($h))
}
$flutters = @($visible | Where-Object {
  $c = [DesktopProbe]::ClassOf($_)
  $c -eq 'FLUTTER_RUNNER_WIN32_WINDOW' -or
    $c -eq 'FLUTTER_MULTI_WINDOW_WIN32_WINDOW'
})
Write-Host "visible Flutter windows: $($flutters.Count)"
for ($i = 0; $i -lt $flutters.Count; $i++) {
  Write-Host ("  [{0}] {1}" -f $i, [DesktopProbe]::Describe($flutters[$i]))
}

$last = $visible.Count - 1
if ($last -ge 0) {
  Write-Host ("bottom-most visible window: {0} ({1})" -f `
    $visible[$last].ToInt64(), [DesktopProbe]::ClassOf($visible[$last]))
}

$overlays = @($allFlutters | Where-Object {
  [DesktopProbe]::RegionType($_) -ne 0
})
Write-Host "overlay windows (region clipped): $($overlays.Count)"
foreach ($h in $overlays) {
  Write-Host ("  {0} regionBox={1}" -f `
    $h.ToInt64(), [DesktopProbe]::RegionBox($h))
  Write-Host ("  hit semantics: {0}" -f `
    [DesktopProbe]::PointTests($h, [int[]]@(60, 60, 300, 300, 448, 378, 900, 300)))
  $index = 0
  foreach ($v in $visible) {
    if ($v.ToInt64() -eq $h.ToInt64()) { break }
    $index++
  }
  Write-Host ("  Z-order position: {0} / {1} visible windows (larger = lower)" -f `
    $index, $visible.Count)
}

Write-Host '--- WindowFromPoint (informational; foreground windows may occlude) ---'
foreach ($point in @(@(60, 60), @(300, 300), @(448, 378))) {
  Write-Host ([DesktopProbe]::Hit($point[0], $point[1]))
}
