param()

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$widgetScript = Join-Path $here "stock-widget.ps1"
$currentPid = $PID

Get-CimInstance Win32_Process |
  Where-Object {
    $_.ProcessId -ne $currentPid -and
    $_.Name -eq "powershell.exe" -and
    $_.CommandLine -like "*-File*outputs\stock-widget.ps1*"
  } |
  ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  }

$widgetInfo = New-Object System.Diagnostics.ProcessStartInfo
$widgetInfo.FileName = "powershell.exe"
$widgetInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$widgetScript`""
$widgetInfo.WorkingDirectory = $here
$widgetInfo.UseShellExecute = $false
$widgetInfo.CreateNoWindow = $true
$widgetInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
[System.Diagnostics.Process]::Start($widgetInfo) | Out-Null
