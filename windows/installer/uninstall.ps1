#requires -Version 5.1
<#
.SYNOPSIS
  卸载「企划星 · 桌面日历清单」用户级安装。
  会恢复系统原壁纸；用户数据默认保留（-RemoveData 才清除）。
#>
[CmdletBinding()]
param(
  [string] $InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\PlanstarDesktopApp'),
  [switch] $RemoveData
)

$ErrorActionPreference = 'Continue'

$ShortcutName = '企划星 桌面日历清单'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PlanstarDesktopApp'

Write-Host '==> 停止运行中的实例…'
Get-Process -Name 'planstar_desktop_app' -ErrorAction SilentlyContinue | ForEach-Object {
  $p = $null
  try { $p = $_.Path } catch { }
  if ($p -and $p.StartsWith($InstallRoot, [StringComparison]::OrdinalIgnoreCase)) {
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
  }
}

$shortcutPaths = @(
  (Join-Path (Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs') "$ShortcutName.lnk"),
  (Join-Path ([Environment]::GetFolderPath('Desktop')) "$ShortcutName.lnk")
)
foreach ($path in $shortcutPaths) {
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Force
    Write-Host "    已删除快捷方式：$path"
  }
}

if (Test-Path -LiteralPath $UninstallKey) {
  Remove-Item -LiteralPath $UninstallKey -Recurse -Force
  Write-Host '    已删除卸载注册表项'
}

# 首次渲染壁纸时记录了系统原壁纸，卸载时还回去。
Write-Host '==> 恢复原始桌面壁纸…'
$originalFile = Get-ChildItem -Path $env:APPDATA, $env:LOCALAPPDATA -Recurse -Filter 'original_wallpaper.txt' -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($originalFile) {
  $originalPath = (Get-Content -LiteralPath $originalFile.FullName -Raw).Trim()
  if ($originalPath -and (Test-Path -LiteralPath $originalPath)) {
    Add-Type -Namespace Planstar -Name Wallpaper -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool SystemParametersInfo(int action, int param, string path, int flags);'
    $restored = [Planstar.Wallpaper]::SystemParametersInfo(20, 0, $originalPath, 3)
    if ($restored) {
      Write-Host "    已恢复：$originalPath"
    } else {
      Write-Warning '    调用 SPI_SETDESKWALLPAPER 失败，请手动在设置里重选壁纸'
    }
  }
}

if (Test-Path -LiteralPath $InstallRoot) {
  Remove-Item -LiteralPath $InstallRoot -Recurse -Force
  Write-Host "    已删除程序目录：$InstallRoot"
}

if ($RemoveData) {
  $candidates = @(
    (Join-Path $env:APPDATA 'planstar_desktop_app'),
    (Join-Path $env:LOCALAPPDATA 'planstar_desktop_app')
  )
  foreach ($path in $candidates) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  }
  Write-Host '    已删除本地用户数据'
} else {
  Write-Host '用户数据已保留（如需清除请加 -RemoveData 参数）。'
}

Write-Host '卸载完成。'
