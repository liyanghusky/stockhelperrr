param(
  [string[]]$Symbols = @("AAPL", "NVDA", "TSLA", "AMZN", "QQQ", "SMH", "M", "SPACEX")
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

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
        Width="390" Height="522"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        ShowActivated="False"
        Topmost="False">
  <Border CornerRadius="2"
          BorderThickness="1"
          BorderBrush="#45E9E6DD"
          Background="#B3050506"
          Padding="14"
          Opacity="0.86">
    <Border.Effect>
      <DropShadowEffect BlurRadius="18" ShadowDepth="0" Opacity="0.26" Color="#000000"/>
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

      <DockPanel Grid.Row="0">
        <StackPanel DockPanel.Dock="Left">
          <TextBlock Text="STOCK WATCH" Foreground="#E9E6DD" FontSize="14" FontWeight="Black"/>
          <TextBlock Text="HARKONNEN MARKET WIDGET" Foreground="#86847D" FontSize="10" FontWeight="Bold" Margin="0,3,0,0"/>
        </StackPanel>
        <TextBlock x:Name="ClockText" Text="--" Foreground="#86847D" FontSize="11" HorizontalAlignment="Right"/>
      </DockPanel>

      <Border Grid.Row="2" BorderBrush="#2E2E32" BorderThickness="1" Background="#2AFFFFFF" Padding="10">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel>
            <TextBlock Text="模拟组合" Foreground="#86847D" FontSize="10" FontWeight="Bold"/>
            <TextBlock x:Name="PortfolioText" Text="$0.00" Foreground="#E9E6DD" FontSize="30" FontWeight="Black" Margin="0,4,0,0"/>
          </StackPanel>
          <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Center">
            <TextBlock x:Name="PortfolioChangeText" Text="+0.00%" Foreground="#F8F4E8" FontFamily="Bahnschrift SemiCondensed, Consolas" FontSize="20" FontWeight="Black" TextAlignment="Right"/>
            <TextBlock Text="SESSION" Foreground="#86847D" FontSize="10" FontWeight="Bold" TextAlignment="Right"/>
          </StackPanel>
        </Grid>
      </Border>

      <StackPanel Grid.Row="4" x:Name="StockList"/>

      <Border Grid.Row="6" CornerRadius="2" Background="#18FFFFFF" BorderBrush="#2E2E32" BorderThickness="1" Padding="9,7">
        <DockPanel>
          <Ellipse x:Name="StatusDot" Width="8" Height="8" Fill="#E9E6DD" DockPanel.Dock="Left" Margin="0,0,8,0"/>
          <TextBlock x:Name="StatusText" Text="每3分钟自动刷新；鼠标穿透；非置顶" Foreground="#86847D" FontSize="11"/>
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
    "SPACEX" { return "私募估值" }
    default { return "" }
  }
}

function Get-StockSnapshot($symbol) {
  $symbol = $symbol.ToUpperInvariant()
  $seed = Get-SymbolHash $symbol
  $slot = [Math]::Floor(((Get-Date).TimeOfDay.TotalMinutes) / 3)
  $base = 45 + ($seed % 260)
  $values = New-Object System.Collections.Generic.List[double]
  $price = [double]$base
  for ($i = 0; $i -lt 14; $i++) {
    $wave = [Math]::Sin(($i + $seed + $slot) / 4.8) * (1.2 + ($seed % 7) / 5)
    $bump = (Get-SeededNoise ($seed + $i * 13 + $slot * 19)) - 0.48
    $price = [Math]::Max(5, $price + $wave * 0.36 + $bump * 2.1)
    $values.Add([Math]::Round($price, 2))
  }
  $first = $values[0]
  $last = $values[$values.Count - 1]
  $change = if ($first -ne 0) { (($last - $first) / $first) * 100 } else { 0 }
  return [pscustomobject]@{
    Symbol = $symbol
    Label = Get-SymbolLabel $symbol
    Subtext = Get-SymbolSubtext $symbol
    Price = $last
    Change = $change
    Values = $values
  }
}

function Format-Money($value) {
  return "$" + $value.ToString("N2", [System.Globalization.CultureInfo]::GetCultureInfo("en-US"))
}

function Get-ChangeBrush($isUp) {
  if ($isUp) { return "#F8F4E8" }
  return "#FF5D4D"
}

function Get-ChangeText($value) {
  return "{0}{1:N2}%" -f ($(if ($value -ge 0) { "+" } else { "" }), $value)
}

