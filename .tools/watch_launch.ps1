$ErrorActionPreference = 'SilentlyContinue'
$exe = 'C:\Users\21263\AppData\Local\Programs\PlanstarDesktopApp\planstar_desktop_app.exe'

# clean slate
Get-Process -Name 'planstar_desktop_app' | Stop-Process -Force
Start-Sleep -Seconds 2

$p = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru
$launch = Get-Date
Write-Output ("launched pid=" + $p.Id + " at " + $launch.ToString('HH:mm:ss'))

for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Seconds 3
  $procs = @(Get-Process -Name 'planstar_desktop_app')
  $elapsed = [int]((Get-Date) - $launch).TotalSeconds
  if ($procs.Count -eq 0) {
    Write-Output ("t+" + $elapsed + "s  EXITED  (exitCode=" + $p.ExitCode + ")")
    break
  }
  $main = $procs[0]
  $h = $main.Handle
  Write-Output ("t+" + $elapsed + "s  RUNNING pid=" + $main.Id + " mem=" + [math]::Round($main.WorkingSet64/1MB) + "MB handles=" + $main.HandleCount)
}

if ($procs.Count -gt 0) {
  Write-Output "=== still alive at t+60s -> stable ==="
}
