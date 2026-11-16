#requires -Version 5.1
<#
.SYNOPSIS
  Per-user installation of "企划星 · 桌面日历清单" (Flutter Windows Release build).

.DESCRIPTION
  No administrator rights required. The payload is copied to
  %LOCALAPPDATA%\Programs\PlanstarDesktopApp, Start menu / Desktop shortcuts
  are created (with the AppUserModelID required by Windows toast notifications),
  and a per-user uninstall entry is registered under HKCU.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File windows\installer\install.ps1
#>
[CmdletBinding()]
param(
  [string] $Source = '',
  [string] $InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\PlanstarDesktopApp'),
  [switch] $NoDesktopShortcut,
  [switch] $NoStartMenuShortcut,
  [switch] $Launch
)

$ErrorActionPreference = 'Stop'

$AppName = '企划星 · 桌面日历清单'
$ShortcutName = '企划星 桌面日历清单'
$Publisher = 'Planstar'
$Version = '1.0.0'
$AppUserModelId = 'Planstar.DesktopCalendar.App'
$ExeName = 'planstar_desktop_app.exe'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PlanstarDesktopApp'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

if ([string]::IsNullOrWhiteSpace($Source)) {
  $Source = Join-Path $projectRoot 'build\windows\x64\runner\Release'
}
if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
  throw "Release 构建目录不存在：$Source`n请先执行 flutter build windows --release"
}
$exeSource = Join-Path $Source $ExeName
if (-not (Test-Path -LiteralPath $exeSource -PathType Leaf)) {
  throw "找不到 $ExeName：$exeSource"
}

Write-Host '==> 停止已安装的旧实例…'
Get-Process -Name 'planstar_desktop_app' -ErrorAction SilentlyContinue | ForEach-Object {
  $p = $null
  try { $p = $_.Path } catch { }
  if ($p -and $p.StartsWith($InstallRoot, [StringComparison]::OrdinalIgnoreCase)) {
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
  }
}
Start-Sleep -Milliseconds 800

Write-Host "==> 安装到 $InstallRoot"
New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
Get-ChildItem -LiteralPath $InstallRoot -Force -ErrorAction SilentlyContinue |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $Source '*') -Destination $InstallRoot -Recurse -Force

$iconSource = Join-Path $projectRoot 'windows\runner\resources\app_icon.ico'
$iconTarget = Join-Path $InstallRoot 'app_icon.ico'
if (Test-Path -LiteralPath $iconSource) {
  Copy-Item -LiteralPath $iconSource -Destination $iconTarget -Force
}
if (-not (Test-Path -LiteralPath $iconTarget)) { $iconTarget = Join-Path $InstallRoot $ExeName }

$uninstallSource = Join-Path $scriptDir 'uninstall.ps1'
if (Test-Path -LiteralPath $uninstallSource) {
  Copy-Item -LiteralPath $uninstallSource -Destination (Join-Path $InstallRoot 'uninstall.ps1') -Force
}

# 快捷方式属性写入依赖 ShellLink 的 IPropertyStore（见 ShortcutAumid.cs）。
if (-not ('Planstar.Installer.ShortcutAumid' -as [type])) {
  Add-Type -Path (Join-Path $scriptDir 'ShortcutAumid.cs')
}

function New-AppShortcut {
  param([string] $Path, [string] $Target)

  $parent = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  $shell = New-Object -ComObject WScript.Shell
  $lnk = $shell.CreateShortcut($Path)
  $lnk.TargetPath = $Target
  $lnk.WorkingDirectory = $InstallRoot
  $lnk.IconLocation = "$iconTarget,0"
  $lnk.Description = $AppName
  $lnk.Save()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($lnk)
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)

  # .lnk 落盘后再写入 System.AppUserModel.ID；WScript.Shell 的 shortcut
  # 对象本身不暴露 IPropertyStore。
  try {
    [Planstar.Installer.ShortcutAumid]::SetOnFile($Path, $AppUserModelId)
    # 用 Shell 属性系统回读校验（IPropertyStore::GetValue 对 ShellLink 不可靠）。
    $checkShell = New-Object -ComObject Shell.Application
    $checkFolder = $checkShell.Namespace((Split-Path -Parent $Path))
    $checkItem = $checkFolder.ParseName((Split-Path -Leaf $Path))
    $readBack = [string] $checkItem.ExtendedProperty('System.AppUserModel.ID')
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($checkItem)
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($checkFolder)
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($checkShell)
    if ($readBack -ne $AppUserModelId) {
      Write-Warning "AppUserModelID 回读不一致：$readBack"
    } else {
      Write-Host "    AppUserModelID：$readBack"
    }
  } catch {
    Write-Warning "快捷方式 AppUserModelID 写入失败（通知可能不可用）：$($_.Exception.Message)"
  }
  Write-Host "    快捷方式：$Path"
}

$exeTarget = Join-Path $InstallRoot $ExeName
if (-not $NoStartMenuShortcut) {
  $programs = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'
  New-AppShortcut -Path (Join-Path $programs "$ShortcutName.lnk") -Target $exeTarget
}
if (-not $NoDesktopShortcut) {
  $desktop = [Environment]::GetFolderPath('Desktop')
  New-AppShortcut -Path (Join-Path $desktop "$ShortcutName.lnk") -Target $exeTarget
}

Write-Host '==> 注册「应用和功能」卸载项 (HKCU)'
$uninstallCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f (Join-Path $InstallRoot 'uninstall.ps1')
New-Item -Path $UninstallKey -Force | Out-Null
Set-ItemProperty -Path $UninstallKey -Name 'DisplayName' -Value $AppName -Type String
Set-ItemProperty -Path $UninstallKey -Name 'DisplayVersion' -Value $Version -Type String
Set-ItemProperty -Path $UninstallKey -Name 'Publisher' -Value $Publisher -Type String
Set-ItemProperty -Path $UninstallKey -Name 'DisplayIcon' -Value "$iconTarget,0" -Type String
Set-ItemProperty -Path $UninstallKey -Name 'InstallLocation' -Value $InstallRoot -Type String
Set-ItemProperty -Path $UninstallKey -Name 'InstallDate' -Value (Get-Date -Format 'yyyyMMdd') -Type String
Set-ItemProperty -Path $UninstallKey -Name 'UninstallString' -Value $uninstallCommand -Type String
Set-ItemProperty -Path $UninstallKey -Name 'NoModify' -Value 1 -Type DWord
Set-ItemProperty -Path $UninstallKey -Name 'NoRepair' -Value 1 -Type DWord
$sizeKb = [int]((Get-ChildItem -LiteralPath $InstallRoot -Recurse -File |
  Measure-Object -Property Length -Sum).Sum / 1KB)
Set-ItemProperty -Path $UninstallKey -Name 'EstimatedSize' -Value $sizeKb -Type DWord

if ($Launch) {
  Start-Process -FilePath $exeTarget -WorkingDirectory $InstallRoot
  Write-Host '==> 已启动应用'
}

Write-Host ''
Write-Host '安装完成。'
Write-Host "  程序目录：$InstallRoot"
Write-Host "  可执行文件：$exeTarget"
Write-Host "  卸载：设置 → 应用 → 应用和功能 → $AppName，或运行 $InstallRoot\uninstall.ps1"
