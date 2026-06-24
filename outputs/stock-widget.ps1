param(
  [string[]]$Symbols = @("SPCX", "NVDA", "AMZN", "TSLA", "AAPL", "^GSPC", "QQQ", "SMH")
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
    $savedValue = Get-Content -LiteralPath $symbolsPath -Raw | ConvertFrom-Json
    $savedSymbols = @(
      foreach ($entry in @($savedValue)) {
        @(([string]$entry) -split '[,\s]+' | Where-Object { $_ })
      }
    )
    if ($savedSymbols.Count -gt 0) {
      $Symbols = @($savedSymbols | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Where-Object { $_ -and $_ -ne "M" } | Select-Object -Unique)
    }
  } catch {}
}

$preferredOrder = @("SPCX", "NVDA", "AMZN", "TSLA", "AAPL", "^GSPC", "QQQ", "SMH")
$orderedSymbols = New-Object System.Collections.Generic.List[string]
foreach ($candidate in $preferredOrder) {
  if ($Symbols -contains $candidate) { $orderedSymbols.Add($candidate) }
}
foreach ($candidate in @($Symbols)) {
  if ($candidate -notin $preferredOrder -and $candidate -ne "M") { $orderedSymbols.Add($candidate) }
}
$Symbols = @($orderedSymbols)

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
  <Window.Resources>
    <Style TargetType="{x:Type ScrollBar}">
      <Setter Property="Width" Value="8"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type ScrollBar}">
            <Grid Width="8" Background="Transparent">
              <Track x:Name="PART_Track" IsDirectionReversed="True">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="{x:Static ScrollBar.PageUpCommand}" Opacity="0"/>
                </Track.DecreaseRepeatButton>
                <Track.Thumb>
                  <Thumb>
                    <Thumb.Template>
                      <ControlTemplate TargetType="{x:Type Thumb}">
                        <Border Width="4" CornerRadius="2" Background="#806B5353"/>
                      </ControlTemplate>
                    </Thumb.Template>
                  </Thumb>
                </Track.Thumb>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="{x:Static ScrollBar.PageDownCommand}" Opacity="0"/>
                </Track.IncreaseRepeatButton>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
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
        <RowDefinition Height="10"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="10"/>
        <RowDefinition Height="Auto"/>
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

      <DockPanel x:Name="HeaderDragSurface" Grid.Row="0" Background="#01000000" Cursor="SizeAll">
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

      <Grid Grid.Row="4">
        <Grid.RowDefinitions>
          <RowDefinition Height="3*"/>
          <RowDefinition Height="8"/>
          <RowDefinition Height="2*"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" CornerRadius="10" Background="#26110E0F" BorderBrush="#385E4747" BorderThickness="1" Padding="8,6">
          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="6"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <DockPanel>
              <TextBlock x:Name="EquityHeader" Text="个股 / EQUITIES" Foreground="#C6B99E" FontFamily="Bahnschrift SemiCondensed" FontSize="12" FontWeight="Black"/>
              <TextBlock Text="↕" Foreground="#806B5A56" FontSize="13" HorizontalAlignment="Right"/>
            </DockPanel>
            <ScrollViewer x:Name="EquityViewport" Grid.Row="2"
                          VerticalScrollBarVisibility="Auto"
                          HorizontalScrollBarVisibility="Disabled"
                          PanningMode="VerticalOnly"
                          CanContentScroll="False"
                          ClipToBounds="True"
                          Background="Transparent">
              <StackPanel x:Name="EquityList" VerticalAlignment="Top"/>
            </ScrollViewer>
          </Grid>
        </Border>

        <GridSplitter Grid.Row="1" Height="8" HorizontalAlignment="Stretch" VerticalAlignment="Center"
                      Background="#01000000" Cursor="SizeNS">
          <GridSplitter.Template>
            <ControlTemplate TargetType="{x:Type GridSplitter}">
              <Grid Background="Transparent">
                <Border Width="54" Height="2" CornerRadius="1" Background="#706B5353" HorizontalAlignment="Center"/>
              </Grid>
            </ControlTemplate>
          </GridSplitter.Template>
        </GridSplitter>

        <Border Grid.Row="2" CornerRadius="10" Background="#26110E0F" BorderBrush="#385E4747" BorderThickness="1" Padding="8,6">
          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="6"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <DockPanel>
              <TextBlock x:Name="FundHeader" Text="指数与 ETF / FUNDS" Foreground="#C6B99E" FontFamily="Bahnschrift SemiCondensed" FontSize="12" FontWeight="Black"/>
              <TextBlock Text="↕" Foreground="#806B5A56" FontSize="13" HorizontalAlignment="Right"/>
            </DockPanel>
            <ScrollViewer x:Name="FundViewport" Grid.Row="2"
                          VerticalScrollBarVisibility="Auto"
                          HorizontalScrollBarVisibility="Disabled"
                          PanningMode="VerticalOnly"
                          CanContentScroll="False"
                          ClipToBounds="True"
                          Background="Transparent">
              <StackPanel x:Name="FundList" VerticalAlignment="Top"/>
            </ScrollViewer>
          </Grid>
        </Border>
      </Grid>

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
$equityList = $window.FindName("EquityList")
$fundList = $window.FindName("FundList")
$equityViewport = $window.FindName("EquityViewport")
$fundViewport = $window.FindName("FundViewport")
$equityHeader = $window.FindName("EquityHeader")
$fundHeader = $window.FindName("FundHeader")
$headerDragSurface = $window.FindName("HeaderDragSurface")
$statusText = $window.FindName("StatusText")
$addSymbolButton = $window.FindName("AddSymbolButton")
$heightGrip = $window.FindName("HeightGrip")
$mainSoftField = $window.FindName("MainSoftField")
$script:hwnd = [IntPtr]::Zero

