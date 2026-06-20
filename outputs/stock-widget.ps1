param(
  [string[]]$Symbols = @("MSFT", "AAPL", "NVDA", "TSLA", "AMD")
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
        Width="390" Height="360"
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
            <TextBlock x:Name="PortfolioChangeText" Text="+0.00%" Foreground="#E9E6DD" FontSize="18" FontWeight="Black" TextAlignment="Right"/>
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

function Get-StockSnapshot($symbol) {
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
    Price = $last
    Change = $change
    Values = $values
  }
}

function Format-Money($value) {
  return "$" + $value.ToString("N2", [System.Globalization.CultureInfo]::GetCultureInfo("en-US"))
}

function Add-StockRow($item) {
  $isUp = $item.Change -ge 0
  $row = New-Object System.Windows.Controls.Border
  $row.CornerRadius = "2"
  $row.BorderThickness = "1"
  $row.BorderBrush = if ($isUp) { "#4CE9E6DD" } else { "#55B7B1A2" }
  $row.Background = if ($isUp) { "#1FE9E6DD" } else { "#18B7B1A2" }
  $row.Padding = "9,7"
  $row.Margin = "0,0,0,7"

  $grid = New-Object System.Windows.Controls.Grid
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) | Out-Null
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) | Out-Null
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) | Out-Null
  $col2 = New-Object System.Windows.Controls.ColumnDefinition
  $col2.Width = "Auto"
  $grid.ColumnDefinitions.Add($col2) | Out-Null

  $name = New-Object System.Windows.Controls.TextBlock
  $name.Text = $item.Symbol
  $name.Foreground = "#E9E6DD"
  $name.FontSize = 15
  $name.FontWeight = [System.Windows.FontWeights]::Black
  [System.Windows.Controls.Grid]::SetColumn($name, 0)
  [System.Windows.Controls.Grid]::SetRow($name, 0)

  $price = New-Object System.Windows.Controls.TextBlock
  $price.Text = Format-Money $item.Price
  $price.Foreground = "#86847D"
  $price.FontSize = 12
  $price.Margin = "70,2,0,0"
  [System.Windows.Controls.Grid]::SetColumn($price, 0)
  [System.Windows.Controls.Grid]::SetRow($price, 0)

  $change = New-Object System.Windows.Controls.TextBlock
  $change.Text = ("{0}{1:N2}%" -f ($(if ($isUp) { "+" } else { "" }), $item.Change))
  $change.Foreground = if ($isUp) { "#E9E6DD" } else { "#B7B1A2" }
  $change.FontSize = 14
  $change.FontWeight = [System.Windows.FontWeights]::Black
  $change.TextAlignment = [System.Windows.TextAlignment]::Right
  [System.Windows.Controls.Grid]::SetColumn($change, 1)
  [System.Windows.Controls.Grid]::SetRow($change, 0)

  $bars = New-Object System.Windows.Controls.StackPanel
  $bars.Orientation = [System.Windows.Controls.Orientation]::Horizontal
  $bars.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
  $bars.Margin = "0,7,0,0"
  [System.Windows.Controls.Grid]::SetColumnSpan($bars, 2)
  [System.Windows.Controls.Grid]::SetRow($bars, 1)

  $min = ($item.Values | Measure-Object -Minimum).Minimum
  $max = ($item.Values | Measure-Object -Maximum).Maximum
  $spread = [Math]::Max(0.01, $max - $min)
  foreach ($value in $item.Values) {
    $bar = New-Object System.Windows.Shapes.Rectangle
    $bar.Width = 19
    $bar.Height = 5 + (($value - $min) / $spread) * 24
    $bar.Margin = "0,0,4,0"
    $bar.RadiusX = 8
    $bar.RadiusY = 8
    $bar.Fill = if ($isUp) { "#DDE9E6DD" } else { "#CCB7B1A2" }
    $bars.Children.Add($bar) | Out-Null
  }

  $grid.Children.Add($name) | Out-Null
  $grid.Children.Add($price) | Out-Null
  $grid.Children.Add($change) | Out-Null
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
  $portfolioChangeText.Text = "{0}{1:N2}%" -f ($(if ($avgChange -ge 0) { "+" } else { "" }), $avgChange)
  $portfolioChangeText.Foreground = if ($avgChange -ge 0) { "#E9E6DD" } else { "#B7B1A2" }
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
