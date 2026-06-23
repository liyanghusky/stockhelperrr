param(
  [string[]]$Symbols = @("AAPL", "NVDA", "TSLA", "AMZN", "QQQ", "SMH", "M", "SPACEX")
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$cacheDirectory = Join-Path $env:LOCALAPPDATA "StockWidget"
$cachePath = Join-Path $cacheDirectory "quotes.json"
$script:quoteCache = @{}

if (Test-Path -LiteralPath $cachePath) {
  try {
    $cachedJson = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
    foreach ($property in $cachedJson.PSObject.Properties) {
      $script:quoteCache[$property.Name] = $property.Value
    }
  } catch {
    $script:quoteCache = @{}
  }
}

$signature = @"
using System;
using System.Runtime.InteropServices;
public static class NativeWindowTools {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }

  [DllImport("user32.dll")]
  public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

  [DllImport("user32.dll")]
  public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
}
"@
Add-Type -TypeDefinition $signature

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="390" Height="460"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        ShowActivated="False"
        Topmost="False">
  <Border CornerRadius="2"
          BorderThickness="1"
          BorderBrush="#88C8CDD0"
          Background="#C8D7DBDC"
          Padding="14"
          Opacity="0.88">
    <Border.Effect>
      <DropShadowEffect BlurRadius="16" ShadowDepth="0" Opacity="0.18" Color="#30383C"/>
    </Border.Effect>
    <Grid>

      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="10"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="10"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="10"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <Canvas IsHitTestVisible="False" Opacity="0.34">
        <Line X1="-20" Y1="44" X2="410" Y2="12" Stroke="#8EA0A4A5" StrokeThickness="1"/>
        <Line X1="12" Y1="168" X2="392" Y2="78" Stroke="#72A0A4A5" StrokeThickness="1"/>
        <Line X1="-10" Y1="300" X2="420" Y2="212" Stroke="#64A0A4A5" StrokeThickness="1"/>
        <Line X1="86" Y1="-20" X2="236" Y2="462" Stroke="#5EA0A4A5" StrokeThickness="1"/>
        <Line X1="304" Y1="16" X2="54" Y2="436" Stroke="#52A0A4A5" StrokeThickness="1"/>
        <Ellipse Canvas.Left="260" Canvas.Top="24" Width="44" Height="44" Stroke="#62A0A4A5" StrokeThickness="1"/>
        <Ellipse Canvas.Left="26" Canvas.Top="280" Width="70" Height="70" Stroke="#52A0A4A5" StrokeThickness="1"/>
        <Ellipse Canvas.Left="306" Canvas.Top="336" Width="38" Height="38" Stroke="#58A0A4A5" StrokeThickness="1"/>
        <Polygon Points="188,28 200,50 176,50" Fill="#70B6A15A" Stroke="#88A88E45" StrokeThickness="1"/>
        <Polygon Points="220,54 232,75 208,75" Fill="#52B6A15A" Stroke="#70A88E45" StrokeThickness="1"/>
        <Rectangle Canvas.Left="46" Canvas.Top="112" Width="5" Height="5" Fill="#8AA88E45"/>
        <Rectangle Canvas.Left="332" Canvas.Top="194" Width="4" Height="4" Fill="#80A88E45"/>
      </Canvas>

      <DockPanel Grid.Row="0">
        <StackPanel DockPanel.Dock="Left">
          <TextBlock Text="STOCK WATCH" Foreground="#243036" FontSize="14" FontWeight="Black"/>
          <TextBlock Text="IMPERIAL ICE MAP" Foreground="#6D7475" FontSize="10" FontWeight="Bold" Margin="0,3,0,0"/>
        </StackPanel>
        <TextBlock x:Name="ClockText" Text="--" Foreground="#596368" FontSize="11" HorizontalAlignment="Right"/>
      </DockPanel>

      <Border Grid.Row="2" BorderBrush="#90B8BCC0" BorderThickness="1" Background="#66EEF0EF" Padding="10">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel>
            <TextBlock Text="模拟组合" Foreground="#6D7475" FontSize="10" FontWeight="Bold"/>
            <TextBlock x:Name="PortfolioText" Text="$0.00" Foreground="#243036" FontSize="30" FontWeight="Black" Margin="0,4,0,0"/>
          </StackPanel>
          <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Center">
            <TextBlock x:Name="PortfolioChangeText" Text="+0.00%" Foreground="#7D6B35" FontFamily="Bahnschrift SemiCondensed, Consolas" FontSize="20" FontWeight="Black" TextAlignment="Right"/>
            <TextBlock Text="SESSION" Foreground="#7D837F" FontSize="10" FontWeight="Bold" TextAlignment="Right"/>
          </StackPanel>
        </Grid>
      </Border>

      <StackPanel Grid.Row="4" x:Name="StockList"/>

      <Border Grid.Row="6" CornerRadius="3" Background="#50EEF0EF" BorderBrush="#8AB8BCC0" BorderThickness="1" Padding="9,7">
        <DockPanel>
          <Ellipse x:Name="StatusDot" Width="8" Height="8" Fill="#B69A50" DockPanel.Dock="Left" Margin="0,0,8,0"/>
          <TextBlock x:Name="StatusText" Text="每3分钟自动刷新；鼠标穿透；非置顶" Foreground="#5F696C" FontSize="11"/>
        </DockPanel>
      </Border>
    </Grid>
  </Border>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$clockText = $window.FindName("ClockText")