function Save-Symbols {
  try {
    New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
    ConvertTo-Json -InputObject @($script:Symbols) | Set-Content -LiteralPath $symbolsPath -Encoding UTF8
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

  $addButton.Add_Click({
    $dialogWindow = [System.Windows.Window]::GetWindow($this)
    $symbolInput = $dialogWindow.FindName("SymbolInput")
    $value = ([string]$symbolInput.Text).Trim().ToUpperInvariant()
    if ($value) {
      $script:newSymbol = $value
      $dialogWindow.DialogResult = $true
    }
  })
  $cancelButton.Add_Click({
    [System.Windows.Window]::GetWindow($this).DialogResult = $false
  })
  $input.Add_KeyDown({
    $dialogWindow = [System.Windows.Window]::GetWindow($this)
    if ($_.Key -eq [System.Windows.Input.Key]::Enter) {
      $value = ([string]$this.Text).Trim().ToUpperInvariant()
      if ($value) {
        $script:newSymbol = $value
        $dialogWindow.DialogResult = $true
      }
    } elseif ($_.Key -eq [System.Windows.Input.Key]::Escape) {
      $dialogWindow.DialogResult = $false
    }
  })
  $dialog.Add_ContentRendered({
    $this.FindName("SymbolInput").Focus() | Out-Null
  })
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
    $values = @($closes | ForEach-Object { [Math]::Round($_, 2) })
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
    $sessionOpen = if ($values.Count -gt 0) { [double]$values[0] } else { $price }
    $openChange = if ($null -ne $price -and $null -ne $sessionOpen -and $sessionOpen -ne 0) {
      (($price - $sessionOpen) / $sessionOpen) * 100
    } else {
      0
    }
    $dayLow = if ($values.Count -gt 0) { ($values | Measure-Object -Minimum).Minimum } else { $price }
    $dayHigh = if ($values.Count -gt 0) { ($values | Measure-Object -Maximum).Maximum } else { $price }

    $snapshot = [pscustomobject]@{
      Symbol = $symbol
      Label = $label
      Subtext = if ($subtext) { $subtext } elseif ($meta.shortName) { [string]$meta.shortName } else { "" }
      Price = if ($null -ne $price) { [Math]::Round($price, 2) } else { $null }
      Change = $change
      OpenChange = $openChange
      DayLow = $dayLow
      DayHigh = $dayHigh
      AssetType = if ($meta.instrumentType) { [string]$meta.instrumentType } else { "EQUITY" }
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
      OpenChange = $snapshot.OpenChange
      DayLow = $snapshot.DayLow
      DayHigh = $snapshot.DayHigh
      AssetType = $snapshot.AssetType
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
        OpenChange = ConvertTo-DoubleOrNull $cached.OpenChange
        DayLow = ConvertTo-DoubleOrNull $cached.DayLow
        DayHigh = ConvertTo-DoubleOrNull $cached.DayHigh
        AssetType = if ($cached.AssetType) { [string]$cached.AssetType } elseif ($symbol.StartsWith("^")) { "INDEX" } else { "EQUITY" }
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
      OpenChange = 0
      DayLow = $null
      DayHigh = $null
      AssetType = if ($symbol.StartsWith("^")) { "INDEX" } else { "EQUITY" }
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

function Add-StockRow($item, $targetList) {
  $isUp = ($item.Change -ge 0)
  $isUpFromOpen = ($item.OpenChange -ge 0)
  $changeBrush = Get-ChangeBrush $isUp
  $trendBrush = Get-ChangeBrush $isUpFromOpen
  $row = New-Object System.Windows.Controls.Border
  $row.CornerRadius = "10"
  $row.BorderThickness = "1"
  $row.BorderBrush = if ($isUp) { "#405C4B32" } else { "#526E3030" }
  $row.Background = if ($isUp) { "#5A131110" } else { "#64190E0F" }
  $row.Padding = "10,8"
  $row.Margin = "0,0,0,7"

  $grid = New-Object System.Windows.Controls.Grid
  foreach ($height in @("Auto", "42", "Auto")) {
    $definition = New-Object System.Windows.Controls.RowDefinition
    $definition.Height = $height
    $grid.RowDefinitions.Add($definition) | Out-Null
  }
  $accentCol = New-Object System.Windows.Controls.ColumnDefinition
  $accentCol.Width = "3"
  $grid.ColumnDefinitions.Add($accentCol) | Out-Null
  $nameCol = New-Object System.Windows.Controls.ColumnDefinition
  $nameCol.Width = "*"
  $grid.ColumnDefinitions.Add($nameCol) | Out-Null
  $priceCol = New-Object System.Windows.Controls.ColumnDefinition
  $priceCol.Width = "Auto"
  $grid.ColumnDefinitions.Add($priceCol) | Out-Null
  $changeCol = New-Object System.Windows.Controls.ColumnDefinition
  $changeCol.Width = "Auto"
  $grid.ColumnDefinitions.Add($changeCol) | Out-Null

  $accent = New-Object System.Windows.Shapes.Rectangle
  $accent.Width = 2
  $accent.Margin = "0,1,7,1"
  $accent.RadiusX = 2
  $accent.RadiusY = 2
  $accent.Fill = $trendBrush
  [System.Windows.Controls.Grid]::SetColumn($accent, 0)
  [System.Windows.Controls.Grid]::SetRowSpan($accent, 3)

  $identity = New-Object System.Windows.Controls.StackPanel
  $identity.Orientation = [System.Windows.Controls.Orientation]::Vertical
  [System.Windows.Controls.Grid]::SetColumn($identity, 1)
  [System.Windows.Controls.Grid]::SetRow($identity, 0)

  $name = New-Object System.Windows.Controls.TextBlock
  $name.Text = $item.Label
  $name.Foreground = "#F0E7DF"
  $name.FontSize = 16
  $name.FontWeight = [System.Windows.FontWeights]::Black
  $name.FontFamily = "Bahnschrift SemiCondensed, Segoe UI"

  $subtext = New-Object System.Windows.Controls.TextBlock
  $subtext.Text = if ($item.IsLive) { [string]$item.Subtext } else { "$($item.Subtext)  $($item.Note)" }
  $subtext.Foreground = "#887A74"
  $subtext.FontSize = 9
  $subtext.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
  $subtext.MaxWidth = 128
  $identity.Children.Add($name) | Out-Null
  $identity.Children.Add($subtext) | Out-Null

  $price = New-Object System.Windows.Controls.TextBlock
  $price.Text = Format-Money $item.Price
  $price.Foreground = "#F0E7DF"
  $price.FontSize = 20
  $price.FontWeight = [System.Windows.FontWeights]::Bold
  $price.Margin = "8,0,10,0"
  $price.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
  $price.FontFamily = "Bahnschrift SemiCondensed, Consolas"
  [System.Windows.Controls.Grid]::SetColumn($price, 2)
  [System.Windows.Controls.Grid]::SetRow($price, 0)

  $changeBadge = New-Object System.Windows.Controls.Border
  $changeBadge.CornerRadius = "8"
  $changeBadge.BorderThickness = "1"
  $changeBadge.BorderBrush = $changeBrush
  $changeBadge.Background = if ($isUp) { "#243E3020" } else { "#2C561719" }
  $changeBadge.Padding = "8,3"
  $changeBadge.MinWidth = 82
  $changeBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
  [System.Windows.Controls.Grid]::SetColumn($changeBadge, 3)
  [System.Windows.Controls.Grid]::SetRow($changeBadge, 0)

  $change = New-Object System.Windows.Controls.TextBlock
  $change.Text = Get-ChangeText $item.Change
  $change.Foreground = $changeBrush
  $change.FontFamily = "Bahnschrift SemiCondensed, Consolas"
  $change.FontSize = 19
  $change.FontWeight = [System.Windows.FontWeights]::Black
  $change.TextAlignment = [System.Windows.TextAlignment]::Right
  $changeBadge.Child = $change

  $chart = New-Object System.Windows.Controls.Canvas
  $chart.Height = 38
  $chart.Margin = "0,3,0,1"
  $chart.ClipToBounds = $true
  [System.Windows.Controls.Grid]::SetColumn($chart, 1)
  [System.Windows.Controls.Grid]::SetColumnSpan($chart, 3)
  [System.Windows.Controls.Grid]::SetRow($chart, 1)

  $chartValues = @($item.Values)
  if ($chartValues.Count -eq 0) { $chartValues = @(0, 0) }
  $min = ($chartValues | Measure-Object -Minimum).Minimum
  $max = ($chartValues | Measure-Object -Maximum).Maximum
  $spread = [Math]::Max(0.01, $max - $min)
  $chartWidth = 354.0
  $chartHeight = 34.0
  $baselineValue = [double]$chartValues[0]
  $baselineY = $chartHeight - (($baselineValue - $min) / $spread) * $chartHeight

  $baseline = New-Object System.Windows.Shapes.Line
  $baseline.X1 = 0
  $baseline.X2 = $chartWidth
  $baseline.Y1 = $baselineY
  $baseline.Y2 = $baselineY
  $baseline.Stroke = "#407E6A65"
  $baseline.StrokeThickness = 1
  $baseline.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection
  $baseline.StrokeDashArray.Add(3)
  $baseline.StrokeDashArray.Add(3)
  $chart.Children.Add($baseline) | Out-Null

  $polyline = New-Object System.Windows.Shapes.Polyline
  $polyline.Stroke = $trendBrush
  $polyline.StrokeThickness = 2.6
  $polyline.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
  $points = New-Object System.Windows.Media.PointCollection
  for ($i = 0; $i -lt $chartValues.Count; $i++) {
    $x = if ($chartValues.Count -le 1) { 0 } else { ($i / ($chartValues.Count - 1)) * $chartWidth }
    $y = $chartHeight - (([double]$chartValues[$i] - $min) / $spread) * $chartHeight
    $points.Add([System.Windows.Point]::new($x, $y))
  }
  $polyline.Points = $points
  $chart.Children.Add($polyline) | Out-Null

  $lastPointIndex = $points.Count - 1
  foreach ($pointIndex in @(0, $lastPointIndex)) {
    if ($pointIndex -lt 0 -or $pointIndex -ge $points.Count) { continue }
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = if ($pointIndex -eq $points.Count - 1) { 7 } else { 5 }
    $dot.Height = $dot.Width
    $dot.Fill = if ($pointIndex -eq $points.Count - 1) { $trendBrush } else { "#A99E8D" }
    [System.Windows.Controls.Canvas]::SetLeft($dot, $points[$pointIndex].X - ($dot.Width / 2))
    [System.Windows.Controls.Canvas]::SetTop($dot, $points[$pointIndex].Y - ($dot.Height / 2))
    $chart.Children.Add($dot) | Out-Null
  }

  $stats = New-Object System.Windows.Controls.TextBlock
  $stats.Text = "开盘→现在 $(Get-ChangeText $item.OpenChange)    低 $(Format-Money $item.DayLow)    高 $(Format-Money $item.DayHigh)"
  $stats.Foreground = $trendBrush
  $stats.FontFamily = "Consolas, Segoe UI"
  $stats.FontSize = 11
  $stats.FontWeight = [System.Windows.FontWeights]::Bold
  $stats.Margin = "0,2,0,0"
  [System.Windows.Controls.Grid]::SetColumn($stats, 1)
  [System.Windows.Controls.Grid]::SetColumnSpan($stats, 3)
  [System.Windows.Controls.Grid]::SetRow($stats, 2)

  $grid.Children.Add($accent) | Out-Null
  $grid.Children.Add($identity) | Out-Null
  $grid.Children.Add($price) | Out-Null
  $grid.Children.Add($changeBadge) | Out-Null
  $grid.Children.Add($chart) | Out-Null
  $grid.Children.Add($stats) | Out-Null
  $row.Child = $grid
  $targetList.Children.Add($row) | Out-Null
}

function Update-Widget {
  $stockItems = @($Symbols | ForEach-Object { Get-StockSnapshot $_.ToUpperInvariant() })
  Save-QuoteCache
  $equityList.Children.Clear()
  $fundList.Children.Clear()

  $equities = @($stockItems | Where-Object { $_.AssetType -notin @("ETF", "INDEX", "MUTUALFUND") })
  $fundsAndIndices = @($stockItems | Where-Object { $_.AssetType -in @("ETF", "INDEX", "MUTUALFUND") })
  $equityHeader.Text = "个股 / EQUITIES  $($equities.Count)"
  $fundHeader.Text = "指数与 ETF / FUNDS  $($fundsAndIndices.Count)"

  if ($equities.Count -gt 0) {
    foreach ($item in $equities) {
      try { Add-StockRow $item $equityList } catch {
        $statusText.Text = "$($item.Symbol) 渲染失败，其他行情继续显示"
      }
    }
  }
  if ($fundsAndIndices.Count -gt 0) {
    foreach ($item in $fundsAndIndices) {
      try { Add-StockRow $item $fundList } catch {
        $statusText.Text = "$($item.Symbol) 渲染失败，其他行情继续显示"
      }
    }
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
      $window.Left = [Math]::Max($area.Left, [Math]::Min([double]$position.Left, $area.Right - $window.Width))
      $window.Top = [Math]::Max($area.Top, [Math]::Min([double]$position.Top, $area.Bottom - $window.MinHeight))
      $availableHeight = [Math]::Max($window.MinHeight, $area.Bottom - $window.Top)
      if ($position.PSObject.Properties.Name -contains "Height") {
        $window.Height = [Math]::Max($window.MinHeight, [Math]::Min([double]$position.Height, $availableHeight))
      }
    } catch {
      $window.Left = $area.Right - $window.Width - 18
      $window.Top = $area.Top + 360
    }
  } else {
    $window.Left = $area.Right - $window.Width - 18
    $window.Top = $area.Top + 360
  }
  $window.MaxHeight = [Math]::Max($window.MinHeight, $area.Bottom - $window.Top)
  if ($window.Height -gt $window.MaxHeight) { $window.Height = $window.MaxHeight }
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

$headerDragSurface.Add_MouseLeftButtonDown({
  if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
    if ($addSymbolButton.IsMouseOver) { return }
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

Save-Symbols
Update-Widget
$window.ShowDialog() | Out-Null

