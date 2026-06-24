param(
  [string[]]$Symbols = @("SPCX", "^GSPC", "AAPL", "NVDA", "TSLA", "AMZN", "QQQ", "SMH", "M")
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$cacheDirectory = Join-Path $env:LOCALAPPDATA "StockWidget"
$cachePath = Join-Path $cacheDirectory "quotes.json"
$positionPath = Join-Path $cacheDirectory "position.json"
$symbolsPath = Join-Path $cacheDirectory "symbols.json"
$script:quoteCache = @{}

if (Test-Path -LiteralPath $symbolsPath) {
  try {
    $savedSymbols = @(Get-Content -LiteralPath $symbolsPath -Raw | ConvertFrom-Json)
    if ($savedSymbols.Count -gt 0) {
      $Symbols = @($savedSymbols | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Where-Object { $_ } | Select-Object -Unique)
    }
  } catch {}
}

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
        Width="440" Height="620"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        ResizeMode="NoResize"
        MinHeight="360"
        ShowInTaskbar="False"
        ShowActivated="True"
        Topmost="False">
  <Border Background="Transparent" BorderThickness="0" Padding="18">
    <Grid Opacity="0.99">
      <Canvas IsHitTestVisible="False">
        <Canvas.OpacityMask>
          <RadialGradientBrush Center="0.5,0.52" GradientOrigin="0.48,0.48" RadiusX="0.72" RadiusY="0.60">
            <GradientStop Color="#FFFFFFFF" Offset="0"/>
            <GradientStop Color="#FFFFFFFF" Offset="0.42"/>
            <GradientStop Color="#B8FFFFFF" Offset="0.62"/>
            <GradientStop Color="#30FFFFFF" Offset="0.82"/>
            <GradientStop Color="#00FFFFFF" Offset="1"/>
          </RadialGradientBrush>
        </Canvas.OpacityMask>
        <Rectangle x:Name="MainSoftField" Canvas.Left="20" Canvas.Top="24" Width="364" Height="548" RadiusX="34" RadiusY="34" Fill="#B2050506">
          <Rectangle.Effect><BlurEffect Radius="58"/></Rectangle.Effect>
        </Rectangle>
        <Ellipse Canvas.Left="16" Canvas.Top="22" Width="344" Height="210" Fill="#30F1EADB">
          <Ellipse.Effect><BlurEffect Radius="72"/></Ellipse.Effect>
        </Ellipse>
        <Ellipse Canvas.Left="78" Canvas.Top="178" Width="320" Height="366" Fill="#8C040405">
          <Ellipse.Effect><BlurEffect Radius="88"/></Ellipse.Effect>
        </Ellipse>
        <Polygon Points="12,118 112,48 238,76 410,28 424,218 312,270 128,236" Fill="#24F1EADB">
          <Polygon.Effect><BlurEffect Radius="54"/></Polygon.Effect>
        </Polygon>
        <Ellipse Canvas.Left="256" Canvas.Top="390" Width="166" Height="142" Fill="#72030103">
          <Ellipse.Effect><BlurEffect Radius="96"/></Ellipse.Effect>
        </Ellipse>
      </Canvas>
      <Grid Margin="10">

      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="10"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="10"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="10"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <Canvas IsHitTestVisible="False" Opacity="0.20">
        <Line X1="0" Y1="74" X2="440" Y2="74" Stroke="#6E5A2424" StrokeThickness="1"/>
        <Line X1="0" Y1="132" X2="440" Y2="132" Stroke="#4E5A2424" StrokeThickness="1"/>
        <Line X1="30" Y1="0" X2="30" Y2="620" Stroke="#38492A2A" StrokeThickness="1"/>
        <Line X1="408" Y1="0" X2="408" Y2="620" Stroke="#38492A2A" StrokeThickness="1"/>
        <Rectangle Canvas.Left="8" Canvas.Top="12" Width="7" Height="44" Fill="#A8A11919"/>
        <Rectangle Canvas.Left="388" Canvas.Top="12" Width="7" Height="44" Fill="#66A11919"/>
        <Polygon Points="202,10 216,34 188,34" Fill="#66A11919" Stroke="#B6492424" StrokeThickness="1"/>
        <Line X1="170" Y1="22" X2="234" Y2="22" Stroke="#A6492424" StrokeThickness="1"/>
      </Canvas>

      <DockPanel Grid.Row="0">
        <StackPanel DockPanel.Dock="Left">
          <TextBlock Text="HARKONNEN MARKET COMMAND" Foreground="#F0E7DF" FontFamily="Bahnschrift SemiCondensed" FontSize="15" FontWeight="Black"/>
          <TextBlock Text="LIVE ASSET SURVEILLANCE // GIEDI PRIME" Foreground="#9E7772" FontSize="9" FontWeight="Bold" Margin="0,3,0,0"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="AddSymbolButton" Content="+" Width="28" Height="28" Margin="0,0,10,0"
                  Foreground="#F0E7DF" Background="#42130F10" BorderBrush="#66734A4A"
                  BorderThickness="1" FontFamily="Consolas" FontSize="18" FontWeight="Bold"
                  ToolTip="添加股票代码" Cursor="Hand"/>
          <TextBlock x:Name="ClockText" Text="--" Foreground="#D64335" FontFamily="Consolas" FontSize="12" FontWeight="Bold" VerticalAlignment="Center"/>
        </StackPanel>
      </DockPanel>

      <Border Grid.Row="2" CornerRadius="12" BorderBrush="#526E3B3B" BorderThickness="1" Background="#58151112" Padding="11">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel>
            <TextBlock Text="COMBINED EXPOSURE" Foreground="#9E7772" FontSize="9" FontWeight="Bold"/>
            <TextBlock x:Name="PortfolioText" Text="$0.00" Foreground="#F0E7DF" FontFamily="Bahnschrift SemiCondensed" FontSize="31" FontWeight="Black" Margin="0,4,0,0"/>
          </StackPanel>
          <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Center">
            <TextBlock x:Name="PortfolioChangeText" Text="+0.00%" Foreground="#D64335" FontFamily="Bahnschrift SemiCondensed, Consolas" FontSize="21" FontWeight="Black" TextAlignment="Right"/>
            <TextBlock Text="SESSION DELTA" Foreground="#755D5A" FontSize="9" FontWeight="Bold" TextAlignment="Right"/>
          </StackPanel>
        </Grid>
      </Border>

      <StackPanel Grid.Row="4" x:Name="StockList" ClipToBounds="True"/>

      <Border Grid.Row="6" CornerRadius="12" Background="#4A100D0E" BorderBrush="#485E3434" BorderThickness="1" Padding="9,7">
        <DockPanel>
          <Ellipse x:Name="StatusDot" Width="8" Height="8" Fill="#C72920" DockPanel.Dock="Left" Margin="0,0,8,0"/>
          <TextBlock x:Name="StatusText" Text="每3分钟自动刷新；按住拖动；非置顶" Foreground="#9E7772" FontSize="11"/>
        </DockPanel>
      </Border>

      <Thumb x:Name="HeightGrip" Grid.Row="7" Height="16" Cursor="SizeNS" HorizontalAlignment="Stretch">
        <Thumb.Template>
          <ControlTemplate TargetType="{x:Type Thumb}">
            <Grid Background="Transparent">
              <Border Width="62" Height="3" CornerRadius="2" Background="#80765B5B" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Grid>
          </ControlTemplate>
        </Thumb.Template>
      </Thumb>
      </Grid>
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
$addSymbolButton = $window.FindName("AddSymbolButton")
$heightGrip = $window.FindName("HeightGrip")
$mainSoftField = $window.FindName("MainSoftField")
$script:hwnd = [IntPtr]::Zero

function Save-Symbols {
  try {
    New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
    @($script:Symbols) | ConvertTo-Json | Set-Content -LiteralPath $symbolsPath -Encoding UTF8
  } catch {}
}

function Save-WindowLayout {
  try {
    New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
    @{
      Left = $window.Left
      Top = $window.Top
      Height = $window.Height
    } | ConvertTo-Json | Set-Content -LiteralPath $positionPath -Encoding UTF8
  } catch {}
}

function Show-AddSymbolDialog {
  $dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="330" Height="178" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ResizeMode="NoResize" ShowInTaskbar="False"
        WindowStartupLocation="CenterOwner">
  <Border CornerRadius="18" Background="#E0151113" BorderBrush="#88704A4A" BorderThickness="1" Padding="20">
    <Border.Effect><DropShadowEffect BlurRadius="32" ShadowDepth="0" Opacity="0.45" Color="#200000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="12"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="16"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <TextBlock Text="ADD MARKET SYMBOL" Foreground="#F0E7DF" FontFamily="Bahnschrift SemiCondensed" FontSize="15" FontWeight="Black"/>
      <TextBox x:Name="SymbolInput" Grid.Row="2" Height="34" Padding="9,6" MaxLength="18"
               Foreground="#F0E7DF" Background="#70100D0F" BorderBrush="#806B4848"
               BorderThickness="1" FontFamily="Consolas" FontSize="14"/>
      <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="CancelButton" Content="取消" Width="70" Height="30" Margin="0,0,8,0"
                Foreground="#A99E8D" Background="#30100D0E" BorderBrush="#405E4747"/>
        <Button x:Name="AddButton" Content="添加" Width="70" Height="30"
                Foreground="#F0E7DF" Background="#70401A1D" BorderBrush="#9A824A4A"/>
      </StackPanel>
    </Grid>
  </Border>
</Window>
"@
  $dialogReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$dialogXaml)
  $dialog = [Windows.Markup.XamlReader]::Load($dialogReader)
  $dialog.Owner = $window
  $input = $dialog.FindName("SymbolInput")
  $addButton = $dialog.FindName("AddButton")
  $cancelButton = $dialog.FindName("CancelButton")
  $script:newSymbol = $null

  $submit = {
    $value = ([string]$input.Text).Trim().ToUpperInvariant()
    if ($value) {
      $script:newSymbol = $value
      $dialog.DialogResult = $true
    }
  }
  $addButton.Add_Click($submit)
  $cancelButton.Add_Click({ $dialog.DialogResult = $false })
  $input.Add_KeyDown({
    if ($_.Key -eq [System.Windows.Input.Key]::Enter) { & $submit }
    elseif ($_.Key -eq [System.Windows.Input.Key]::Escape) { $dialog.DialogResult = $false }
  })
  $dialog.Add_ContentRendered({ $input.Focus() | Out-Null })
  $accepted = $dialog.ShowDialog()
  if ($accepted -and $script:newSymbol) { return $script:newSymbol }
  return $null
}

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
    "SPCX" { return "SPACE X" }
    "^GSPC" { return "S&P 500" }
    default { return $symbol.ToUpperInvariant() }
  }
}