$portfolioText = $window.FindName("PortfolioText")
$portfolioChangeText = $window.FindName("PortfolioChangeText")
$stockList = $window.FindName("StockList")
$statusText = $window.FindName("StatusText")
$script:hwnd = [IntPtr]::Zero

function Get-SymbolHash($symbol) {
  $sum = 97
  foreach ($char in $symbol.ToCharArray()) {
    $sum += [int][char]$char * 17
  }
  return $sum
}

function Get-SeededNoise($seed) {
  $x = [Math]::Sin($seed) * 10000
  return $x - [Math]::Floor($x)
}

function Get-SymbolLabel($symbol) {
  switch ($symbol.ToUpperInvariant()) {
    "SPACEX" { return "SPACE X" }
    default { return $symbol.ToUpperInvariant() }
  }
}

function Get-SymbolSubtext($symbol) {
  switch ($symbol.ToUpperInvariant()) {
    "QQQ" { return "Nasdaq 100 ETF" }
    "SMH" { return "Semiconductor ETF" }
    "M" { return "Macy's" }
    "AMZN" { return "Amazon" }
    "SPACEX" { return "私募估值 / N/A" }
    default { return "" }
  }
}

function ConvertTo-DoubleOrNull($value) {
  if ($null -eq $value) { return $null }
  try {
    return [double]$value
  } catch {
    return $null
  }
}

function Save-QuoteCache {
  try {
    New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
    $script:quoteCache | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $cachePath -Encoding UTF8
  } catch {
    # A cache write failure should never stop live quote updates.
  }
}

function Get-YahooChart($symbol) {
  $encoded = [System.Uri]::EscapeDataString($symbol)
  $errors = @()
  foreach ($hostName in @("query1.finance.yahoo.com", "query2.finance.yahoo.com")) {
    $uri = "https://$hostName/v8/finance/chart/${encoded}?range=1d&interval=5m"
    try {
      $response = Invoke-RestMethod `
        -Uri $uri `
        -Headers @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) StockWidget/1.0"; "Accept" = "application/json" } `
        -TimeoutSec 15
      if ($null -eq $response.chart.error -and @($response.chart.result).Count -gt 0) {
        return $response.chart.result[0]
      }
      $errors += "$hostName returned no data"
    } catch {
      $errors += "$hostName`: $($_.Exception.Message)"
      Start-Sleep -Milliseconds 250
    }
  }
  throw ($errors -join " | ")
}

function Get-StockSnapshot($symbol) {
  $symbol = $symbol.ToUpperInvariant()
  $label = Get-SymbolLabel $symbol
  $subtext = Get-SymbolSubtext $symbol

  if ($symbol -eq "SPACEX") {
    return [pscustomobject]@{
      Symbol = $symbol
      Label = $label
      Subtext = $subtext
      Price = $null
      Change = 0
      Values = @()
      IsLive = $false
      Note = "非公开交易"
    }
  }

  try {
    $result = Get-YahooChart $symbol
    $meta = $result.meta
    $quote = $result.indicators.quote[0]
    $closes = @($quote.close | ForEach-Object { ConvertTo-DoubleOrNull $_ } | Where-Object { $null -ne $_ })
    $values = @($closes | Select-Object -Last 14 | ForEach-Object { [Math]::Round($_, 2) })
    $price = ConvertTo-DoubleOrNull $meta.regularMarketPrice
    if ($null -eq $price -and $values.Count -gt 0) {
      $price = $values[$values.Count - 1]
    }

    $previousClose = ConvertTo-DoubleOrNull $meta.previousClose
    if ($null -eq $previousClose) {
      $previousClose = ConvertTo-DoubleOrNull $meta.chartPreviousClose
    }
    if ($null -eq $previousClose -and $values.Count -gt 0) {
      $previousClose = $values[0]
    }

    $change = if ($null -ne $price -and $null -ne $previousClose -and $previousClose -ne 0) {
      (($price - $previousClose) / $previousClose) * 100
    } else {
      0
    }

    $snapshot = [pscustomobject]@{
      Symbol = $symbol
      Label = $label
      Subtext = if ($meta.shortName) { [string]$meta.shortName } else { $subtext }
      Price = if ($null -ne $price) { [Math]::Round($price, 2) } else { $null }
      Change = $change
      Values = $values
      IsLive = $true
      Note = "Yahoo Finance"
      Error = ""
    }
    $script:quoteCache[$symbol] = [pscustomobject]@{
      Symbol = $snapshot.Symbol
      Label = $snapshot.Label
      Subtext = $snapshot.Subtext
      Price = $snapshot.Price
      Change = $snapshot.Change
      Values = $snapshot.Values
      SavedAt = (Get-Date).ToString("o")
    }
    return $snapshot
  } catch {
    $errorMessage = $_.Exception.Message
    if ($script:quoteCache.ContainsKey($symbol)) {
      $cached = $script:quoteCache[$symbol]
      return [pscustomobject]@{
        Symbol = $symbol
        Label = $label
        Subtext = [string]$cached.Subtext
        Price = ConvertTo-DoubleOrNull $cached.Price
        Change = ConvertTo-DoubleOrNull $cached.Change
        Values = @($cached.Values)
        IsLive = $false
        Note = "缓存"
        Error = $errorMessage
      }
    }
    return [pscustomobject]@{
      Symbol = $symbol
      Label = $label
      Subtext = if ($subtext) { $subtext } else { "行情暂不可用" }
      Price = $null
      Change = 0
      Values = @()
      IsLive = $false
      Note = "读取失败"
      Error = $errorMessage
    }
  }
}