function Add-StockRow($item) {
  $isUp = $item.Change -ge 0
  $changeBrush = Get-ChangeBrush $isUp
  $row = New-Object System.Windows.Controls.Border
  $row.CornerRadius = "0"
  $row.BorderThickness = "1"
  $row.BorderBrush = if ($isUp) { "#66F8F4E8" } else { "#99FF5D4D" }
  $row.Background = if ($isUp) { "#19000000" } else { "#220F0302" }
  $row.Padding = "8,7"
  $row.Margin = "0,0,0,7"

  $grid = New-Object System.Windows.Controls.Grid
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) | Out-Null
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) | Out-Null
  $accentCol = New-Object System.Windows.Controls.ColumnDefinition
  $accentCol.Width = "4"
  $grid.ColumnDefinitions.Add($accentCol) | Out-Null
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) | Out-Null
  $col2 = New-Object System.Windows.Controls.ColumnDefinition
  $col2.Width = "Auto"
  $grid.ColumnDefinitions.Add($col2) | Out-Null

  $accent = New-Object System.Windows.Shapes.Rectangle
  $accent.Width = 3
  $accent.Margin = "0,1,7,1"
  $accent.Fill = $changeBrush
  [System.Windows.Controls.Grid]::SetColumn($accent, 0)
  [System.Windows.Controls.Grid]::SetRowSpan($accent, 2)

  $name = New-Object System.Windows.Controls.TextBlock
  $name.Text = $item.Label
  $name.Foreground = "#E9E6DD"
  $name.FontSize = 14
  $name.FontWeight = [System.Windows.FontWeights]::Black
  $name.FontFamily = "Bahnschrift SemiCondensed, Segoe UI"
  [System.Windows.Controls.Grid]::SetColumn($name, 1)
  [System.Windows.Controls.Grid]::SetRow($name, 0)

  $price = New-Object System.Windows.Controls.TextBlock
  $price.Text = if ($item.Subtext) { (Format-Money $item.Price) + "  " + $item.Subtext } else { Format-Money $item.Price }
  $price.Foreground = "#86847D"
  $price.FontSize = 11
  $price.Margin = "82,2,0,0"
  $price.FontFamily = "Consolas, Segoe UI"
  [System.Windows.Controls.Grid]::SetColumn($price, 1)
  [System.Windows.Controls.Grid]::SetRow($price, 0)

  $changeBadge = New-Object System.Windows.Controls.Border
  $changeBadge.CornerRadius = "0"
  $changeBadge.BorderThickness = "1,0,1,1"
  $changeBadge.BorderBrush = $changeBrush
  $changeBadge.Background = if ($isUp) { "#18F8F4E8" } else { "#24FF5D4D" }
  $changeBadge.Padding = "8,2"
  $changeBadge.MinWidth = 74
  [System.Windows.Controls.Grid]::SetColumn($changeBadge, 2)
  [System.Windows.Controls.Grid]::SetRow($changeBadge, 0)

  $change = New-Object System.Windows.Controls.TextBlock
  $change.Text = Get-ChangeText $item.Change
  $change.Foreground = $changeBrush
  $change.FontFamily = "Bahnschrift SemiCondensed, Consolas"
  $change.FontSize = 15
  $change.FontWeight = [System.Windows.FontWeights]::Black
  $change.TextAlignment = [System.Windows.TextAlignment]::Right
  $changeBadge.Child = $change

  $bars = New-Object System.Windows.Controls.StackPanel
  $bars.Orientation = [System.Windows.Controls.Orientation]::Horizontal
  $bars.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
  $bars.Margin = "0,7,0,0"
  [System.Windows.Controls.Grid]::SetColumn($bars, 1)
  [System.Windows.Controls.Grid]::SetColumnSpan($bars, 2)
  [System.Windows.Controls.Grid]::SetRow($bars, 1)

  $min = ($item.Values | Measure-Object -Minimum).Minimum
  $max = ($item.Values | Measure-Object -Maximum).Maximum
  $spread = [Math]::Max(0.01, $max - $min)
  foreach ($value in $item.Values) {
    $bar = New-Object System.Windows.Shapes.Rectangle
    $bar.Width = 17
    $bar.Height = 4 + (($value - $min) / $spread) * 18
    $bar.Margin = "0,0,4,0"
    $bar.RadiusX = 0
    $bar.RadiusY = 0
    $bar.Fill = $changeBrush
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
  $stockList.Children.Clear()
  foreach ($item in $stockItems) {
    Add-StockRow $item
  }
  $total = ($stockItems | Measure-Object -Property Price -Sum).Sum * 8
  $avgChange = ($stockItems | Measure-Object -Property Change -Average).Average
  $portfolioText.Text = Format-Money $total
  $portfolioChangeText.Text = Get-ChangeText $avgChange
  $portfolioChangeText.Foreground = Get-ChangeBrush ($avgChange -ge 0)
  $clockText.Text = (Get-Date).ToString("HH:mm")
  $statusText.Text = "每3分钟自动刷新；模拟行情；鼠标穿透"
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