function Get-SymbolSubtext($symbol) {
  switch ($symbol.ToUpperInvariant()) {
    "QQQ" { return "Nasdaq 100 ETF" }
    "^GSPC" { return "S&P 500 Index" }
    "SMH" { return "Semiconductor ETF" }
    "M" { return "Macy's" }
    "AMZN" { return "Amazon" }
    "SPCX" { return "SpaceX / Nasdaq" }
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
      Subtext = if ($subtext) { $subtext } elseif ($meta.shortName) { [string]$meta.shortName } else { "" }
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
  if ($isUp) { return "#C9A35C" }
  return "#D64335"
}

function Get-ChangeText($value) {
  return "{0}{1:N2}%" -f ($(if ($value -ge 0) { "+" } else { "" }), $value)
}

function Add-StockRow($item) {
  $isUp = ($item.Change -ge 0)
  $changeBrush = Get-ChangeBrush $isUp
  $row = New-Object System.Windows.Controls.Border
  $row.CornerRadius = "10"
  $row.BorderThickness = "1"
  $row.BorderBrush = if ($isUp) { "#405C4B32" } else { "#526E3030" }
  $row.Background = if ($isUp) { "#5A131110" } else { "#64190E0F" }
  $row.Padding = "9,6"
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
  $name.Foreground = "#F0E7DF"
  $name.FontSize = 13
  $name.FontWeight = [System.Windows.FontWeights]::Black
  $name.FontFamily = "Bahnschrift SemiCondensed, Segoe UI"
  [System.Windows.Controls.Grid]::SetColumn($name, 1)
  [System.Windows.Controls.Grid]::SetRow($name, 0)

  $price = New-Object System.Windows.Controls.TextBlock
  $sourceMark = if ($item.IsLive) { "" } else { "  " + $item.Note }
  $price.Text = if ($item.Subtext) { (Format-Money $item.Price) + "  " + $item.Subtext + $sourceMark } else { (Format-Money $item.Price) + $sourceMark }
  $price.Foreground = "#9E8E87"
  $price.FontSize = 10
  $price.Margin = "72,2,0,0"
  $price.FontFamily = "Consolas, Segoe UI"
  [System.Windows.Controls.Grid]::SetColumn($price, 1)
  [System.Windows.Controls.Grid]::SetRow($price, 0)

  $changeBadge = New-Object System.Windows.Controls.Border
  $changeBadge.CornerRadius = "8"
  $changeBadge.BorderThickness = "1"
  $changeBadge.BorderBrush = $changeBrush
  $changeBadge.Background = if ($isUp) { "#243E3020" } else { "#2C561719" }
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
    $bar.RadiusX = 0
    $bar.RadiusY = 0
    $bar.Fill = if ($isUp) { "#9B7B43" } else { "#A82D28" }
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
  $pricedItems = @($stockItems | Where-Object { $null -ne $_.Price -and $_.Symbol -ne "^GSPC" })
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
  $WS_EX_TOOLWINDOW = 0x80
  [NativeWindowTools]::SetWindowLong($hwnd, -20, $style -bor $WS_EX_TOOLWINDOW) | Out-Null

  $area = [System.Windows.SystemParameters]::WorkArea
  if (Test-Path -LiteralPath $positionPath) {
    try {
      $position = Get-Content -LiteralPath $positionPath -Raw | ConvertFrom-Json
      if ($position.PSObject.Properties.Name -contains "Height") {
        $window.Height = [Math]::Max($window.MinHeight, [double]$position.Height)
      }
      $window.Left = [Math]::Max($area.Left, [Math]::Min([double]$position.Left, $area.Right - $window.Width))
      $window.Top = [Math]::Max($area.Top, [Math]::Min([double]$position.Top, $area.Bottom - $window.Height))
    } catch {
      $window.Left = $area.Right - $window.Width - 18
      $window.Top = $area.Top + 360
    }
  } else {
    $window.Left = $area.Right - $window.Width - 18
    $window.Top = $area.Top + 360
  }
  $window.MaxHeight = [Math]::Max($window.MinHeight, $area.Bottom - $window.Top)
})