function Format-Money($value) {
  if ($null -eq $value) { return "N/A" }
  return "$" + $value.ToString("N2", [System.Globalization.CultureInfo]::GetCultureInfo("en-US"))
}

function Get-ChangeBrush($isUp) {
  if ($isUp) { return "#8A7436" }
  return "#A65C54"
}

function Get-ChangeText($value) {
  return "{0}{1:N2}%" -f ($(if ($value -ge 0) { "+" } else { "" }), $value)
}

function Add-StockRow($item) {
  $isUp = ($item.Change -ge 0)
  $changeBrush = Get-ChangeBrush $isUp
  $row = New-Object System.Windows.Controls.Border
  $row.CornerRadius = "3"
  $row.BorderThickness = "1"
  $row.BorderBrush = if ($isUp) { "#78B8BCC0" } else { "#88A65C54" }
  $row.Background = if ($isUp) { "#48F3F4F1" } else { "#42EEE6E2" }
  $row.Padding = "8,5"
  $row.Margin = "0,0,0,5"

  $grid = New-Object System.Windows.Controls.Grid
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) | Out-Null
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) | Out-Null
  $accentCol = New-Object System.Windows.Controls.ColumnDefinition
  $accentCol.Width = "3"
  $grid.ColumnDefinitions.Add($accentCol) | Out-Null
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) | Out-Null
  $col2 = New-Object System.Windows.Controls.ColumnDefinition
  $col2.Width = "Auto"
  $grid.ColumnDefinitions.Add($col2) | Out-Null

  $accent = New-Object System.Windows.Shapes.Rectangle
  $accent.Width = 2
  $accent.Margin = "0,1,7,1"
  $accent.RadiusX = 2
  $accent.RadiusY = 2
  $accent.Fill = $changeBrush
  [System.Windows.Controls.Grid]::SetColumn($accent, 0)
  [System.Windows.Controls.Grid]::SetRowSpan($accent, 2)

  $name = New-Object System.Windows.Controls.TextBlock
  $name.Text = $item.Label
  $name.Foreground = "#243036"
  $name.FontSize = 13
  $name.FontWeight = [System.Windows.FontWeights]::Black
  $name.FontFamily = "Bahnschrift SemiCondensed, Segoe UI"
  [System.Windows.Controls.Grid]::SetColumn($name, 1)
  [System.Windows.Controls.Grid]::SetRow($name, 0)

  $price = New-Object System.Windows.Controls.TextBlock
  $sourceMark = if ($item.IsLive) { "" } else { "  " + $item.Note }
  $price.Text = if ($item.Subtext) { (Format-Money $item.Price) + "  " + $item.Subtext + $sourceMark } else { (Format-Money $item.Price) + $sourceMark }
  $price.Foreground = "#687174"
  $price.FontSize = 10
  $price.Margin = "72,2,0,0"
  $price.FontFamily = "Consolas, Segoe UI"
  [System.Windows.Controls.Grid]::SetColumn($price, 1)
  [System.Windows.Controls.Grid]::SetRow($price, 0)

  $changeBadge = New-Object System.Windows.Controls.Border
  $changeBadge.CornerRadius = "3"
  $changeBadge.BorderThickness = "1"
  $changeBadge.BorderBrush = $changeBrush
  $changeBadge.Background = if ($isUp) { "#40D8C896" } else { "#36D9B3AA" }
  $changeBadge.Padding = "7,1"
  $changeBadge.MinWidth = 78
  [System.Windows.Controls.Grid]::SetColumn($changeBadge, 2)
  [System.Windows.Controls.Grid]::SetRow($changeBadge, 0)

  $change = New-Object System.Windows.Controls.TextBlock
  $change.Text = Get-ChangeText $item.Change
  $change.Foreground = $changeBrush
  $change.FontFamily = "Bahnschrift SemiCondensed, Consolas"
  $change.FontSize = 16
  $change.FontWeight = [System.Windows.FontWeights]::Black
  $change.TextAlignment = [System.Windows.TextAlignment]::Right
  $changeBadge.Child = $change

  $bars = New-Object System.Windows.Controls.StackPanel
  $bars.Orientation = [System.Windows.Controls.Orientation]::Horizontal
  $bars.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
  $bars.Margin = "0,4,0,0"
  [System.Windows.Controls.Grid]::SetColumn($bars, 1)
  [System.Windows.Controls.Grid]::SetColumnSpan($bars, 2)
  [System.Windows.Controls.Grid]::SetRow($bars, 1)

  $barValues = @($item.Values)
  if ($barValues.Count -eq 0) {
    $barValues = @(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  }
  $min = ($barValues | Measure-Object -Minimum).Minimum
  $max = ($barValues | Measure-Object -Maximum).Maximum
  $spread = [Math]::Max(0.01, $max - $min)
  foreach ($value in $barValues) {
    $bar = New-Object System.Windows.Shapes.Rectangle
    $bar.Width = 16
    $bar.Height = 3 + (($value - $min) / $spread) * 10
    $bar.Margin = "0,0,3,0"
    $bar.RadiusX = 2
    $bar.RadiusY = 2
    $bar.Fill = if ($isUp) { "#B6A15A" } else { "#A65C54" }
    $bars.Children.Add($bar) | Out-Null
  }

  $grid.Children.Add($accent) | Out-Null
  $grid.Children.Add($name) | Out-Null
  $grid.Children.Add($price) | Out-Null
  $grid.Children.Add($changeBadge) | Out-Null
  $grid.Children.Add($bars) | Out-Null
  $row.Child = $grid
  $stockList.Children.Add($row) | Out-Null
}

function Update-Widget {
  $stockItems = @($Symbols | ForEach-Object { Get-StockSnapshot $_.ToUpperInvariant() })
  Save-QuoteCache
  $stockList.Children.Clear()
  foreach ($item in $stockItems) {
    Add-StockRow $item
  }
  $pricedItems = @($stockItems | Where-Object { $null -ne $_.Price })
  $total = if ($pricedItems.Count -gt 0) { ($pricedItems | Measure-Object -Property Price -Sum).Sum * 8 } else { $null }
  $avgChange = if ($pricedItems.Count -gt 0) { ($pricedItems | Measure-Object -Property Change -Average).Average } else { 0 }
  $portfolioText.Text = Format-Money $total
  $portfolioChangeText.Text = Get-ChangeText $avgChange
  $portfolioChangeText.Foreground = Get-ChangeBrush ($avgChange -ge 0)
  $clockText.Text = (Get-Date).ToString("HH:mm")
  $liveCount = @($stockItems | Where-Object { $_.IsLive }).Count
  $cacheCount = @($stockItems | Where-Object { -not $_.IsLive -and $_.Note -eq "缓存" }).Count
  if ($liveCount -gt 0) {
    $statusText.Text = "实时 $liveCount/$($stockItems.Count)；缓存 $cacheCount；每3分钟刷新"
  } else {
    $firstError = @($stockItems | Where-Object { $_.Error } | Select-Object -First 1)
    $reason = if ($firstError.Count -gt 0) { $firstError[0].Error } else { "无可用行情" }
    if ($reason.Length -gt 38) { $reason = $reason.Substring(0, 38) + "..." }
    $statusText.Text = "实时连接失败；缓存 $cacheCount；$reason"
  }
}

$window.Add_SourceInitialized({
  $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
  $hwnd = $helper.Handle
  $script:hwnd = $hwnd
  $style = [NativeWindowTools]::GetWindowLong($hwnd, -20)
  $WS_EX_TRANSPARENT = 0x20
  $WS_EX_TOOLWINDOW = 0x80
  $WS_EX_NOACTIVATE = 0x08000000
  [NativeWindowTools]::SetWindowLong($hwnd, -20, $style -bor $WS_EX_TRANSPARENT -bor $WS_EX_TOOLWINDOW -bor $WS_EX_NOACTIVATE) | Out-Null

  $area = [System.Windows.SystemParameters]::WorkArea
  $window.Left = $area.Right - $window.Width - 18
  $window.Top = $area.Top + 400
})

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMinutes(3)
$timer.Add_Tick({ Update-Widget })
$timer.Start()

Update-Widget
$window.ShowDialog() | Out-Null