$addSymbolButton.Add_Click({
  $symbol = Show-AddSymbolDialog
  if (-not $symbol) { return }
  if (@($script:Symbols) -contains $symbol) {
    $statusText.Text = "$symbol 已在列表中"
    return
  }
  $script:Symbols = @($script:Symbols) + $symbol
  Save-Symbols
  $statusText.Text = "正在添加 $symbol..."
  Update-Widget
})

$heightGrip.Add_DragDelta({
  $area = [System.Windows.SystemParameters]::WorkArea
  $maxHeight = [Math]::Max($window.MinHeight, $area.Bottom - $window.Top)
  $window.Height = [Math]::Max($window.MinHeight, [Math]::Min($maxHeight, $window.Height + $_.VerticalChange))
})

$heightGrip.Add_DragCompleted({ Save-WindowLayout })

$window.Add_MouseLeftButtonDown({
  if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
    try { $window.DragMove() } catch {}
  }
})

$window.Add_LocationChanged({
  Save-WindowLayout
})

$window.Add_SizeChanged({
  if ($null -ne $mainSoftField) {
    $mainSoftField.Height = [Math]::Max(250, $window.ActualHeight - 72)
  }
})

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMinutes(3)
$timer.Add_Tick({ Update-Widget })
$timer.Start()

Update-Widget
$window.ShowDialog() | Out-Null

