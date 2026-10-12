# Grid Square Worked - D&C Ham Adventure (M7ANI) 2026
# ONE FILE. Save as GridSquareWorked.ps1 and run.

param([switch]$BuildOnly)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {
    $sig = @'
using System; using System.Diagnostics; using System.Runtime.InteropServices; using System.Text;
public class WinCleaner {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool DestroyWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public static void CloseOurTooltips() {
        uint myPid = (uint)Process.GetCurrentProcess().Id;
        EnumWindows((h, l) => {
            var sb = new StringBuilder(256); GetClassName(h, sb, 256);
            if (sb.ToString().StartsWith("tooltips_class")) {
                uint pid; GetWindowThreadProcessId(h, out pid);
                if (pid == myPid) DestroyWindow(h);
            }
            return true; }, IntPtr.Zero);
    }
}
'@
    Add-Type -TypeDefinition $sig -ErrorAction SilentlyContinue
    [WinCleaner]::CloseOurTooltips()
} catch { }

try {
    $menuSig = @'
using System.Drawing;
using System.Windows.Forms;
public class DarkMenuColorTable : ProfessionalColorTable {
    private static readonly Color DarkBg = Color.FromArgb(45, 45, 48);
    private static readonly Color HoverBg = Color.FromArgb(80, 80, 92);
    private static readonly Color Border = Color.FromArgb(90, 90, 100);
    public override Color MenuItemSelected { get { return HoverBg; } }
    public override Color MenuItemSelectedGradientBegin { get { return HoverBg; } }
    public override Color MenuItemSelectedGradientEnd { get { return HoverBg; } }
    public override Color MenuItemBorder { get { return Border; } }
    public override Color MenuItemPressedGradientBegin { get { return HoverBg; } }
    public override Color MenuItemPressedGradientMiddle { get { return HoverBg; } }
    public override Color MenuItemPressedGradientEnd { get { return HoverBg; } }
    public override Color MenuBorder { get { return Border; } }
    public override Color ToolStripDropDownBackground { get { return DarkBg; } }
    public override Color ImageMarginGradientBegin { get { return DarkBg; } }
    public override Color ImageMarginGradientMiddle { get { return DarkBg; } }
    public override Color ImageMarginGradientEnd { get { return DarkBg; } }
    public override Color ToolStripBorder { get { return Border; } }
    public override Color SeparatorDark { get { return Border; } }
    public override Color SeparatorLight { get { return Border; } }
    public override Color ToolStripGradientBegin { get { return DarkBg; } }
    public override Color ToolStripGradientMiddle { get { return DarkBg; } }
    public override Color ToolStripGradientEnd { get { return DarkBg; } }
}
'@
    Add-Type -TypeDefinition $menuSig -ReferencedAssemblies System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
} catch { }

function Build-SelfToExe {
    param([string]$SourceFile, [bool]$Silent = $false)
    $outFile = Join-Path (Split-Path $SourceFile) 'GridSquareWorked.exe'
    $needInstall = $false
    try { if (-not (Get-Module -ListAvailable -Name ps2exe)) { $needInstall = $true } } catch { $needInstall = $true }
    if ($needInstall) {
        if (-not $Silent) { Write-Host "Installing ps2exe module (one time)..." -ForegroundColor Yellow }
        try { $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue; if ($repo -and $repo.InstallationPolicy -ne 'Trusted') { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } } catch { }
        try { Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop } catch { return "Failed to install ps2exe: $_" }
    }
    Import-Module ps2exe -Force
    if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
    try {
        Invoke-PS2EXE -InputFile $SourceFile -OutputFile $outFile -noConsole `
            -Title 'Grid Square Worked' `
            -Description 'Maidenhead grid square worked tracker' `
            -Product 'Grid Square Worked' `
            -Company 'D&C Ham Adventure (M7ANI)' `
            -Copyright '© D&C Ham Adventure (M7ANI) 2026' `
            -Version '1.5.1.0' | Out-Null
    } catch { return "Compile failed: $_" }
    if (Test-Path $outFile) { return $null }
    return "Build did not produce an exe."
}

if ($BuildOnly) {
    $src = $PSCommandPath; if (-not $src) { $src = $MyInvocation.MyCommand.Path }
    Write-Host "Building $src ..."
    $err = Build-SelfToExe -SourceFile $src
    if ($err) { Write-Host "ERROR: $err" -ForegroundColor Red } else { Write-Host "Success. GridSquareWorked.exe created next to the script." -ForegroundColor Green }
    exit
}

$script:LogEntries   = [System.Collections.Generic.List[object]]::new()
$script:Manual4      = [System.Collections.Generic.HashSet[string]]::new()
$script:Manual6      = [System.Collections.Generic.HashSet[string]]::new()
$script:Confirmed4   = [System.Collections.Generic.HashSet[string]]::new()
$script:Confirmed6   = [System.Collections.Generic.HashSet[string]]::new()
$script:CurrentBase  = ''
$script:MapBitmaps   = @{}
$script:MapBoxes     = @{}
$script:TabPages     = @{}
$script:WorldImg     = $null
$script:ActiveMapKey = 'UK'
$script:HoverLabel   = $null
$script:PropGrid     = $null
$script:PropHeader   = $null
$script:PropStatus   = $null
$script:RenderTimer  = $null
$script:StartupTimer = $null
$script:ClockTimer   = $null
$script:CleanTimer   = $null
$script:DxTimer      = $null
$script:ClockLabel   = $null
$script:TabCtrl      = $null
$script:GridCountLabel = $null
$script:ZoomSlider   = $null
$script:LegendSw4    = $null
$script:LegendSw6    = $null
$script:LegendSwSel  = $null
$script:DistGrid     = $null
$script:DistCombo    = $null
$script:DistHeader   = $null
$script:LogBandCombo = $null
$script:LogModeCombo = $null
$script:NoaaGrid     = $null
$script:NoaaHeader   = $null
$script:NoaaStatus   = $null
$script:DxList       = $null
$script:DxStatus     = $null
$script:DxHostBox    = $null
$script:DxPortBox    = $null
$script:DxBandCombo  = $null
$script:DxModeCombo  = $null
$script:DxTextFilter = $null
$script:DxRunspace   = $null
$script:DxPS         = $null
$script:DxHandle     = $null
$script:DxQueue      = $null
$script:DxConnected  = $false
$script:VisibleKeys  = @()
$script:MainMenu     = $null

$script:QRZSessionKey  = $null
$script:QRZSessionTime = [DateTime]::MinValue
$script:QRZSessionUser = ''

$script:DxPresets = @(
    @{ Host='hrd.wa9pie.net';       Port='8000' },
    @{ Host='dxc.nc7j.com';         Port='7373' },
    @{ Host='ve7cc.net';            Port='23'   },
    @{ Host='dxc.ve7cc.net';        Port='23'   },
    @{ Host='dxc.w1ve.com';         Port='7373' },
    @{ Host='k1ttt.net';            Port='7373' },
    @{ Host='gb7mbc.net';           Port='8000' },
    @{ Host='dx.w1nr.net';          Port='7300' },
    @{ Host='dxspots.com';          Port='23'   },
    @{ Host='dxc.w3lpl.net';        Port='7373' },
    @{ Host='cluster.srars.org';    Port='7300' },
    @{ Host='ea4ure.es';            Port='7300' },
    @{ Host='oh7lzb.dy.fi';         Port='8000' },
    @{ Host='db0sue.dyndns.org';    Port='8000' },
    @{ Host='dxc.k0xm.net';         Port='7300' },
    @{ Host='w6yx.ddns.net';        Port='7300' },
    @{ Host='wd5ixc.dyndns.org';    Port='23'   },
    @{ Host='dxc.k1ttt.net';        Port='7300' },
    @{ Host='k0blt.ddns.net';       Port='7300' },
    @{ Host='dxusa.net';            Port='7300' },
    @{ Host='cluster.iz7djl.com';   Port='8000' }
)

$script:ScriptDir = Split-Path -Parent $PSCommandPath
if (-not $script:ScriptDir) { $script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $script:ScriptDir) { $script:ScriptDir = $PWD.Path }
$script:WorldImagePath = Join-Path $script:ScriptDir 'worldmap-5400.jpg'
$script:SettingsPath   = Join-Path $script:ScriptDir 'settings.json'
$script:DataPath       = Join-Path $script:ScriptDir 'gridlog.json'

$script:DefaultVisibleTabs = @('UK','EU','NA','SA','AF','AS','OC','AN','Log','Propagation','NOAA','DXCluster')

$script:Settings = [PSCustomObject]@{
    Callsign=''; Name=''; Grid=''
    QRZUser=''; QRZPass=''; QRZApiKey=''
    AutoLocate=$true; ITUZone=''; CQZone=''
    ShowClock=$true; Clock24h=$true
    UseMiles=$false
    Theme='Light'
    VisibleTabs=@($script:DefaultVisibleTabs)
    DxHost='hrd.wa9pie.net'; DxPort='8000'
    DxCallsign=''
    DxFilterBand='All'; DxFilterMode='All'; DxFilterText=''
    LogFilterBand='All'; LogFilterMode='All'
    ShowGridLabelBg=$true
    ColorGridLabelBg='255,255,255'
    ColorGridLabelText='20,20,20'
    ColorRibbon='30,60,110'
    ColorCallsign='255,255,255'
    ColorClock='200,240,200'
    ColorZones='255,220,150'
    Color4Char='175,230,175'
    Color6Char='40,175,60'
    ColorSelection='210,100,0'
}

$script:MapViews = @{
    UK = @{ CenterLon=-4.0;   CenterLat=54.5;  PPD=60.0 }
    EU = @{ CenterLon=15.0;   CenterLat=53.0;  PPD=18.0 }
    NA = @{ CenterLon=-100.0; CenterLat=43.0;  PPD=9.0  }
    SA = @{ CenterLon=-58.0;  CenterLat=-21.0; PPD=20.0 }
    AF = @{ CenterLon=17.0;   CenterLat=2.0;   PPD=16.0 }
    AS = @{ CenterLon=100.0;  CenterLat=34.0;  PPD=8.0  }
    OC = @{ CenterLon=145.0;  CenterLat=-27.0; PPD=13.0 }
    AN = @{ CenterLon=0.0;    CenterLat=-72.0; PPD=4.0  }
}
$script:MapKeys = @('UK','EU','NA','SA','AF','AS','OC','AN')

$script:TabDefs = @(
    [PSCustomObject]@{ Key='UK';         Label='UK';             Type='Map' }
    [PSCustomObject]@{ Key='EU';         Label='Europe';         Type='Map' }
    [PSCustomObject]@{ Key='NA';         Label='North America';  Type='Map' }
    [PSCustomObject]@{ Key='SA';         Label='South America';  Type='Map' }
    [PSCustomObject]@{ Key='AF';         Label='Africa';         Type='Map' }
    [PSCustomObject]@{ Key='AS';         Label='Asia';           Type='Map' }
    [PSCustomObject]@{ Key='OC';         Label='Australia';      Type='Map' }
    [PSCustomObject]@{ Key='AN';         Label='Antarctica';     Type='Map' }
    [PSCustomObject]@{ Key='Log';        Label='Log';            Type='Log' }
    [PSCustomObject]@{ Key='Propagation';Label='Propagation';    Type='Propagation' }
    [PSCustomObject]@{ Key='NOAA';       Label='NOAA SWPC';      Type='NOAA' }
    [PSCustomObject]@{ Key='DXCluster';  Label='DX Cluster';     Type='DXCluster' }
)

$script:Drag = @{ Active=$false; Moved=$false; StartX=0; StartY=0; StartCenterLon=0.0; StartCenterLat=0.0; MapKey=$null }
$script:BandList = @('All','160m','80m','60m','40m','30m','20m','17m','15m','12m','10m','6m','4m','2m','70cm','23cm','13cm','Other')
$script:ModeList = @('All','SSB','FM','AM','CW','Data','Other')
$script:DxBandList = @('All','160m','80m','60m','40m','30m','20m','17m','15m','12m','10m','6m','2m','70cm')
$script:DxModeList = @('All','CW','SSB','USB','LSB','FT8','FT4','RTTY','PSK','AM','FM','JT65','JS8')

$script:LandPolys = @(
    @(-5.7,50.05,-5.0,50.0,-4.2,50.35,-3.5,50.6,-2.5,50.6,-1.3,50.9,-0.3,50.8,0.3,50.77,1.4,51.4,1.75,52.3,1.5,52.85,0.5,53.0,0.0,53.5,-0.2,54.1,-1.4,55.0,-2.0,55.8,-2.8,56.5,-1.8,57.5,-2.0,57.9,-3.5,58.5,-3.0,58.6,-5.0,58.55,-5.9,57.6,-6.1,56.8,-5.7,56.0,-5.2,55.3,-3.6,54.7,-3.0,54.1,-3.1,53.4,-4.4,53.2,-4.7,52.8,-5.3,52.1,-5.0,51.6,-4.2,51.2,-3.5,50.6,-4.2,50.3,-5.4,50.1,-5.7,50.05),
    @(-9.5,51.5,-8.0,51.6,-6.2,51.9,-6.1,53.4,-6.0,54.0,-5.6,54.6,-6.5,55.2,-7.5,55.3,-8.7,54.7,-9.0,54.3,-9.9,53.6,-9.8,53.1,-10.2,52.2,-10.3,51.8,-9.5,51.5),
    @(-9.5,43.0,-8.0,43.7,-6.0,43.6,-4.0,43.5,-2.0,43.4,-1.7,43.5,-1.2,45.5,-1.5,46.5,-2.5,47.3,-4.8,48.5,-1.5,48.6,0.2,49.8,2.5,51.0,3.4,51.4,4.7,52.5,5.4,53.3,8.0,53.5,8.8,54.5,8.1,55.5,10.5,57.5,10.5,56.0,9.8,54.8,12.0,54.3,14.0,54.5,19.5,54.4,21.0,55.5,24.0,57.0,28.0,59.5,30.0,60.0,30.0,42.0,29.0,41.0,26.5,40.0,23.0,38.0,19.5,40.0,18.0,42.5,15.0,44.5,13.5,45.5,12.5,45.7,13.5,43.6,16.9,41.1,18.5,40.1,17.2,40.4,15.6,38.0,15.8,40.0,14.0,40.8,12.5,42.0,10.5,43.5,9.0,44.4,7.0,43.5,4.0,43.5,3.0,42.0,0.0,38.5,-2.0,36.7,-6.0,36.0,-9.5,37.0,-9.5,43.0),
    @(4.9,58.0,5.5,62.0,7.5,63.0,10.0,64.0,12.5,65.5,15.0,67.5,18.0,69.0,21.0,70.0,25.0,71.0,28.0,70.5,30.0,70.5,30.0,60.0,28.0,59.5,24.0,60.0,22.0,60.5,20.0,59.5,18.5,59.0,16.5,58.0,14.0,56.5,12.5,56.0,12.5,57.5,11.5,58.5,10.5,59.5,8.0,58.5,6.0,58.0,4.9,58.0)
)

function Get-ColorFromString { param([string]$s, [System.Drawing.Color]$default); try { $p = $s -split ','; if ($p.Count -eq 3) { return [System.Drawing.Color]::FromArgb([int]$p[0], [int]$p[1], [int]$p[2]) } } catch { }; return $default }
function Set-ColorToString { param([System.Drawing.Color]$c); return "$($c.R),$($c.G),$($c.B)" }

function Get-ThemeColors {
    param([string]$Theme)
    if ($Theme -eq 'Dark') {
        return @{
            FormBg       = [System.Drawing.Color]::FromArgb(32, 32, 34)
            FormFg       = [System.Drawing.Color]::FromArgb(230, 230, 232)
            PanelBg      = [System.Drawing.Color]::FromArgb(32, 32, 34)
            TextBg       = [System.Drawing.Color]::FromArgb(50, 50, 54)
            TextFg       = [System.Drawing.Color]::FromArgb(230, 230, 232)
            GridBg       = [System.Drawing.Color]::FromArgb(45, 45, 48)
            GridFg       = [System.Drawing.Color]::FromArgb(230, 230, 232)
            GridHeaderBg = [System.Drawing.Color]::FromArgb(60, 60, 64)
            GridHeaderFg = [System.Drawing.Color]::FromArgb(240, 240, 240)
            GridLines    = [System.Drawing.Color]::FromArgb(75, 75, 80)
            TabBg        = [System.Drawing.Color]::FromArgb(45, 45, 48)
            TabUnselBg   = [System.Drawing.Color]::FromArgb(55, 55, 58)
            TabSelBg     = [System.Drawing.Color]::FromArgb(45, 45, 48)
            TabSelLine   = [System.Drawing.Color]::FromArgb(100, 150, 210)
            TabText      = [System.Drawing.Color]::FromArgb(235, 235, 235)
            ButtonBg     = [System.Drawing.Color]::FromArgb(60, 60, 63)
            ButtonFg     = [System.Drawing.Color]::FromArgb(230, 230, 232)
            ButtonHover  = [System.Drawing.Color]::FromArgb(80, 80, 85)
            ButtonDown   = [System.Drawing.Color]::FromArgb(40, 40, 45)
            ButtonBorder = [System.Drawing.Color]::FromArgb(100, 100, 105)
            MenuBg       = [System.Drawing.Color]::FromArgb(45, 45, 48)
            MenuFg       = [System.Drawing.Color]::FromArgb(230, 230, 232)
            StatusFg     = [System.Drawing.Color]::FromArgb(130, 180, 230)
            GroupFg      = [System.Drawing.Color]::FromArgb(230, 230, 232)
            IsDark       = $true
        }
    } else {
        return @{
            FormBg       = [System.Drawing.SystemColors]::Control
            FormFg       = [System.Drawing.Color]::Black
            PanelBg      = [System.Drawing.SystemColors]::Control
            TextBg       = [System.Drawing.Color]::White
            TextFg       = [System.Drawing.Color]::Black
            GridBg       = [System.Drawing.Color]::White
            GridFg       = [System.Drawing.Color]::Black
            GridHeaderBg = [System.Drawing.SystemColors]::Control
            GridHeaderFg = [System.Drawing.Color]::Black
            GridLines    = [System.Drawing.Color]::LightGray
            TabBg        = [System.Drawing.Color]::White
            TabUnselBg   = [System.Drawing.Color]::FromArgb(230, 235, 240)
            TabSelBg     = [System.Drawing.Color]::White
            TabSelLine   = [System.Drawing.Color]::FromArgb(30, 60, 110)
            TabText      = [System.Drawing.Color]::Black
            ButtonBg     = [System.Drawing.Color]::FromArgb(240, 242, 245)
            ButtonFg     = [System.Drawing.Color]::Black
            ButtonHover  = [System.Drawing.Color]::FromArgb(215, 228, 242)
            ButtonDown   = [System.Drawing.Color]::FromArgb(190, 210, 235)
            ButtonBorder = [System.Drawing.Color]::FromArgb(150, 150, 150)
            MenuBg       = [System.Drawing.SystemColors]::Control
            MenuFg       = [System.Drawing.Color]::Black
            StatusFg     = [System.Drawing.Color]::DarkBlue
            GroupFg      = [System.Drawing.Color]::Black
            IsDark       = $false
        }
    }
}

function Set-FlatButton {
    param($btn)
    try {
        $t = Get-ThemeColors $script:Settings.Theme
        $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btn.UseVisualStyleBackColor = $false
        $btn.BackColor = $t.ButtonBg
        $btn.ForeColor = $t.ButtonFg
        $btn.FlatAppearance.BorderColor = $t.ButtonBorder
        $btn.FlatAppearance.BorderSize = 1
        $btn.FlatAppearance.MouseOverBackColor = $t.ButtonHover
        $btn.FlatAppearance.MouseDownBackColor = $t.ButtonDown
        $btn.TabStop = $false
        $btn.Add_GotFocus({ try { $f = $this.FindForm(); if ($null -ne $f) { $f.ActiveControl = $null } } catch { } })
    } catch { }
}

function Apply-Theme {
    param($Container)
    try {
        if ($null -eq $Container) { return }
        $t = Get-ThemeColors $script:Settings.Theme

        if ($Container -is [System.Windows.Forms.Form]) {
            $Container.BackColor = $t.FormBg
            $Container.ForeColor = $t.FormFg
        }

        foreach ($ctrl in @($Container.Controls)) {
            try {
                $skip = $false

                if ($ctrl -eq $script:RibbonPanel -or
                    $ctrl -eq $script:RibbonCall -or
                    $ctrl -eq $script:RibbonName -or
                    $ctrl -eq $script:ClockLabel -or
                    $ctrl -eq $script:RibbonGrid -or
                    $ctrl -eq $script:RibbonZones -or
                    $ctrl -eq $script:GridCountLabel -or
                    $ctrl -eq $script:HoverLabel) {
                    $skip = $true
                }
                if ($ctrl -eq $script:LegendSw4 -or $ctrl -eq $script:LegendSw6 -or $ctrl -eq $script:LegendSwSel) {
                    $skip = $true
                }
                if ($ctrl -is [System.Windows.Forms.PictureBox]) { $skip = $true }
                # Skip any Panel with a Tag (color swatches in Change Colours dialog)
                if ($ctrl -is [System.Windows.Forms.Panel] -and $null -ne $ctrl.Tag) { $skip = $true }

                if (-not $skip) {
                    if ($ctrl -is [System.Windows.Forms.Button]) {
                        Set-FlatButton $ctrl
                    }
                    elseif ($ctrl -is [System.Windows.Forms.TextBox]) {
                        $ctrl.BackColor = $t.TextBg
                        $ctrl.ForeColor = $t.TextFg
                    }
                    elseif ($ctrl -is [System.Windows.Forms.ComboBox]) {
                        $ctrl.BackColor = $t.TextBg
                        $ctrl.ForeColor = $t.TextFg
                    }
                    elseif ($ctrl -is [System.Windows.Forms.DataGridView]) {
                        $ctrl.BackgroundColor = $t.GridBg
                        $ctrl.GridColor = $t.GridLines
                        $ctrl.DefaultCellStyle.BackColor = $t.GridBg
                        $ctrl.DefaultCellStyle.ForeColor = $t.GridFg
                        $ctrl.DefaultCellStyle.SelectionBackColor = $t.TabSelLine
                        $ctrl.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
                        $ctrl.ColumnHeadersDefaultCellStyle.BackColor = $t.GridHeaderBg
                        $ctrl.ColumnHeadersDefaultCellStyle.ForeColor = $t.GridHeaderFg
                        $ctrl.EnableHeadersVisualStyles = $false
                        $ctrl.Refresh()
                    }
                    elseif ($ctrl -is [System.Windows.Forms.ListBox]) {
                        $ctrl.BackColor = $t.TextBg
                        $ctrl.ForeColor = $t.TextFg
                    }
                    elseif ($ctrl -is [System.Windows.Forms.TabPage]) {
                        $ctrl.BackColor = $t.TabBg
                        $ctrl.ForeColor = $t.FormFg
                    }
                    elseif ($ctrl -is [System.Windows.Forms.TabControl]) {
                        $ctrl.BackColor = $t.FormBg
                        $ctrl.Invalidate()
                    }
                    elseif ($ctrl -is [System.Windows.Forms.GroupBox]) {
                        $ctrl.ForeColor = $t.GroupFg
                        $ctrl.BackColor = $t.FormBg
                    }
                    elseif ($ctrl -is [System.Windows.Forms.Panel]) {
                        $ctrl.BackColor = $t.PanelBg
                    }
                    elseif ($ctrl -is [System.Windows.Forms.Label]) {
                        if ($ctrl -eq $script:LblStatusCtrl) {
                            $ctrl.ForeColor = $t.StatusFg
                        } else {
                            $ctrl.ForeColor = $t.FormFg
                        }
                        if ($ctrl.BackColor -ne [System.Drawing.Color]::Transparent) {
                            $ctrl.BackColor = $t.FormBg
                        }
                    }
                    elseif ($ctrl -is [System.Windows.Forms.CheckBox] -or $ctrl -is [System.Windows.Forms.RadioButton]) {
                        $ctrl.ForeColor = $t.FormFg
                        $ctrl.BackColor = $t.FormBg
                    }
                    elseif ($ctrl -is [System.Windows.Forms.MenuStrip]) {
                        $ctrl.BackColor = $t.MenuBg
                        $ctrl.ForeColor = $t.MenuFg
                        $ctrl.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::Professional
                        if ($t.IsDark) {
                            try {
                                $table = [DarkMenuColorTable]::new()
                                $ctrl.Renderer = [System.Windows.Forms.ToolStripProfessionalRenderer]::new($table)
                            } catch { }
                        } else {
                            try { $ctrl.Renderer = [System.Windows.Forms.ToolStripProfessionalRenderer]::new() } catch { }
                        }
                        foreach ($mi in $ctrl.Items) {
                            $mi.BackColor = $t.MenuBg
                            $mi.ForeColor = $t.MenuFg
                            foreach ($sub in $mi.DropDownItems) {
                                if ($sub -is [System.Windows.Forms.ToolStripMenuItem]) {
                                    $sub.BackColor = $t.MenuBg
                                    $sub.ForeColor = $t.MenuFg
                                }
                            }
                        }
                    }
                    elseif ($ctrl -is [System.Windows.Forms.TrackBar]) {
                        $ctrl.BackColor = $t.FormBg
                        $ctrl.ForeColor = $t.FormFg
                    }
                }

                if ($ctrl.Controls.Count -gt 0) {
                    Apply-Theme $ctrl
                }
            } catch { }
        }
    } catch { }
}

function Load-Settings {
    if (Test-Path $script:SettingsPath) {
        try {
            $s = Get-Content $script:SettingsPath -Raw | ConvertFrom-Json
            foreach ($p in 'Callsign','Name','Grid','QRZUser','QRZPass','QRZApiKey','ITUZone','CQZone','ColorRibbon','ColorCallsign','ColorClock','ColorZones','Color4Char','Color6Char','ColorSelection','DxHost','DxPort','DxCallsign','DxFilterBand','DxFilterMode','DxFilterText','LogFilterBand','LogFilterMode','ColorGridLabelBg','ColorGridLabelText','Theme') {
                if ($null -ne $s.$p) { $script:Settings.$p = [string]$s.$p }
            }
            if ($null -ne $s.AutoLocate)      { $script:Settings.AutoLocate      = [bool]$s.AutoLocate }
            if ($null -ne $s.ShowClock)       { $script:Settings.ShowClock       = [bool]$s.ShowClock }
            if ($null -ne $s.Clock24h)        { $script:Settings.Clock24h        = [bool]$s.Clock24h }
            if ($null -ne $s.UseMiles)        { $script:Settings.UseMiles        = [bool]$s.UseMiles }
            if ($null -ne $s.ShowGridLabelBg) { $script:Settings.ShowGridLabelBg = [bool]$s.ShowGridLabelBg }
            if ($null -ne $s.VisibleTabs) {
                $arr = @()
                foreach ($t in @($s.VisibleTabs)) { if ($t) { $arr += [string]$t } }
                if ($arr.Count -gt 0) { $script:Settings.VisibleTabs = $arr }
            }
        } catch { }
    }
    if ($script:Settings.Theme -ne 'Dark' -and $script:Settings.Theme -ne 'Light') { $script:Settings.Theme = 'Light' }
}
function Save-Settings { try { $script:Settings | ConvertTo-Json -Depth 5 | Set-Content -Path $script:SettingsPath -Encoding UTF8 } catch { } }

function Save-LogData {
    try {
        $obj = [PSCustomObject]@{
            Manual4    = @($script:Manual4)
            Manual6    = @($script:Manual6)
            LogEntries = @($script:LogEntries)
            CurrentBase = $script:CurrentBase
        }
        $obj | ConvertTo-Json -Depth 6 | Set-Content -Path $script:DataPath -Encoding UTF8
    } catch { }
}
function Load-LogData {
    if (-not (Test-Path $script:DataPath)) { return $false }
    try {
        $obj = Get-Content -Path $script:DataPath -Raw | ConvertFrom-Json
        $script:Manual4.Clear(); $script:Manual6.Clear(); $script:LogEntries.Clear()
        foreach ($g in @($obj.Manual4)) { if ($g) { $script:Manual4.Add([string]$g) | Out-Null } }
        foreach ($g in @($obj.Manual6)) { if ($g) { $script:Manual6.Add([string]$g) | Out-Null } }
        if ($obj.LogEntries) {
            foreach ($e in @($obj.LogEntries)) {
                $script:LogEntries.Add([PSCustomObject]@{ Date=$e.Date; Time=$e.Time; Call=$e.Call; Band=$e.Band; Mode=$e.Mode; SubMode=$e.SubMode; ModeCat=$e.ModeCat; Grid=$e.Grid; RSTSent=$e.RSTSent; RSTRcvd=$e.RSTRcvd; Name=$e.Name; QTH=$e.QTH }) | Out-Null
            }
        }
        $script:CurrentBase = [string]$obj.CurrentBase
        return $true
    } catch { return $false }
}
function Save-GridFile { param([string]$Path); try { $obj = [PSCustomObject]@{ Manual4=@($script:Manual4); Manual6=@($script:Manual6); LogEntries=@($script:LogEntries); CurrentBase=$script:CurrentBase }; $obj | ConvertTo-Json -Depth 4 | Set-Content -Path $Path -Encoding UTF8; return $true } catch { return $false } }
function Load-GridFile { param([string]$Path); if (-not (Test-Path $Path)) { return $false }; try { $obj = Get-Content -Path $Path -Raw | ConvertFrom-Json; $script:Manual4.Clear(); $script:Manual6.Clear(); $script:LogEntries.Clear(); foreach ($g in @($obj.Manual4)) { if ($g) { $script:Manual4.Add([string]$g) | Out-Null } }; foreach ($g in @($obj.Manual6)) { if ($g) { $script:Manual6.Add([string]$g) | Out-Null } }; if ($obj.LogEntries) { foreach ($e in @($obj.LogEntries)) { $script:LogEntries.Add([PSCustomObject]@{ Date=$e.Date; Time=$e.Time; Call=$e.Call; Band=$e.Band; Mode=$e.Mode; SubMode=$e.SubMode; ModeCat=$e.ModeCat; Grid=$e.Grid; RSTSent=$e.RSTSent; RSTRcvd=$e.RSTRcvd; Name=$e.Name; QTH=$e.QTH }) | Out-Null } }; $script:CurrentBase = [string]$obj.CurrentBase; return $true } catch { return $false } }

function Update-Clock { try { if ($null -eq $script:ClockLabel) { return }; if (-not $script:Settings.ShowClock) { $script:ClockLabel.Text = ''; return }; $now = [DateTime]::Now; $utc = [DateTime]::UtcNow; if ($script:Settings.Clock24h) { $script:ClockLabel.Text = "Local: $($now.ToString('HH:mm:ss'))   UTC: $($utc.ToString('HH:mm:ss'))" } else { $script:ClockLabel.Text = "Local: $($now.ToString('hh:mm:ss tt'))   UTC: $($utc.ToString('hh:mm:ss tt'))" } } catch { } }

function Reset-QRZCache {
    $script:QRZSessionKey  = $null
    $script:QRZSessionTime = [DateTime]::MinValue
    $script:QRZSessionUser = ''
}

function Get-QRZSession {
    param([string]$User, [string]$Pass, [string]$ApiKey = '')
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $usePass = if ($ApiKey) { $ApiKey } else { $Pass }
    $url = "https://xmldata.qrz.com/xml/current/?username=$([uri]::EscapeDataString($User));password=$([uri]::EscapeDataString($usePass))"
    $wc = [System.Net.WebClient]::new()
    $wc.Headers.Add('User-Agent', 'Mozilla/5.0')
    $raw = ''
    try { $raw = $wc.DownloadString($url) } finally { $wc.Dispose() }
    $xml = $null
    try { $xml = [xml]$raw } catch { throw "QRZ returned non-XML response:`n`n$raw" }
    $key = $null
    try { $key = $xml.QRZDatabase.Session.Key } catch { }
    if ($key) { return @{ Ok=$true; Key=$key; Raw=$raw } }
    $err = 'Unknown error'
    try { $err = [string]$xml.QRZDatabase.Session.Error } catch { }
    return @{ Ok=$false; Error=$err.Trim(); Raw=$raw }
}

function Get-QRZSessionCached {
    param([string]$User, [string]$Pass, [string]$ApiKey = '')
    if ($script:QRZSessionKey -and
        $script:QRZSessionUser -eq $User -and
        ([DateTime]::UtcNow - $script:QRZSessionTime).TotalMinutes -lt 55) {
        return @{ Ok=$true; Key=$script:QRZSessionKey; Raw='(cached session)' }
    }
    $r = Get-QRZSession -User $User -Pass $Pass -ApiKey $ApiKey
    if ($r.Ok) {
        $script:QRZSessionKey  = $r.Key
        $script:QRZSessionUser = $User
        $script:QRZSessionTime = [DateTime]::UtcNow
    }
    return $r
}

function Get-QRZCallsign { param([string]$SessionKey, [string]$Callsign); $url = "https://xmldata.qrz.com/xml/current/?s=$SessionKey;callsign=$([uri]::EscapeDataString($Callsign))"; $wc = [System.Net.WebClient]::new(); $wc.Headers.Add('User-Agent', 'Mozilla/5.0'); try { $xml = [xml]$wc.DownloadString($url) } finally { $wc.Dispose() }; try { return $xml.QRZDatabase.Callsign } catch { return $null } }

function Initialize-WorldImage {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    if (Test-Path $script:WorldImagePath) { try { $bytes = [System.IO.File]::ReadAllBytes($script:WorldImagePath); $ms = [System.IO.MemoryStream]::new($bytes); $script:WorldImg = [System.Drawing.Image]::FromStream($ms); return $true } catch { Remove-Item $script:WorldImagePath -ErrorAction SilentlyContinue } }
    $urls = @('https://eoimages.gsfc.nasa.gov/images/imagerecords/73000/73909/world.topo.bathy.200412.3x5400x2700.jpg', 'https://eoimages.gsfc.nasa.gov/images/imagerecords/57000/57730/land_ocean_ice_2048.png')
    foreach ($url in $urls) { try { $wc = [System.Net.WebClient]::new(); $wc.Headers.Add('User-Agent', 'Mozilla/5.0'); $wc.DownloadFile($url, $script:WorldImagePath); $wc.Dispose(); $bytes = [System.IO.File]::ReadAllBytes($script:WorldImagePath); $ms = [System.IO.MemoryStream]::new($bytes); $script:WorldImg = [System.Drawing.Image]::FromStream($ms); return $true } catch { Remove-Item $script:WorldImagePath -ErrorAction SilentlyContinue; continue } }
    return $false
}

function Get-ModeCategory { param([string]$Mode, [string]$SubMode); $m = ("$Mode $SubMode").ToUpper().Trim(); if ($m -match 'USB|LSB|SSB') { return 'SSB' }; if ($m -match '\bFM\b|NFM|WFM') { return 'FM' }; if ($m -match '\bAM\b|AMTOR|DSB') { return 'AM' }; if ($m -match '\bCW\b|PCW|CW-R') { return 'CW' }; if ($m -match 'RTTY|PSK|FT8|FT4|JT65|JT9|JT4|MFSK|OLIVIA|DOMINO|CONTESTIA|DATA|PACKET|JS8|HELL|THOR|Q65|FST4|WSPR') { return 'Data' }; if ($m -eq '') { return 'Other' }; return 'Other' }

function Parse-ADIFText {
    param([string]$text)
    $entries = [System.Collections.Generic.List[object]]::new()
    if (-not $text) { return $entries }
    $rx = [regex]'<([A-Za-z_]+):(\d+)(?::[A-Za-z])?>'
    foreach ($rec in [regex]::Split($text, '(?i)<EOR>')) {
        $fields = @{}
        foreach ($m in $rx.Matches($rec)) { $tag = $m.Groups[1].Value.ToUpper(); $len = [int]$m.Groups[2].Value; $start = $m.Index + $m.Length; if ($start + $len -gt $rec.Length) { continue }; $fields[$tag] = $rec.Substring($start, $len) }
        if ($fields.Count -eq 0) { continue }
        if (-not $fields.ContainsKey('CALL') -and -not $fields.ContainsKey('GRIDSQUARE') -and -not $fields.ContainsKey('MY_GRIDSQUARE')) { continue }
        $grid = ''; if ($fields.ContainsKey('GRIDSQUARE')) { $grid = $fields['GRIDSQUARE'] } elseif ($fields.ContainsKey('MY_GRIDSQUARE')) { $grid = $fields['MY_GRIDSQUARE'] }
        $grid = $grid.ToUpper().Trim()
        $mode = ''; if ($fields.ContainsKey('MODE')) { $mode = $fields['MODE'] }
        $sub = ''; if ($fields.ContainsKey('SUBMODE')) { $sub = $fields['SUBMODE'] }
        $band = ''; if ($fields.ContainsKey('BAND')) { $band = $fields['BAND'].ToLower().Trim() }
        $entries.Add([PSCustomObject]@{ Date=$fields['QSO_DATE']; Time=$fields['TIME_ON']; Call=$fields['CALL']; Band=$band; Mode=$mode; SubMode=$sub; ModeCat=(Get-ModeCategory $mode $sub); Grid=$grid; RSTSent=$fields['RST_SENT']; RSTRcvd=$fields['RST_RCVD']; Name=$fields['NAME']; QTH=$fields['QTH'] })
    }
    return $entries
}

function Rebuild-Confirmed {
    $script:Confirmed4.Clear(); $script:Confirmed6.Clear()
    foreach ($g in $script:Manual4) { $script:Confirmed4.Add($g) | Out-Null }
    foreach ($g in $script:Manual6) { $script:Confirmed6.Add($g) | Out-Null }
    $modeF='All'; $bandF='All'
    if ($null -ne $script:CboMode -and $null -ne $script:CboMode.SelectedItem) { $modeF = [string]$script:CboMode.SelectedItem }
    if ($null -ne $script:CboBand -and $null -ne $script:CboBand.SelectedItem) { $bandF = [string]$script:CboBand.SelectedItem }
    foreach ($e in $script:LogEntries) {
        if ($modeF -ne 'All' -and $e.ModeCat -ne $modeF) { continue }
        if ($bandF -ne 'All' -and $e.Band -ne $bandF) { continue }
        if (-not $e.Grid) { continue }
        if ($e.Grid.Length -ge 6) { $script:Confirmed6.Add($e.Grid.Substring(0,6)) | Out-Null; $script:Confirmed4.Add($e.Grid.Substring(0,4)) | Out-Null }
        elseif ($e.Grid.Length -ge 4) { $script:Confirmed4.Add($e.Grid.Substring(0,4)) | Out-Null }
    }
}

function Update-GridCount { try { if ($null -ne $script:GridCountLabel) { $script:GridCountLabel.Text = "Grids logged: $($script:Confirmed6.Count)" } } catch { } }

function Update-Legend {
    try {
        if ($null -ne $script:LegendSw4) { $script:LegendSw4.BackColor = Get-ColorFromString $script:Settings.Color4Char ([System.Drawing.Color]::FromArgb(175,230,175)) }
        if ($null -ne $script:LegendSw6) { $script:LegendSw6.BackColor = Get-ColorFromString $script:Settings.Color6Char ([System.Drawing.Color]::FromArgb(40,175,60)) }
        if ($null -ne $script:LegendSwSel) { $script:LegendSwSel.BackColor = Get-ColorFromString $script:Settings.ColorSelection ([System.Drawing.Color]::FromArgb(210,100,0)) }
    } catch { }
}

function Get-BoundsFromLocator { param([string]$Loc); $loc = $Loc.ToUpper(); if ($loc.Length -lt 4) { return $null }; try { $f1 = ([int][char]$loc[0]) - 65; $f2 = ([int][char]$loc[1]) - 65; $d1 = [int]::Parse($loc.Substring(2,1)); $d2 = [int]::Parse($loc.Substring(3,1)) } catch { return $null }; $lon = -180.0 + $f1 * 20.0 + $d1 * 2.0; $lat = -90.0 + $f2 * 10.0 + $d2 * 1.0; $lonSize = 2.0; $latSize = 1.0; if ($loc.Length -ge 6) { $s1 = ([int][char]$loc[4]) - 65; $s2 = ([int][char]$loc[5]) - 65; if ($s1 -lt 0 -or $s1 -gt 23 -or $s2 -lt 0 -or $s2 -gt 23) { return $null }; $lonSize = 2.0/24.0; $latSize = 1.0/24.0; $lon += $s1 * $lonSize; $lat += $s2 * $latSize }; [PSCustomObject]@{ LonMin=$lon; LonMax=$lon+$lonSize; LatMin=$lat; LatMax=$lat+$latSize; SizeLon=$lonSize; SizeLat=$latSize } }
function Get-LocatorAtLevel { param([double]$Lon, [double]$Lat, [int]$Level); $lonAdj = $Lon + 180.0; $latAdj = $Lat + 90.0; if ($lonAdj -lt 0) { $lonAdj = 0.0001 }; if ($lonAdj -ge 360) { $lonAdj = 359.9999 }; if ($latAdj -lt 0) { $latAdj = 0.0001 }; if ($latAdj -ge 180) { $latAdj = 179.9999 }; $f1 = [int][math]::Floor($lonAdj / 20.0); $f2 = [int][math]::Floor($latAdj / 10.0); $rem1 = $lonAdj - $f1 * 20.0; $rem2 = $latAdj - $f2 * 10.0; $d1 = [int][math]::Floor($rem1 / 2.0); $d2 = [int][math]::Floor($rem2 / 1.0); $base = ([string][char](65+$f1)) + ([string][char](65+$f2)) + ([string]$d1) + ([string]$d2); if ($Level -le 4) { return $base }; $rem1 -= $d1 * 2.0; $rem2 -= $d2 * 1.0; $stepLon = 2.0 / 24.0; $stepLat = 1.0 / 24.0; $s1 = [int][math]::Floor($rem1 / $stepLon); $s2 = [int][math]::Floor($rem2 / $stepLat); if ($s1 -lt 0) { $s1 = 0 }; if ($s1 -gt 23) { $s1 = 23 }; if ($s2 -lt 0) { $s2 = 0 }; if ($s2 -gt 23) { $s2 = 23 }; return $base + ([string][char](65+$s1)) + ([string][char](65+$s2)) }

function Get-ZonesFromGrid { param([string]$Grid); $b = Get-BoundsFromLocator $Grid; if ($null -eq $b) { return @{ ITU=''; CQ='' } }; $lon = ($b.LonMin + $b.LonMax) / 2; $lat = ($b.LatMin + $b.LatMax) / 2; $cq = ''; if ($lat -ge 35 -and $lat -le 75) { if ($lon -ge -15 -and $lon -lt 5) { $cq = '14' } elseif ($lon -ge 5 -and $lon -lt 25) { $cq = '15' } elseif ($lon -ge 25 -and $lon -lt 40) { $cq = '16' } elseif ($lon -ge -30 -and $lon -lt -15) { $cq = '13' } }; if (-not $cq -and $lon -ge -180 -and $lon -lt -140) { $cq = '3' }; if (-not $cq -and $lon -ge -140 -and $lon -lt -60) { $cq = '4' }; if (-not $cq -and $lon -ge -60 -and $lon -lt -15) { $cq = '8' }; $itu = ''; if ($lat -ge 49 -and $lat -le 62 -and $lon -ge -12 -and $lon -le 3) { $itu = '27' } elseif ($lat -ge 42 -and $lat -le 52 -and $lon -ge -11 -and $lon -le 10) { $itu = '28' } elseif ($lat -ge 44 -and $lat -le 56 -and $lon -ge 5 -and $lon -le 25) { $itu = '28' } elseif ($lat -ge 55 -and $lat -le 72 -and $lon -ge 3 -and $lon -le 35) { $itu = '18' } elseif ($lat -ge 35 -and $lat -le 55 -and $lon -ge 20 -and $lon -le 45) { $itu = '29' }; return @{ ITU=$itu; CQ=$cq } }

function Get-HoverInfoForLocator { param([string]$Loc); $matches = [System.Collections.Generic.List[string]]::new(); $seen = @{}; $modeF='All'; $bandF='All'; if ($null -ne $script:CboMode -and $null -ne $script:CboMode.SelectedItem) { $modeF = [string]$script:CboMode.SelectedItem }; if ($null -ne $script:CboBand -and $null -ne $script:CboBand.SelectedItem) { $bandF = [string]$script:CboBand.SelectedItem }; foreach ($e in $script:LogEntries) { if (-not $e.Grid) { continue }; $g = $e.Grid.ToUpper(); $match = $false; if ($Loc.Length -eq 6) { if ($g.Length -ge 6 -and $g.Substring(0,6) -eq $Loc) { $match = $true } } else { if ($g.Length -ge 4 -and $g.Substring(0,4) -eq $Loc) { $match = $true } }; if (-not $match) { continue }; if ($modeF -ne 'All' -and $e.ModeCat -ne $modeF) { continue }; if ($bandF -ne 'All' -and $e.Band -ne $bandF) { continue }; $bits = @(); if ($e.Band) { $bits += $e.Band }; if ($e.ModeCat) { $bits += $e.ModeCat }; $desc = if ($e.Call) { $e.Call } else { '(unknown)' }; if ($bits.Count -gt 0) { $desc = "$desc ($($bits -join ' '))" }; if ($seen.ContainsKey($desc)) { continue }; $seen[$desc] = $true; $matches.Add($desc) | Out-Null }; $manual = $false; if ($Loc.Length -eq 6 -and $script:Manual6.Contains($Loc)) { $manual = $true }; if ($Loc.Length -eq 4 -and $script:Manual4.Contains($Loc)) { $manual = $true }; if ($matches.Count -eq 0 -and -not $manual) { return $null }; $lines = [System.Collections.Generic.List[string]]::new(); $lines.Add("Square: $Loc") | Out-Null; if ($manual) { $lines.Add('  (manually confirmed)') | Out-Null }; if ($matches.Count -gt 0) { $shown = 0; foreach ($m in $matches) { if ($shown -ge 12) { $lines.Add("  ... + $($matches.Count - $shown) more") | Out-Null; break }; $lines.Add("  - $m") | Out-Null; $shown++ } }; return ($lines -join "`n") }

function Draw-PolyFallback { param($g, $lonMin, $lonMax, $latMin, $latMax, $W, $H); $landBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(214, 224, 195)); $coastPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(70, 100, 70), 1); $sx = $W / ($lonMax - $lonMin); $sy = $H / ($latMax - $latMin); foreach ($poly in $script:LandPolys) { $n = [int]($poly.Count / 2); if ($n -lt 3) { continue }; $pts = [System.Drawing.PointF[]]::new($n); for ($i = 0; $i -lt $n; $i++) { $pts[$i] = [System.Drawing.PointF]::new([float](($poly[$i*2] - $lonMin) * $sx), [float](($latMax - $poly[$i*2+1]) * $sy)) }; $g.FillPolygon($landBrush, $pts); $g.DrawPolygon($coastPen, $pts) }; $landBrush.Dispose(); $coastPen.Dispose() }

function Draw-GridLines { param($g, $lonMin, $lonMax, $latMin, $latMax, $ppd, $W, $H); $penField = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(190, 40, 40, 100), 1.5); for ($f1 = 0; $f1 -le 18; $f1++) { $lon = -180 + $f1 * 20.0; if ($lon -lt $lonMin -or $lon -gt $lonMax) { continue }; $g.DrawLine($penField, [float](($lon - $lonMin) * $ppd), 0, [float](($lon - $lonMin) * $ppd), $H) }; for ($f2 = 0; $f2 -le 18; $f2++) { $lat = -90 + $f2 * 10.0; if ($lat -lt $latMin -or $lat -gt $latMax) { continue }; $g.DrawLine($penField, 0, [float](($latMax - $lat) * $ppd), $W, [float](($latMax - $lat) * $ppd)) }; $penField.Dispose(); if ((2.0 * $ppd) -ge 6) { $pen4 = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(170, 60, 60, 60), 1); $k0 = [int][math]::Floor(($lonMin + 180) / 2.0); $k1 = [int][math]::Ceiling(($lonMax + 180) / 2.0); for ($k = $k0; $k -le $k1; $k++) { $lon = -180 + $k * 2.0; if ($lon -lt $lonMin -or $lon -gt $lonMax) { continue }; $g.DrawLine($pen4, [float](($lon - $lonMin) * $ppd), 0, [float](($lon - $lonMin) * $ppd), $H) }; $k0 = [int][math]::Floor(($latMin + 90) / 1.0); $k1 = [int][math]::Ceiling(($latMax + 90) / 1.0); for ($k = $k0; $k -le $k1; $k++) { $lat = -90 + $k * 1.0; if ($lat -lt $latMin -or $lat -gt $latMax) { continue }; $g.DrawLine($pen4, 0, [float](($latMax - $lat) * $ppd), $W, [float](($latMax - $lat) * $ppd)) }; $pen4.Dispose() }; $stepLon = 2.0 / 24.0; $stepLat = 1.0 / 24.0; if (($stepLon * $ppd) -ge 4) { $pen6 = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(120, 90, 90, 90), 1); $k0 = [int][math]::Floor(($lonMin + 180) / $stepLon); $k1 = [int][math]::Ceiling(($lonMax + 180) / $stepLon); if (($k1 - $k0) -lt 6000) { for ($k = $k0; $k -le $k1; $k++) { $lon = -180 + $k * $stepLon; $g.DrawLine($pen6, [float](($lon - $lonMin) * $ppd), 0, [float](($lon - $lonMin) * $ppd), $H) } }; $k0 = [int][math]::Floor(($latMin + 90) / $stepLat); $k1 = [int][math]::Ceiling(($latMax + 90) / $stepLat); if (($k1 - $k0) -lt 6000) { for ($k = $k0; $k -le $k1; $k++) { $lat = -90 + $k * $stepLat; $g.DrawLine($pen6, 0, [float](($latMax - $lat) * $ppd), $W, [float](($latMax - $lat) * $ppd)) } }; $pen6.Dispose() } }

function Draw-Highlights {
    param($g, $lonMin, $lonMax, $latMin, $latMax, $ppd, $W, $H)
    $c4 = Get-ColorFromString $script:Settings.Color4Char ([System.Drawing.Color]::FromArgb(175,230,175))
    $c6 = Get-ColorFromString $script:Settings.Color6Char ([System.Drawing.Color]::FromArgb(40,175,60))
    $cs = Get-ColorFromString $script:Settings.ColorSelection ([System.Drawing.Color]::FromArgb(210,100,0))
    $brush4 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(190, $c4.R, $c4.G, $c4.B))
    $brush6 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(235, $c6.R, $c6.G, $c6.B))
    $selPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, $cs.R, $cs.G, $cs.B), 2)
    $minW = 3.0; $minH = 2.0
    foreach ($loc in $script:Confirmed4) {
        if ($loc.Length -ne 4) { continue }
        $b = Get-BoundsFromLocator $loc
        if ($null -eq $b) { continue }
        if ($b.LonMax -lt $lonMin -or $b.LonMin -gt $lonMax -or $b.LatMax -lt $latMin -or $b.LatMin -gt $latMax) { continue }
        $x = ($b.LonMin - $lonMin) * $ppd; $y = ($latMax - $b.LatMax) * $ppd
        $w = $b.SizeLon * $ppd; $h = $b.SizeLat * $ppd
        if ($w -lt $minW) { $x = $x - ($minW - $w)/2; $w = $minW }
        if ($h -lt $minH) { $y = $y - ($minH - $h)/2; $h = $minH }
        $g.FillRectangle($brush4, [float]$x, [float]$y, [float]$w, [float]$h)
    }
    foreach ($loc in $script:Confirmed6) {
        if ($loc.Length -ne 6) { continue }
        $b = Get-BoundsFromLocator $loc
        if ($null -eq $b) { continue }
        if ($b.LonMax -lt $lonMin -or $b.LonMin -gt $lonMax -or $b.LatMax -lt $latMin -or $b.LatMin -gt $latMax) { continue }
        $x = ($b.LonMin - $lonMin) * $ppd; $y = ($latMax - $b.LatMax) * $ppd
        $w = $b.SizeLon * $ppd; $h = $b.SizeLat * $ppd
        if ($w -lt $minW) { $x = $x - ($minW - $w)/2; $w = $minW }
        if ($h -lt $minH) { $y = $y - ($minH - $h)/2; $h = $minH }
        $g.FillRectangle($brush6, [float]$x, [float]$y, [float]$w, [float]$h)
    }
    if ($script:CurrentBase -and $script:CurrentBase.Length -ge 4) {
        $b = Get-BoundsFromLocator $script:CurrentBase
        if ($null -ne $b -and $b.LonMax -ge $lonMin -and $b.LonMin -le $lonMax -and $b.LatMax -ge $latMin -and $b.LatMin -le $latMax) {
            $x = ($b.LonMin - $lonMin) * $ppd; $y = ($latMax - $b.LatMax) * $ppd
            $w = $b.SizeLon * $ppd; $h = $b.SizeLat * $ppd
            if ($w -ge 3 -and $h -ge 3) { $g.DrawRectangle($selPen, [float]$x, [float]$y, [float]$w, [float]$h) }
        }
    }
    $brush4.Dispose(); $brush6.Dispose(); $selPen.Dispose()
}

function Draw-Labels {
    param($g, $lonMin, $lonMax, $latMin, $latMax, $ppd, $W, $H)
    $sqPx = 2.0 * $ppd
    $subPx = (2.0/24.0) * $ppd
    $txCol = Get-ColorFromString $script:Settings.ColorGridLabelText ([System.Drawing.Color]::FromArgb(20,20,20))
    $bgCol = Get-ColorFromString $script:Settings.ColorGridLabelBg ([System.Drawing.Color]::White)
    $showBg = [bool]$script:Settings.ShowGridLabelBg
    $tb = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(240, $txCol.R, $txCol.G, $txCol.B))
    if ($showBg) {
        $hb = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(120, $bgCol.R, $bgCol.G, $bgCol.B))
    } else {
        $hb = $null
    }
    $level = 0
    if ($subPx -ge 28) { $level = 6 } elseif ($sqPx -ge 22) { $level = 4 }
    if ($level -eq 0) { $tb.Dispose(); if ($null -ne $hb) { $hb.Dispose() }; return }
    if ($level -eq 6) {
        $fs = 6.0
        if ($subPx -ge 55) { $fs = 7.0 }
        if ($subPx -ge 90) { $fs = 8.0 }
        if ($subPx -ge 140) { $fs = 9.0 }
    } else {
        $fs = 7.5
        if ($sqPx -ge 55) { $fs = 9.0 }
        if ($sqPx -ge 100) { $fs = 11.0 }
        if ($sqPx -ge 160) { $fs = 13.0 }
    }
    $font = [System.Drawing.Font]::new('Consolas', $fs, [System.Drawing.FontStyle]::Bold)
    if ($level -eq 6) {
        $stepLon = 2.0 / 24.0; $stepLat = 1.0 / 24.0
        $kLon0 = [int][math]::Floor(($lonMin + 180) / $stepLon)
        $kLon1 = [int][math]::Ceiling(($lonMax + 180) / $stepLon)
        $kLat0 = [int][math]::Floor(($latMin + 90) / $stepLat)
        $kLat1 = [int][math]::Ceiling(($latMax + 90) / $stepLat)
        if ((($kLon1-$kLon0) * ($kLat1-$kLat0)) -gt 20000) { $font.Dispose(); $tb.Dispose(); if ($null -ne $hb) { $hb.Dispose() }; return }
        for ($kl = $kLon0; $kl -lt $kLon1; $kl++) {
            $f1 = [int][math]::Floor($kl / 240); $rem1 = $kl - $f1 * 240
            $d1 = [int][math]::Floor($rem1 / 24); $s1 = $rem1 - $d1 * 24
            if ($f1 -lt 0 -or $f1 -gt 17) { continue }
            $lon = -180 + $kl * $stepLon; $x = ($lon - $lonMin) * $ppd
            $cellW = $stepLon * $ppd
            for ($km = $kLat0; $km -lt $kLat1; $km++) {
                $f2 = [int][math]::Floor($km / 240); $rem2 = $km - $f2 * 240
                $d2 = [int][math]::Floor($rem2 / 24); $s2 = $rem2 - $d2 * 24
                if ($f2 -lt 0 -or $f2 -gt 17) { continue }
                $lat = -90 + $km * $stepLat
                $y = ($latMax - ($lat + $stepLat)) * $ppd
                $cellH = $stepLat * $ppd
                $loc = ([string][char](65+$f1)) + ([string][char](65+$f2)) + ([string]$d1) + ([string]$d2) + ([string][char](65+$s1)) + ([string][char](65+$s2))
                $ts = $g.MeasureString($loc, $font)
                if ($ts.Width -le ($cellW - 2) -and $ts.Height -le ($cellH - 2)) {
                    $tx = $x + ($cellW - $ts.Width) / 2
                    $ty = $y + ($cellH - $ts.Height) / 2
                    if ($null -ne $hb) { $g.FillRectangle($hb, [float]($tx-0.5), [float]($ty-0.5), [float]($ts.Width+1), [float]($ts.Height+1)) }
                    $g.DrawString($loc, $font, $tb, [float]$tx, [float]$ty)
                }
            }
        }
    } else {
        $kLon0 = [int][math]::Floor(($lonMin + 180) / 2.0)
        $kLon1 = [int][math]::Ceiling(($lonMax + 180) / 2.0)
        $kLat0 = [int][math]::Floor(($latMin + 90) / 1.0)
        $kLat1 = [int][math]::Ceiling(($latMax + 90) / 1.0)
        for ($kl = $kLon0; $kl -lt $kLon1; $kl++) {
            $f1 = [int][math]::Floor($kl / 10); $d1 = $kl - $f1 * 10
            if ($f1 -lt 0 -or $f1 -gt 17) { continue }
            $lon = -180 + $kl * 2.0; $x = ($lon - $lonMin) * $ppd
            $cellW = 2.0 * $ppd
            for ($km = $kLat0; $km -lt $kLat1; $km++) {
                $f2 = [int][math]::Floor($km / 10); $d2 = $km - $f2 * 10
                if ($f2 -lt 0 -or $f2 -gt 17) { continue }
                $lat = -90 + $km * 1.0
                $y = ($latMax - ($lat + 1.0)) * $ppd
                $cellH = 1.0 * $ppd
                $loc = ([string][char](65+$f1)) + ([string][char](65+$f2)) + ([string]$d1) + ([string]$d2)
                $ts = $g.MeasureString($loc, $font)
                if ($ts.Width -le ($cellW - 3) -and $ts.Height -le ($cellH - 3)) {
                    $tx = $x + ($cellW - $ts.Width) / 2
                    $ty = $y + ($cellH - $ts.Height) / 2
                    if ($null -ne $hb) { $g.FillRectangle($hb, [float]($tx-1), [float]($ty-1), [float]($ts.Width+2), [float]($ts.Height+2)) }
                    $g.DrawString($loc, $font, $tb, [float]$tx, [float]$ty)
                }
            }
        }
    }
    $font.Dispose(); $tb.Dispose(); if ($null -ne $hb) { $hb.Dispose() }
}

function Render-Map { param([string]$MapKey); $box = $script:MapBoxes[$MapKey]; if ($null -eq $box) { return }; if (-not $script:MapViews.ContainsKey($MapKey)) { return }; $W = [int]$box.ClientSize.Width; $H = [int]$box.ClientSize.Height; if ($W -lt 50 -or $H -lt 50) { return }; $view = $script:MapViews[$MapKey]; $ppd = $view.PPD; $lonMin = $view.CenterLon - ($W / 2.0) / $ppd; $lonMax = $view.CenterLon + ($W / 2.0) / $ppd; $latMax = $view.CenterLat + ($H / 2.0) / $ppd; $latMin = $view.CenterLat - ($H / 2.0) / $ppd; $old = $null; if ($script:MapBitmaps.ContainsKey($MapKey)) { $old = $script:MapBitmaps[$MapKey] }; if ($null -eq $old -or $old.Width -ne $W -or $old.Height -ne $H) { if ($null -ne $old) { $old.Dispose() }; $script:MapBitmaps[$MapKey] = [System.Drawing.Bitmap]::new($W, $H) }; $bmp = $script:MapBitmaps[$MapKey]; $g = [System.Drawing.Graphics]::FromImage($bmp); try { $g.Clear([System.Drawing.Color]::FromArgb(214, 230, 244)); if ($null -ne $script:WorldImg) { $srcW = $script:WorldImg.Width; $srcH = $script:WorldImg.Height; $sx0 = (($lonMin + 180) / 360.0) * $srcW; $sx1 = (($lonMax + 180) / 360.0) * $srcW; $sy0 = ((90 - $latMax) / 180.0) * $srcH; $sy1 = ((90 - $latMin) / 180.0) * $srcH; $sx0 = [math]::Max(0.0, [math]::Min($srcW-1.0, $sx0)); $sx1 = [math]::Max(0.0, [math]::Min($srcW-1.0, $sx1)); $sy0 = [math]::Max(0.0, [math]::Min($srcH-1.0, $sy0)); $sy1 = [math]::Max(0.0, [math]::Min($srcH-1.0, $sy1)); if ($sx1 -gt $sx0 -and $sy1 -gt $sy0) { $srcRect = [System.Drawing.RectangleF]::new([float]$sx0, [float]$sy0, [float]($sx1-$sx0), [float]($sy1-$sy0)); $dstRect = [System.Drawing.RectangleF]::new(0, 0, [float]$W, [float]$H); $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.DrawImage($script:WorldImg, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel) } } else { Draw-PolyFallback -g $g -lonMin $lonMin -lonMax $lonMax -latMin $latMin -latMax $latMax -W $W -H $H }; $g.SmoothingMode = 'None'; Draw-GridLines -g $g -lonMin $lonMin -lonMax $lonMax -latMin $latMin -latMax $latMax -ppd $ppd -W $W -H $H; $g.SmoothingMode = 'AntiAlias'; Draw-Highlights -g $g -lonMin $lonMin -lonMax $lonMax -latMin $latMin -latMax $latMax -ppd $ppd -W $W -H $H; Draw-Labels -g $g -lonMin $lonMin -lonMax $lonMax -latMin $latMin -latMax $latMax -ppd $ppd -W $W -H $H } finally { $g.Dispose() }; $box.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Stretch; $box.BackgroundImage = $bmp; $box.Image = $null; $box.Invalidate() }

function Render-AllMaps { foreach ($k in $script:MapKeys) { if ($script:MapBoxes.ContainsKey($k)) { Render-Map $k } }; Update-GridCount }
function Clamp-View { param([string]$MapKey); $view = $script:MapViews[$MapKey]; if ($view.PPD -lt 0.5) { $view.PPD = 0.5 }; if ($view.PPD -gt 50000.0) { $view.PPD = 50000.0 }; if ($view.CenterLon -lt -180) { $view.CenterLon = -180 }; if ($view.CenterLon -gt 180) { $view.CenterLon = 180 }; if ($view.CenterLat -lt -80) { $view.CenterLat = -80 }; if ($view.CenterLat -gt 80) { $view.CenterLat = 80 } }
function Handle-Zoom { param([string]$MapKey, [int]$PixelX, [int]$PixelY, [int]$Delta); $view = $script:MapViews[$MapKey]; $box = $script:MapBoxes[$MapKey]; if ($null -eq $box) { return }; $W = [int]$box.ClientSize.Width; $H = [int]$box.ClientSize.Height; if ($W -lt 50 -or $H -lt 50) { return }; $ppd = $view.PPD; $lonMin = $view.CenterLon - ($W / 2.0) / $ppd; $latMax = $view.CenterLat + ($H / 2.0) / $ppd; $lonUnder = $lonMin + $PixelX / $ppd; $latUnder = $latMax - $PixelY / $ppd; $factor = if ($Delta -gt 0) { 1.30 } else { 0.769 }; $newPPD = $ppd * $factor; if ($newPPD -lt 0.5) { $newPPD = 0.5 }; if ($newPPD -gt 50000.0) { $newPPD = 50000.0 }; $view.CenterLon = $lonUnder - ($PixelX - $W / 2.0) / $newPPD; $view.CenterLat = $latUnder + ($PixelY - $H / 2.0) / $newPPD; $view.PPD = $newPPD; Clamp-View $MapKey; Render-Map $MapKey; Update-Status; Update-ZoomSlider }

function Update-ZoomSlider { try { if ($null -eq $script:ZoomSlider) { return }; $mk = $script:ActiveMapKey; if (-not $script:MapViews.ContainsKey($mk)) { return }; $ppd = $script:MapViews[$mk].PPD; $val = [int][math]::Round([math]::Log($ppd, 10) * 20); if ($val -lt $script:ZoomSlider.Minimum) { $val = $script:ZoomSlider.Minimum }; if ($val -gt $script:ZoomSlider.Maximum) { $val = $script:ZoomSlider.Maximum }; $script:ZoomSlider.Value = $val } catch { } }

function Update-Status { try { $mk = $script:ActiveMapKey; if ($null -eq $script:LblStatusCtrl) { return }; if ($mk -eq 'Log') { $rc = 0; if ($null -ne $script:DistGrid) { $rc = $script:DistGrid.Rows.Count }; $script:LblStatusCtrl.Text = "Log tab: $($script:LogEntries.Count) QSOs total, $rc shown after filters."; return }; if ($mk -eq 'Propagation') { $script:LblStatusCtrl.Text = "Propagation tab: solar data from hamqsl.com (N0NBH)."; return }; if ($mk -eq 'NOAA') { $script:LblStatusCtrl.Text = "NOAA SWPC tab: live solar and geomagnetic data from NOAA."; return }; if ($mk -eq 'DXCluster') { $script:LblStatusCtrl.Text = "DX Cluster tab: live spots from a public telnet cluster."; return }; if (-not $script:MapViews.ContainsKey($mk)) { return }; $view = $script:MapViews[$mk]; $ppd = $view.PPD; $subPx = (2.0/24.0) * $ppd; $sqPx = 2.0 * $ppd; $lvl = if ($subPx -ge 28) { '6-char' } elseif ($sqPx -ge 22) { '4-char' } else { '4-char (small)' }; $script:LblStatusCtrl.Text = "Map: $mk   |   Zoom: $([math]::Round($ppd,1)) px/deg   |   Click: $lvl" } catch { } }

function Add-CellAt { param([string]$MapKey, [int]$PixelX, [int]$PixelY); $box = $script:MapBoxes[$MapKey]; if ($null -eq $box) { return }; $W = [int]$box.ClientSize.Width; $H = [int]$box.ClientSize.Height; $view = $script:MapViews[$MapKey]; $ppd = $view.PPD; $lonMin = $view.CenterLon - ($W / 2.0) / $ppd; $latMax = $view.CenterLat + ($H / 2.0) / $ppd; $lon = $lonMin + $PixelX / $ppd; $lat = $latMax - $PixelY / $ppd; $subPx = (2.0/24.0) * $ppd; $level = 4; if ($subPx -ge 28) { $level = 6 }; if ($level -eq 6) { $loc6 = Get-LocatorAtLevel -Lon $lon -Lat $lat -Level 6; if ($script:Manual6.Contains($loc6)) { $script:LblStatusCtrl.Text = "Already manually confirmed: $loc6"; return }; $ans = [System.Windows.Forms.MessageBox]::Show("Would you like to log this 6-character square?`n`n$loc6", 'Add 6-char square', 'YesNo', 'Question'); if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }; $script:Manual6.Add($loc6) | Out-Null; $script:LblStatusCtrl.Text = "Added manual 6-char: $loc6 (green)"; $script:CurrentBase = $loc6.Substring(0,4) } else { $loc = Get-LocatorAtLevel -Lon $lon -Lat $lat -Level 4; if ($script:Manual4.Contains($loc)) { $script:LblStatusCtrl.Text = "Already manually confirmed: $loc"; return }; $ans = [System.Windows.Forms.MessageBox]::Show("Would you like to log this 4-character square?`n`n$loc", 'Add 4-char square', 'YesNo', 'Question'); if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }; $script:Manual4.Add($loc) | Out-Null; $script:LblStatusCtrl.Text = "Added manual 4-char: $loc"; $script:CurrentBase = $loc }; Rebuild-Confirmed; Render-AllMaps; Save-LogData }

function Remove-CellAt { param([string]$MapKey, [int]$PixelX, [int]$PixelY); $box = $script:MapBoxes[$MapKey]; if ($null -eq $box) { return }; $W = [int]$box.ClientSize.Width; $H = [int]$box.ClientSize.Height; $view = $script:MapViews[$MapKey]; $ppd = $view.PPD; $lonMin = $view.CenterLon - ($W / 2.0) / $ppd; $latMax = $view.CenterLat + ($H / 2.0) / $ppd; $lon = $lonMin + $PixelX / $ppd; $lat = $latMax - $PixelY / $ppd; $subPx = (2.0/24.0) * $ppd; $level = 4; if ($subPx -ge 28) { $level = 6 }; if ($level -eq 6) { $loc6 = Get-LocatorAtLevel -Lon $lon -Lat $lat -Level 6; $parent = $loc6.Substring(0,4); if (-not $script:Manual6.Contains($loc6)) { $script:LblStatusCtrl.Text = "Nothing to remove at $loc6."; return }; $ans = [System.Windows.Forms.MessageBox]::Show("Do you want to remove this 6-character grid square?`n`n$loc6", 'Remove 6-char square', 'YesNo', 'Question'); if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }; $script:Manual6.Remove($loc6) | Out-Null; $script:LblStatusCtrl.Text = "Removed manual 6-char: $loc6"; $script:CurrentBase = $parent } else { $loc = Get-LocatorAtLevel -Lon $lon -Lat $lat -Level 4; if ($script:Manual4.Contains($loc)) { $ans = [System.Windows.Forms.MessageBox]::Show("Do you want to remove this 4-character grid square?`n`n$loc", 'Remove 4-char square', 'YesNo', 'Question'); if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }; $script:Manual4.Remove($loc) | Out-Null; $script:LblStatusCtrl.Text = "Removed manual 4-char: $loc" } else { $script:LblStatusCtrl.Text = "Nothing to remove at $loc."; return } }; Rebuild-Confirmed; Render-AllMaps; Save-LogData }

function Apply-Filters { try { Rebuild-Confirmed } catch {}; try { Render-AllMaps } catch {}; try { Update-Status } catch {}; try { Refresh-LogView } catch {} }

function Get-DistanceKm { param([double]$Lat1, [double]$Lon1, [double]$Lat2, [double]$Lon2); $R = 6371.0; $dLat = ($Lat2 - $Lat1) * [math]::PI / 180.0; $dLon = ($Lon2 - $Lon1) * [math]::PI / 180.0; $a = [math]::Sin($dLat/2) * [math]::Sin($dLat/2) + [math]::Cos($Lat1*[math]::PI/180.0) * [math]::Cos($Lat2*[math]::PI/180.0) * [math]::Sin($dLon/2) * [math]::Sin($dLon/2); $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1-$a)); return $R * $c }
function Get-GridCenter { param([string]$Grid); $b = Get-BoundsFromLocator $Grid; if ($null -eq $b) { return $null }; return @{ Lat = ($b.LatMin + $b.LatMax) / 2.0; Lon = ($b.LonMin + $b.LonMax) / 2.0 } }
function Format-Distance { param([double]$Km); if ($script:Settings.UseMiles) { $mi = $Km * 0.621371; return ("{0:N1} mi" -f $mi) } else { return ("{0:N1} km" -f $Km) } }

function Refresh-LogView {
    if ($null -eq $script:DistGrid) { return }
    try { $script:DistGrid.SuspendLayout(); $script:DistGrid.Rows.Clear() } catch {}
    try {
        $bandF = 'All'; $modeF = 'All'
        if ($null -ne $script:LogBandCombo -and $null -ne $script:LogBandCombo.SelectedItem) { $bandF = [string]$script:LogBandCombo.SelectedItem }
        if ($null -ne $script:LogModeCombo -and $null -ne $script:LogModeCombo.SelectedItem) { $modeF = [string]$script:LogModeCombo.SelectedItem }

        $myGrid = $script:Settings.Grid
        $myCenter = $null
        if ($myGrid -and $myGrid.Length -ge 4) { $myCenter = Get-GridCenter $myGrid }

        $rows = [System.Collections.Generic.List[object]]::new()
        foreach ($e in $script:LogEntries) {
            if ($bandF -ne 'All' -and $e.Band -ne $bandF) { continue }
            if ($modeF -ne 'All' -and $e.ModeCat -ne $modeF) { continue }
            $km = $null
            if ($null -ne $myCenter -and $e.Grid -and $e.Grid.Length -ge 4) {
                $c = Get-GridCenter $e.Grid
                if ($null -ne $c) { $km = Get-DistanceKm -Lat1 $myCenter.Lat -Lon1 $myCenter.Lon -Lat2 $c.Lat -Lon2 $c.Lon }
            }
            $rows.Add([PSCustomObject]@{ Call=$e.Call; Grid=$e.Grid; Km=$km; Band=$e.Band; Mode=$e.Mode; SubMode=$e.SubMode; Date=$e.Date; Time=$e.Time }) | Out-Null
        }

        if ($rows.Count -eq 0) {
            if ($null -ne $script:DistHeader) {
                if ($script:LogEntries.Count -eq 0) {
                    $script:DistHeader.Text = "No QSOs loaded. Use Upload ADIF to populate the log."
                } else {
                    $script:DistHeader.Text = "No QSOs match the current Band/Mode filter."
                }
            }
            try { $script:DistGrid.ResumeLayout() } catch {}
            return
        }

        $sortedWithKm = @($rows | Where-Object { $null -ne $_.Km } | Sort-Object -Property Km)
        $longest = $null; $shortest = $null
        if ($sortedWithKm.Count -gt 0) {
            $shortest = $sortedWithKm[0]
            $longest  = $sortedWithKm[$sortedWithKm.Count - 1]
        }

        $mode = 'All (longest first)'
        if ($null -ne $script:DistCombo) { $mode = [string]$script:DistCombo.SelectedItem }

        $ordered = switch ($mode) {
            'All (shortest first)' {
                @($rows | Sort-Object -Property @{Expression={ if ($null -ne $_.Km) { $_.Km } else { [double]::MaxValue } }})
            }
            'Top 10 longest' {
                if ($sortedWithKm.Count -eq 0) { @() } else { @($sortedWithKm | Select-Object -Last ([math]::Min(10,$sortedWithKm.Count)) | Sort-Object -Property Km -Descending) }
            }
            'Top 10 shortest' {
                if ($sortedWithKm.Count -eq 0) { @() } else { @($sortedWithKm | Select-Object -First ([math]::Min(10,$sortedWithKm.Count))) }
            }
            'Most recent first' {
                @($rows | Sort-Object -Property @{Expression={ "$($_.Date)$($_.Time)" }} -Descending)
            }
            default {
                @($rows | Sort-Object -Property @{Expression={ if ($null -ne $_.Km) { -$_.Km } else { [double]::MinValue } }})
            }
        }

        foreach ($r in $ordered) {
            $dt = $r.Date; if ($dt -and $dt.Length -eq 8) { $dt = "$($dt.Substring(0,4))-$($dt.Substring(4,2))-$($dt.Substring(6,2))" }
            $m = $r.Mode; if ($r.SubMode) { $m = "$m/$($r.SubMode)" }
            $distStr = if ($null -ne $r.Km) { Format-Distance $r.Km } else { '-' }
            $idx = $script:DistGrid.Rows.Add($dt, $r.Time, $r.Call, $r.Band, $m, $r.Grid, $distStr)
            if ($null -ne $r.Km -and $null -ne $longest -and $r.Km -eq $longest.Km) { $script:DistGrid.Rows[$idx].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen; $script:DistGrid.Rows[$idx].DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black }
            elseif ($null -ne $r.Km -and $null -ne $shortest -and $r.Km -eq $shortest.Km) { $script:DistGrid.Rows[$idx].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightSkyBlue; $script:DistGrid.Rows[$idx].DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black }
        }

        if ($null -ne $script:DistHeader) {
            if ($null -ne $longest -and $null -ne $shortest) {
                $script:DistHeader.Text = "Longest: $(Format-Distance $longest.Km) ($($longest.Call), $($longest.Grid))   |   Shortest: $(Format-Distance $shortest.Km) ($($shortest.Call), $($shortest.Grid))   |   Shown: $($rows.Count) of $($script:LogEntries.Count) QSOs"
            } else {
                $script:DistHeader.Text = "Shown: $($rows.Count) of $($script:LogEntries.Count) QSOs.  (Set your grid in Settings for distance calculations.)"
            }
        }
    } catch {
        if ($null -ne $script:DistHeader) { $script:DistHeader.Text = "Log tab error: $_" }
    }
    try { $script:DistGrid.ResumeLayout() } catch {}
}

function Refresh-NOAA {
    if ($null -eq $script:NoaaGrid) { return }
    if ($null -ne $script:NoaaStatus) { $script:NoaaStatus.Text = 'Fetching NOAA SWPC data...'; $script:NoaaStatus.ForeColor = [System.Drawing.Color]::DarkBlue }
    [System.Windows.Forms.Application]::DoEvents()
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $wc = [System.Net.WebClient]::new(); $wc.Headers.Add('User-Agent', 'Mozilla/5.0')

        $sfi = ''; $ssn = ''
        try {
            $json = $wc.DownloadString('https://services.swpc.noaa.gov/json/solar-cycle/observed-solar-cycle-indices.json')
            $arr = $json | ConvertFrom-Json
            if ($arr.Count -gt 0) { $last = $arr[$arr.Count-1]; if ($null -ne $last.'f10.7') { $sfi = [string]$last.'f10.7' }; if ($null -ne $last.ssn) { $ssn = [string]$last.ssn } }
        } catch { }

        $kp = ''; $aIdx = ''
        try {
            $json2 = $wc.DownloadString('https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json')
            $arr2 = $json2 | ConvertFrom-Json
            if ($arr2.Count -gt 1) { $lastRow = $arr2[$arr2.Count-1]; $kp = [string]$lastRow[1] }
        } catch { }

        try {
            $txt = $wc.DownloadString('https://services.swpc.noaa.gov/text/daily-geomagnetic-indices.txt')
            $lines = $txt -split "`n"
            $lastData = $null
            foreach ($ln in $lines) { if ($ln -match '^\s*\d{4}\s+\d{2}\s+\d{2}') { $lastData = $ln } }
            if ($lastData) {
                $parts = $lastData -split '\s+' | Where-Object { $_ -ne '' }
                if ($parts.Count -ge 22) { $aIdx = $parts[21] }
            }
        } catch { }

        $alerts = [System.Collections.Generic.List[object]]::new()
        try {
            $json3 = $wc.DownloadString('https://services.swpc.noaa.gov/products/alerts.json')
            $arr3 = $json3 | ConvertFrom-Json
            $take = [math]::Min(50, $arr3.Count)
            for ($i = $arr3.Count - 1; $i -ge ($arr3.Count - $take); $i--) {
                if ($i -lt 0) { break }
                $it = $arr3[$i]
                $msg = [string]$it.message
                $firstLine = ($msg -split "`n")[0]
                $alerts.Add([PSCustomObject]@{ Time=[string]$it.issue_datetime; Summary=$firstLine; Message=$msg }) | Out-Null
            }
        } catch { }

        $wc.Dispose()
        if ($null -ne $script:NoaaHeader) {
            $script:NoaaHeader.Text = "Solar Flux (SFI): $sfi    |    A-Index: $aIdx    |    K-Index: $kp    |    Sunspots: $ssn"
        }
        try { $script:NoaaGrid.SuspendLayout(); $script:NoaaGrid.Rows.Clear() } catch {}
        foreach ($al in $alerts) {
            $rIdx = $script:NoaaGrid.Rows.Add($al.Time, $al.Summary)
            $script:NoaaGrid.Rows[$rIdx].Tag = $al.Message
        }
        try { $script:NoaaGrid.ResumeLayout() } catch {}
        if ($null -ne $script:NoaaStatus) {
            $script:NoaaStatus.Text = "Loaded $($alerts.Count) recent alert(s) from NOAA SWPC. Double-click a row to read the full message."
            $script:NoaaStatus.ForeColor = [System.Drawing.Color]::DarkGreen
        }
    } catch {
        if ($null -ne $script:NoaaStatus) { $script:NoaaStatus.Text = "Could not fetch NOAA data: $_"; $script:NoaaStatus.ForeColor = [System.Drawing.Color]::DarkRed }
    }
}

function Get-BandFromFreq {
    param([double]$KHz)
    if ($KHz -ge 1800 -and $KHz -le 2000) { return '160m' }
    if ($KHz -ge 3500 -and $KHz -le 4000) { return '80m' }
    if ($KHz -ge 5300 -and $KHz -le 5410) { return '60m' }
    if ($KHz -ge 7000 -and $KHz -le 7300) { return '40m' }
    if ($KHz -ge 10100 -and $KHz -le 10150) { return '30m' }
    if ($KHz -ge 14000 -and $KHz -le 14350) { return '20m' }
    if ($KHz -ge 18068 -and $KHz -le 18168) { return '17m' }
    if ($KHz -ge 21000 -and $KHz -le 21450) { return '15m' }
    if ($KHz -ge 24890 -and $KHz -le 24990) { return '12m' }
    if ($KHz -ge 28000 -and $KHz -le 29700) { return '10m' }
    if ($KHz -ge 50000 -and $KHz -le 54000) { return '6m' }
    if ($KHz -ge 144000 -and $KHz -le 148000) { return '2m' }
    if ($KHz -ge 430000 -and $KHz -le 450000) { return '70cm' }
    return ''
}

function Test-DxSpotMatches {
    param([string]$Line, [string]$Band, [string]$Mode, [string]$Text)
    if (-not $Line) { return $false }
    if ($Line.StartsWith('---') -or $Line.StartsWith('ERROR:')) { return $true }
    if ($Band -and $Band -ne 'All') {
        $m = [regex]::Match($Line, '(\d{4,6}(?:\.\d+)?)')
        if (-not $m.Success) { return $false }
        $freq = [double]$m.Groups[1].Value
        $b = Get-BandFromFreq $freq
        if ($b -ne $Band) { return $false }
    }
    if ($Mode -and $Mode -ne 'All') {
        if ($Line -notmatch "(?i)\b$([regex]::Escape($Mode))\b") { return $false }
    }
    if ($Text) {
        if ($Line.ToUpper() -notmatch [regex]::Escape($Text.ToUpper())) { return $false }
    }
    return $true
}

function Stop-DXCluster {
    if ($null -ne $script:DxPS) { try { $script:DxPS.Stop() } catch {}; try { $script:DxPS.Dispose() } catch {}; $script:DxPS = $null }
    if ($null -ne $script:DxRunspace) { try { $script:DxRunspace.Close() } catch {}; try { $script:DxRunspace.Dispose() } catch {}; $script:DxRunspace = $null }
    $script:DxHandle = $null
    $script:DxConnected = $false
}

function Test-DXConnection {
    param([string]$HostName, [int]$Port)
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(8000, $false)
        if (-not $ok) {
            try { $client.Close() } catch {}
            return @{ Ok=$false; Msg="Timed out after 8s. Port $Port is likely blocked by your ISP, router or firewall." }
        }
        $client.EndConnect($iar)
        try { $client.Close() } catch {}
        return @{ Ok=$true; Msg='OK' }
    } catch {
        return @{ Ok=$false; Msg=$_.Exception.Message }
    }
}

function Test-AllDXHosts {
    param([System.Windows.Forms.ListBox]$ResultList = $null)
    $results = [System.Collections.Generic.List[object]]::new()
    $total = $script:DxPresets.Count
    $idx = 0
    foreach ($pres in $script:DxPresets) {
        $idx++
        $p = 7300
        try { $p = [int]$pres.Port } catch { $p = 7300 }
        if ($null -ne $ResultList) {
            $ResultList.Items.Add("--- Testing [$idx/$total] $($pres.Host):$p ---") | Out-Null
            $ResultList.TopIndex = $ResultList.Items.Count - 1
            [System.Windows.Forms.Application]::DoEvents()
        }
        $r = Test-DXConnection -HostName $pres.Host -Port $p
        $line = if ($r.Ok) { "PASS  $($pres.Host):$p" } else { "FAIL  $($pres.Host):$p  ($($r.Msg))" }
        $results.Add([PSCustomObject]@{ Host=$pres.Host; Port=$p; Ok=$r.Ok; Msg=$r.Msg; Line=$line }) | Out-Null
        if ($null -ne $ResultList) {
            $ResultList.Items.Add($line) | Out-Null
            $ResultList.TopIndex = $ResultList.Items.Count - 1
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    return $results
}

function Start-DXCluster {
    param([string]$HostName, [int]$Port, [string]$Login)
    Stop-DXCluster
    try {
        $script:DxQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        $script:DxRunspace = [runspacefactory]::CreateRunspace()
        $script:DxRunspace.Open()
        $script:DxPS = [powershell]::Create()
        $script:DxPS.Runspace = $script:DxRunspace

        $workerScript = @'
param($q, $h, $p, $login)
try {
    $q.Enqueue("--- Step 1: creating TcpClient ---")
    $client = New-Object System.Net.Sockets.TcpClient
    $q.Enqueue("--- Step 2: connecting to ${h}:${p} (10s timeout) ---")
    $iar = $client.BeginConnect($h, $p, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne(10000, $false)
    if (-not $ok) {
        $q.Enqueue("ERROR: Connect timeout after 10s. Port ${p} may be blocked.")
        return
    }
    $client.EndConnect($iar)
    if (-not $client.Connected) {
        $q.Enqueue("ERROR: EndConnect returned but Connected=false.")
        return
    }
    $q.Enqueue("--- Step 3: socket connected ---")
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.NewLine = "`r`n"
    $writer.AutoFlush = $true
    $q.Enqueue("--- Step 4: sending login '$login' ---")
    $writer.WriteLine($login)
    $q.Enqueue("--- Connected to ${h}:${p} as $login ---")
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    $gotBanner = $false
    while ([DateTime]::UtcNow -lt $deadline -and -not $gotBanner) {
        if ($stream.DataAvailable) {
            $line = $reader.ReadLine()
            if ($null -ne $line) {
                $q.Enqueue($line)
                if ($line -match 'login|hello|welcome|call|cluster') { $gotBanner = $true }
            }
        } else {
            Start-Sleep -Milliseconds 200
        }
    }
    if (-not $gotBanner) { $q.Enqueue("--- No banner received in 20s (some clusters stay silent). Streaming anyway. ---") }
    while ($client.Connected) {
        try {
            $line = $reader.ReadLine()
            if ($null -eq $line) { break }
            $q.Enqueue($line)
        } catch { break }
    }
    try { $client.Close() } catch {}
    $q.Enqueue("--- Disconnected from ${h}:${p} ---")
} catch {
    $q.Enqueue("ERROR: $($_.Exception.Message)")
}
'@

        $script:DxPS.AddScript($workerScript).AddArgument($script:DxQueue).AddArgument($HostName).AddArgument($Port).AddArgument($Login) | Out-Null
        $script:DxHandle = $script:DxPS.BeginInvoke()
        $script:DxConnected = $true
        return $true
    } catch {
        return $false
    }
}

function Update-Ribbon {
    $call = $script:Settings.Callsign; $grid = $script:Settings.Grid; $itu = $script:Settings.ITUZone; $cq = $script:Settings.CQZone; $name = $script:Settings.Name
    if ($null -eq $script:RibbonCall) { return }
    $colRibbon = Get-ColorFromString $script:Settings.ColorRibbon ([System.Drawing.Color]::FromArgb(30,60,110))
    $colCall = Get-ColorFromString $script:Settings.ColorCallsign ([System.Drawing.Color]::White)
    $colClock = Get-ColorFromString $script:Settings.ColorClock ([System.Drawing.Color]::FromArgb(200,240,200))
    $colZones = Get-ColorFromString $script:Settings.ColorZones ([System.Drawing.Color]::FromArgb(255,220,150))
    $script:RibbonPanel.BackColor = $colRibbon
    $script:RibbonCall.ForeColor = $colCall
    $script:ClockLabel.ForeColor = $colClock
    $script:RibbonZones.ForeColor = $colZones
    if (-not $call -and -not $grid) {
        $script:RibbonCall.Text = 'Set your callsign in Settings'
        $script:RibbonGrid.Text = ''; $script:RibbonZones.Text = ''; $script:RibbonName.Text = ''
    } else {
        $script:RibbonCall.Text = if ($call) { $call } else { '(no call)' }
        $script:RibbonGrid.Text = if ($grid) { "Grid: $grid" } else { '' }
        $z = @(); if ($itu) { $z += "ITU $itu" }; if ($cq) { $z += "CQ $cq" }
        $script:RibbonZones.Text = ($z -join '   |   ')
        $script:RibbonName.Text = if ($name) { $name } else { '' }
    }
    Update-Clock
    Update-GridCount
    Update-Legend
}

function Apply-TabVisibility {
    try {
        $tabs = $script:TabCtrl
        if ($null -eq $tabs) { return }
        $tabs.TabPages.Clear()
        $script:VisibleKeys = @()
        foreach ($def in $script:TabDefs) {
            if ($script:Settings.VisibleTabs -contains $def.Key) {
                if ($script:TabPages.ContainsKey($def.Key)) {
                    $tabs.TabPages.Add($script:TabPages[$def.Key])
                    $script:VisibleKeys += $def.Key
                }
            }
        }
        if ($tabs.TabPages.Count -eq 0) {
            if ($script:TabPages.ContainsKey('Log')) { $tabs.TabPages.Add($script:TabPages['Log']); $script:VisibleKeys = @('Log') }
        }
        $tabs.SelectedIndex = 0
        if ($script:VisibleKeys.Count -gt 0) {
            $script:ActiveMapKey = $script:VisibleKeys[0]
            Update-Status
            Update-ZoomSlider
        }
        $tabs.Invalidate()
    } catch { }
}

function Show-ManualForm {
    $manualText = @"
GRID SQUARE WORKED - USER MANUAL
(c) D&C Ham Adventure (M7ANI) 2026
============================================================

IMPORTANT - PLEASE READ
------------------------------------------------------------
This program is a hobby project made for fun by D&C Ham
Adventure (M7ANI).  It is NOT a professional logging tool
and the grid square data shown has not been verified against
any official source.  Some grid squares may be off, especially
near borders and coastlines.  Please do not rely on it for
awards, contest entries or anything official.

Use it for what it is: a fun way to visualise where you have
been heard and where you have heard others.  Always verify
important contacts against your own log.

If you spot an obvious error, get in touch - see Contact at
the end.

============================================================

WHAT THIS PROGRAM DOES
------------------------------------------------------------
Tracks which Maidenhead grid squares you have worked, plotted
on regional maps. Upload an ADIF log file and every grid you
have contacted is highlighted. Also includes live DX Cluster
spots, propagation data and NOAA space weather.

1. FIRST TIME SETUP
------------------------------------------------------------
Open Settings... from the Settings menu.

  Your details:
    Callsign    - your amateur callsign (e.g. M7ANI)
    Name        - your name
    Grid Square - your Maidenhead locator (e.g. IO83VA)
    ITU Zone    - your ITU zone number
    CQ Zone     - your CQ zone number

  QRZ Callsign Lookup (optional):
    QRZ Username - your QRZ login name or callsign
    QRZ Password - your QRZ account password
    QRZ API Key  - LEAVE THIS BLANK unless you specifically
                   have an API key. If blank, the Password is
                   used automatically. This is what most users
                   should do.

    Click Download from QRZ to auto-fill Name, Grid, ITU and
    CQ zones. Requires an active paid QRZ XML Data subscription.

  DX Cluster:
    DX Cluster callsign - the login name the cluster sees.
    Leave blank to use your main callsign.

  Theme:
    Light - classic look (default)
    Dark  - easier on the eyes at night

  Clock, Units and Labels:
    Show clock on ribbon    - local and UTC clock
    Clock format            - 24-hour or AM/PM
    Distance units          - Kilometres or Miles
    Show box behind grid labels - toggle the white background
                                  behind grid text on maps

  Locate mode:
    Auto locate   - pull your grid from QRZ
    Manual locate - type your own

  Visible tabs:
    Tick the tabs you want to see. The Log tab is always shown.
    Click "Default (all)" to reset to all tabs on.

2. LOADING YOUR LOG
------------------------------------------------------------
Click "Upload ADIF" on the main toolbar and pick your .adi or
.adif file. Every QSO is loaded and the log is saved
automatically to gridlog.json in the same folder as the script.
Next time you launch the app it reloads automatically.

The Log tab shows Date, Time, Call, Band, Mode, Grid and the
distance from your own grid to each contact.

3. THE MAPS
------------------------------------------------------------
Eight regional map tabs are included:
  UK              North America   Africa        Australia
  Europe          South America   Asia          Antarctica

Map controls:
  Left-click empty area   - pan the map
  Left-click on a square  - add that square manually (a popup
                            asks for confirmation)
  Right-click a square    - remove a manually-added square
  Mouse wheel             - zoom in and out
  Zoom slider             - same as mouse wheel

The Mode and Band dropdowns on the main toolbar control which
squares are highlighted on the maps. They do NOT affect the
Log tab. A note on the toolbar says "Selection is for the maps".

Colours:
  4-Grid squares are shown in one colour (default light green)
  6-Grid squares are shown in another (default solid green)
  The current selection is outlined in orange

The Legend at the top of the window shows the current colours.

4. SEARCH
------------------------------------------------------------
Type a 4 or 6 character locator in the Search box and click Go.
The active map will centre on that square. Example: IO83 or
IO83VA.

5. THE LOG TAB
------------------------------------------------------------
Shows all logged QSOs with distances. Has its own Band and Mode
filters that only affect what is displayed here.

Use the "Show:" dropdown to sort:
  All (longest first)   - biggest distances first (default)
  All (shortest first)  - closest first
  Top 10 longest        - just your best DX
  Top 10 shortest       - just your nearest contacts
  Most recent first     - newest QSOs at the top

The header line summarises the longest and shortest contacts.

6. PROPAGATION TAB
------------------------------------------------------------
Live HF band conditions from hamqsl.com (N0NBH). Shows day and
night predictions for every HF band plus general notes for 6m,
4m, 2m and 70cm. Click Refresh to update.

7. NOAA SWPC TAB
------------------------------------------------------------
Live space weather data from the NOAA Space Weather Prediction
Center. Shows:
  - Solar Flux Index (SFI)
  - A-Index
  - K-Index
  - Sunspot number
  - Recent solar flare and geomagnetic alerts

Double-click any row to read the full alert message.

8. DX CLUSTER TAB
------------------------------------------------------------
Connect to a public telnet DX cluster and watch live DX spots.

Setup:
  1. Pick a host from the dropdown - the port fills in
     automatically
  2. Click Test to confirm the host is reachable
  3. Click Connect to start streaming spots

The "Test All" button checks every host in the list and tells
you which ones work from your network. Many UK ISPs block
certain ports outbound; Test All finds the ones that aren't
blocked.

Filters (Band, Mode, Text) apply to new spots as they arrive.
Click "Save filters" to remember them.

Verified working from UK ISPs:
  hrd.wa9pie.net       port 8000
  dxc.nc7j.com         port 7373
  ve7cc.net            port 23
  dxc.ve7cc.net        port 23

If a host times out, your ISP is blocking the port. Try a
different host from the list.

9. SAVING AND LOADING
------------------------------------------------------------
Save    - save the current grid state to a JSON file
Load    - restore a previously saved file
Clear   - wipe everything from the current session
Reset   - wipe everything AND require a fresh ADIF upload

Your log auto-saves after every change and auto-loads on launch.
The files settings.json and gridlog.json live next to the script.

10. COLOURS AND THEME
------------------------------------------------------------
Settings menu -> Change Colour. You can change:
  - Ribbon background
  - Callsign text
  - Clock text
  - ITU / CQ zone text
  - 4-Grid square colour
  - 6-Grid square colour
  - Current selection outline
  - Grid label text (map)
  - Grid label background box (map)

Click any swatch to pick a new colour. Click "Reset defaults"
to go back to the shipped colours.

Theme (Light / Dark) is chosen in Settings, top of the Clock,
Units and Labels section. Your theme choice is saved and
applied next time you launch.

11. QRZ TROUBLESHOOTING
------------------------------------------------------------
If QRZ lookups fail:

  "Username/password incorrect"
    - Check your QRZ login at qrz.com in a browser first
    - Try your CALLSIGN instead of your QRZ login name
    - Passwords are case-sensitive
    - Leave the API Key field blank (use Password instead)

  "Blocked until ..."
    - QRZ blocks the IP for 20 minutes after several failed
      login attempts. Wait 20 minutes without retrying, then
      try ONCE. Repeatedly clicking resets the block timer.

  "No XML Data subscription"
    - QRZ's XML Data API requires a paid subscription. Check
      Account -> XML Subscription on qrz.com.

  Still failing?
    - Run this in PowerShell to see the raw response:

      `$url = "https://xmldata.qrz.com/xml/current/?username=YOURUSER;password=YOURPASS"
      (New-Object System.Net.WebClient).DownloadString(`$url)

12. DX CLUSTER TROUBLESHOOTING
------------------------------------------------------------
If nothing shows when you click Connect:

  1. Click Test first. If it says FAILED, the port is blocked
     by your ISP or firewall.
  2. Click Test All. This runs a full sweep and shows which
     hosts pass from your network.
  3. Check Windows Firewall - it may block outbound telnet.
  4. Some antivirus software blocks telnet; whitelist the app.

13. FILES
------------------------------------------------------------
GridSquareWorked.ps1    the script (this file)
settings.json           your preferences
gridlog.json            your log and confirmed squares
worldmap-5400.jpg       cached NASA world map (auto-downloaded)
GridSquareWorked.exe    optional compiled version

Delete settings.json or gridlog.json to reset those parts.

14. CONTACT
------------------------------------------------------------
TikTok:  dc.ham.adventure
Discord: D&C Ham Adventure
"@

    $dlg = [System.Windows.Forms.Form]::new()
    $dlg.Text = 'Grid Square Worked - Manual'
    $dlg.ClientSize = [System.Drawing.Size]::new(860, 660)
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'Sizable'
    $dlg.MinimizeBox = $false

    $btnPanel = [System.Windows.Forms.Panel]::new()
    $btnPanel.Dock = 'Bottom'
    $btnPanel.Height = 44
    $dlg.Controls.Add($btnPanel)

    $btnClose = [System.Windows.Forms.Button]::new()
    $btnClose.Text = 'Close'
    $btnClose.Location = [System.Drawing.Point]::new(745, 6)
    $btnClose.Size = [System.Drawing.Size]::new(100, 32)
    $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnPanel.Controls.Add($btnClose)

    $btnPrint = [System.Windows.Forms.Button]::new()
    $btnPrint.Text = 'Save as HTML / Print to PDF'
    $btnPrint.Location = [System.Drawing.Point]::new(490, 6)
    $btnPrint.Size = [System.Drawing.Size]::new(245, 32)
    $btnPanel.Controls.Add($btnPrint)

    $lblHint = [System.Windows.Forms.Label]::new()
    $lblHint.Text = 'Tip: click "Save as HTML" then use your browser''s Print > Save as PDF to make a PDF copy.'
    $lblHint.Location = [System.Drawing.Point]::new(10, 12)
    $lblHint.Size = [System.Drawing.Size]::new(470, 20)
    $lblHint.ForeColor = [System.Drawing.Color]::Gray
    $lblHint.Font = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)
    $btnPanel.Controls.Add($lblHint)

    $txt = [System.Windows.Forms.TextBox]::new()
    $txt.Multiline = $true
    $txt.ReadOnly = $true
    $txt.ScrollBars = 'Vertical'
    $txt.WordWrap = $true
    $txt.Dock = 'Fill'
    $txt.Font = [System.Drawing.Font]::new('Consolas', 9.5)
    $txt.Text = $manualText
    $dlg.Controls.Add($txt)
    $txt.BringToFront()

    Set-FlatButton $btnClose
    Set-FlatButton $btnPrint

    $btnPrint.Add_Click({
        try {
            $safeText = $manualText -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
            $html = @"
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Grid Square Worked - Manual</title>
<style>
body { font-family: Consolas, 'Courier New', monospace; font-size: 11pt; line-height: 1.45; max-width: 900px; margin: 30px auto; padding: 0 30px; color: #222; }
pre { white-space: pre-wrap; word-wrap: break-word; font-family: inherit; font-size: inherit; margin: 0; }
@media print { body { font-size: 10pt; max-width: none; margin: 12mm; } }
</style></head>
<body><pre>$safeText</pre></body></html>
"@
            $outPath = Join-Path $script:ScriptDir 'GridSquareWorked-Manual.html'
            Set-Content -Path $outPath -Value $html -Encoding UTF8
            Start-Process $outPath
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Could not write manual file: $_", 'Manual') | Out-Null
        }
    })

    $dlg.AcceptButton = $btnClose
    $dlg.CancelButton = $btnClose
    Apply-Theme $dlg
    [void]$dlg.ShowDialog()
    $dlg.Dispose()
}

function Show-SettingsForm {
    $dlg = [System.Windows.Forms.Form]::new(); $dlg.Text = 'Settings'; $dlg.ClientSize = [System.Drawing.Size]::new(620, 960); $dlg.StartPosition = 'CenterParent'; $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
    $sy = 15
    $grpYou = [System.Windows.Forms.GroupBox]::new(); $grpYou.Text = 'Your details'; $grpYou.Location = [System.Drawing.Point]::new(15, $sy); $grpYou.Size = [System.Drawing.Size]::new(590, 170); $dlg.Controls.Add($grpYou)
    $yl = 25
    function Add-YouField { param($label, $value); $l = [System.Windows.Forms.Label]::new(); $l.Text = $label; $l.Location = [System.Drawing.Point]::new(15, ($script:yl + 3)); $l.Size = [System.Drawing.Size]::new(120, 20); $grpYou.Controls.Add($l); $t = [System.Windows.Forms.TextBox]::new(); $t.Location = [System.Drawing.Point]::new(140, $script:yl); $t.Size = [System.Drawing.Size]::new(430, 22); $t.Text = $value; $grpYou.Controls.Add($t); $script:yl += 30; return $t }
    $script:yl = $yl
    $txtCall = Add-YouField 'Callsign:' $script:Settings.Callsign
    $txtName = Add-YouField 'Name:' $script:Settings.Name
    $txtGrid = Add-YouField 'Grid Square:' $script:Settings.Grid
    $txtITU = Add-YouField 'ITU Zone:' $script:Settings.ITUZone
    $txtCQ = Add-YouField 'CQ Zone:' $script:Settings.CQZone
    $txtCall.CharacterCasing = 'Upper'; $txtGrid.CharacterCasing = 'Upper'
    $sy += 180
    $grpQRZ = [System.Windows.Forms.GroupBox]::new(); $grpQRZ.Text = 'QRZ Callsign Lookup (XML Data API)'; $grpQRZ.Location = [System.Drawing.Point]::new(15, $sy); $grpQRZ.Size = [System.Drawing.Size]::new(590, 195); $dlg.Controls.Add($grpQRZ)
    $hint = 'Fill in Callsign + QRZ Username + QRZ Password, then click Download.' + "`n" +
            'Leave the API Key blank - the Password is used automatically.' + "`n" +
            'Requires an active QRZ XML Data subscription.'
    $hintLbl = [System.Windows.Forms.Label]::new(); $hintLbl.Text = $hint; $hintLbl.Location = [System.Drawing.Point]::new(15, 18); $hintLbl.Size = [System.Drawing.Size]::new(560, 55); $hintLbl.ForeColor = [System.Drawing.Color]::FromArgb(0, 80, 160); $hintLbl.Font = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Italic); $grpQRZ.Controls.Add($hintLbl)
    $l1 = [System.Windows.Forms.Label]::new(); $l1.Text='QRZ Username:'; $l1.Location=[System.Drawing.Point]::new(15,80); $l1.Size=[System.Drawing.Size]::new(120,20); $grpQRZ.Controls.Add($l1)
    $txtUser = [System.Windows.Forms.TextBox]::new(); $txtUser.Location = [System.Drawing.Point]::new(140, 77); $txtUser.Size = [System.Drawing.Size]::new(430, 22); $txtUser.Text = $script:Settings.QRZUser; $grpQRZ.Controls.Add($txtUser)
    $l2 = [System.Windows.Forms.Label]::new(); $l2.Text='QRZ Password:'; $l2.Location=[System.Drawing.Point]::new(15,108); $l2.Size=[System.Drawing.Size]::new(120,20); $grpQRZ.Controls.Add($l2)
    $txtPass = [System.Windows.Forms.TextBox]::new(); $txtPass.Location = [System.Drawing.Point]::new(140, 105); $txtPass.Size = [System.Drawing.Size]::new(430, 22); $txtPass.UseSystemPasswordChar = $true; $txtPass.Text = $script:Settings.QRZPass; $grpQRZ.Controls.Add($txtPass)
    $l3 = [System.Windows.Forms.Label]::new(); $l3.Text='QRZ API Key:'; $l3.Location=[System.Drawing.Point]::new(15,136); $l3.Size=[System.Drawing.Size]::new(120,20); $grpQRZ.Controls.Add($l3)
    $txtApi = [System.Windows.Forms.TextBox]::new(); $txtApi.Location = [System.Drawing.Point]::new(140, 133); $txtApi.Size = [System.Drawing.Size]::new(430, 22); $txtApi.Text = $script:Settings.QRZApiKey; $grpQRZ.Controls.Add($txtApi)
    $lblApiOpt = [System.Windows.Forms.Label]::new(); $lblApiOpt.Text = 'Leave this blank to use your Password (most users).'; $lblApiOpt.Location = [System.Drawing.Point]::new(15, 158); $lblApiOpt.Size = [System.Drawing.Size]::new(560, 16); $lblApiOpt.ForeColor = [System.Drawing.Color]::FromArgb(0, 110, 60); $lblApiOpt.Font = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Italic); $grpQRZ.Controls.Add($lblApiOpt)
    $sy += 205

    $grpDx = [System.Windows.Forms.GroupBox]::new(); $grpDx.Text = 'DX Cluster'; $grpDx.Location = [System.Drawing.Point]::new(15, $sy); $grpDx.Size = [System.Drawing.Size]::new(590, 90); $dlg.Controls.Add($grpDx)
    $lDxCall = [System.Windows.Forms.Label]::new(); $lDxCall.Text = 'DX Cluster callsign:'; $lDxCall.Location = [System.Drawing.Point]::new(15, 25); $lDxCall.Size = [System.Drawing.Size]::new(150, 20); $grpDx.Controls.Add($lDxCall)
    $txtDxCall = [System.Windows.Forms.TextBox]::new(); $txtDxCall.Location = [System.Drawing.Point]::new(170, 22); $txtDxCall.Size = [System.Drawing.Size]::new(150, 22); $txtDxCall.CharacterCasing = 'Upper'; $txtDxCall.Text = $script:Settings.DxCallsign; $grpDx.Controls.Add($txtDxCall)
    $lDxHint = [System.Windows.Forms.Label]::new(); $lDxHint.Text = 'The login the cluster sees. Leave blank to use your main callsign.'; $lDxHint.Location = [System.Drawing.Point]::new(15, 50); $lDxHint.Size = [System.Drawing.Size]::new(560, 30); $lDxHint.ForeColor = [System.Drawing.Color]::Gray; $lDxHint.Font = [System.Drawing.Font]::new('Segoe UI', 8.5, [System.Drawing.FontStyle]::Italic); $grpDx.Controls.Add($lDxHint)
    $sy += 100

    $grpClock = [System.Windows.Forms.GroupBox]::new(); $grpClock.Text = 'Clock, Units and Labels'; $grpClock.Location = [System.Drawing.Point]::new(15, $sy); $grpClock.Size = [System.Drawing.Size]::new(590, 135); $dlg.Controls.Add($grpClock)
    $chkShowClock = [System.Windows.Forms.CheckBox]::new(); $chkShowClock.Text = 'Show clock on ribbon (Local + UTC)'; $chkShowClock.Location = [System.Drawing.Point]::new(15, 22); $chkShowClock.Size = [System.Drawing.Size]::new(280, 22); $chkShowClock.Checked = $script:Settings.ShowClock; $grpClock.Controls.Add($chkShowClock)
    $lblTheme = [System.Windows.Forms.Label]::new(); $lblTheme.Text = 'Theme:'; $lblTheme.Location = [System.Drawing.Point]::new(310, 24); $lblTheme.Size = [System.Drawing.Size]::new(55, 20); $grpClock.Controls.Add($lblTheme)
    $rbLight = [System.Windows.Forms.RadioButton]::new(); $rbLight.Text = 'Light'; $rbLight.Location = [System.Drawing.Point]::new(370, 22); $rbLight.Size = [System.Drawing.Size]::new(65, 22); $rbLight.Checked = ($script:Settings.Theme -ne 'Dark'); $grpClock.Controls.Add($rbLight)
    $rbDark = [System.Windows.Forms.RadioButton]::new(); $rbDark.Text = 'Dark'; $rbDark.Location = [System.Drawing.Point]::new(440, 22); $rbDark.Size = [System.Drawing.Size]::new(65, 22); $rbDark.Checked = ($script:Settings.Theme -eq 'Dark'); $grpClock.Controls.Add($rbDark)
    $lblFmt = [System.Windows.Forms.Label]::new(); $lblFmt.Text = 'Clock format:'; $lblFmt.Location = [System.Drawing.Point]::new(15, 50); $lblFmt.Size = [System.Drawing.Size]::new(100, 20); $grpClock.Controls.Add($lblFmt)
    $rb24 = [System.Windows.Forms.RadioButton]::new(); $rb24.Text = '24-hour'; $rb24.Location = [System.Drawing.Point]::new(125, 48); $rb24.Size = [System.Drawing.Size]::new(90, 22); $rb24.Checked = $script:Settings.Clock24h; $grpClock.Controls.Add($rb24)
    $rb12 = [System.Windows.Forms.RadioButton]::new(); $rb12.Text = 'AM / PM'; $rb12.Location = [System.Drawing.Point]::new(225, 48); $rb12.Size = [System.Drawing.Size]::new(90, 22); $rb12.Checked = -not $script:Settings.Clock24h; $grpClock.Controls.Add($rb12)
    $lblDist = [System.Windows.Forms.Label]::new(); $lblDist.Text = 'Distance units:'; $lblDist.Location = [System.Drawing.Point]::new(15, 78); $lblDist.Size = [System.Drawing.Size]::new(110, 20); $grpClock.Controls.Add($lblDist)
    $rbKm = [System.Windows.Forms.RadioButton]::new(); $rbKm.Text = 'Kilometres (km)'; $rbKm.Location = [System.Drawing.Point]::new(130, 76); $rbKm.Size = [System.Drawing.Size]::new(160, 22); $rbKm.Checked = -not $script:Settings.UseMiles; $grpClock.Controls.Add($rbKm)
    $rbMi = [System.Windows.Forms.RadioButton]::new(); $rbMi.Text = 'Miles (mi)'; $rbMi.Location = [System.Drawing.Point]::new(300, 76); $rbMi.Size = [System.Drawing.Size]::new(120, 22); $rbMi.Checked = $script:Settings.UseMiles; $grpClock.Controls.Add($rbMi)
    $chkGridLabelBg = [System.Windows.Forms.CheckBox]::new(); $chkGridLabelBg.Text = 'Show box behind grid labels on maps (turn off to see the map better)'; $chkGridLabelBg.Location = [System.Drawing.Point]::new(15, 104); $chkGridLabelBg.Size = [System.Drawing.Size]::new(560, 22); $chkGridLabelBg.Checked = $script:Settings.ShowGridLabelBg; $grpClock.Controls.Add($chkGridLabelBg)
    $sy += 145
    $grpLoc = [System.Windows.Forms.GroupBox]::new(); $grpLoc.Text = 'Locate mode'; $grpLoc.Location = [System.Drawing.Point]::new(15, $sy); $grpLoc.Size = [System.Drawing.Size]::new(590, 55); $dlg.Controls.Add($grpLoc)
    $rbAuto = [System.Windows.Forms.RadioButton]::new(); $rbAuto.Text = 'Auto locate (fill from QRZ)'; $rbAuto.Location = [System.Drawing.Point]::new(15, 22); $rbAuto.Size = [System.Drawing.Size]::new(220, 22); $rbAuto.Checked = $script:Settings.AutoLocate; $grpLoc.Controls.Add($rbAuto)
    $rbManual = [System.Windows.Forms.RadioButton]::new(); $rbManual.Text = 'Manual locate (type my own)'; $rbManual.Location = [System.Drawing.Point]::new(245, 22); $rbManual.Size = [System.Drawing.Size]::new(250, 22); $rbManual.Checked = -not $script:Settings.AutoLocate; $grpLoc.Controls.Add($rbManual)
    $sy += 65

    $grpTabs = [System.Windows.Forms.GroupBox]::new(); $grpTabs.Text = 'Visible tabs'; $grpTabs.Location = [System.Drawing.Point]::new(15, $sy); $grpTabs.Size = [System.Drawing.Size]::new(590, 130); $dlg.Controls.Add($grpTabs)
    $tabChecks = @{}
    $cx = 15; $cy = 22; $col = 0
    foreach ($def in $script:TabDefs) {
        $chk = [System.Windows.Forms.CheckBox]::new()
        $chk.Text = $def.Label
        $chk.Location = [System.Drawing.Point]::new($cx, $cy)
        $chk.Size = [System.Drawing.Size]::new(190, 22)
        $chk.Checked = ($script:Settings.VisibleTabs -contains $def.Key)
        if ($def.Key -eq 'Log') { $chk.Enabled = $false; $chk.Checked = $true }
        $grpTabs.Controls.Add($chk)
        $tabChecks[$def.Key] = $chk
        $col++
        $cy += 26
        if ($col -ge 4) { $col = 0; $cx += 200; $cy = 22 }
    }
    $btnDefaultTabs = [System.Windows.Forms.Button]::new(); $btnDefaultTabs.Text = 'Default (all)'
    $btnDefaultTabs.Location = [System.Drawing.Point]::new(470, 22); $btnDefaultTabs.Size = [System.Drawing.Size]::new(105, 26)
    $grpTabs.Controls.Add($btnDefaultTabs)
    $btnDefaultTabs.Add_Click({ foreach ($def in $script:TabDefs) { if ($tabChecks.ContainsKey($def.Key)) { $tabChecks[$def.Key].Checked = $true } } })
    $sy += 140

    $btnQRZ = [System.Windows.Forms.Button]::new(); $btnQRZ.Text = 'Download from QRZ'; $btnQRZ.Location = [System.Drawing.Point]::new(15, ($sy + 5)); $btnQRZ.Size = [System.Drawing.Size]::new(160, 34); $btnQRZ.Font = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Bold); $dlg.Controls.Add($btnQRZ)
    $btnClearS = [System.Windows.Forms.Button]::new(); $btnClearS.Text = 'Clear fields'; $btnClearS.Location = [System.Drawing.Point]::new(185, ($sy + 5)); $btnClearS.Size = [System.Drawing.Size]::new(95, 34); $dlg.Controls.Add($btnClearS)
    $btnSaveS = [System.Windows.Forms.Button]::new(); $btnSaveS.Text = 'Save'; $btnSaveS.Location = [System.Drawing.Point]::new(470, ($sy + 5)); $btnSaveS.Size = [System.Drawing.Size]::new(60, 34); $btnSaveS.DialogResult = [System.Windows.Forms.DialogResult]::OK; $dlg.Controls.Add($btnSaveS)
    $btnCancel = [System.Windows.Forms.Button]::new(); $btnCancel.Text = 'Cancel'; $btnCancel.Location = [System.Drawing.Point]::new(535, ($sy + 5)); $btnCancel.Size = [System.Drawing.Size]::new(60, 34); $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dlg.Controls.Add($btnCancel)
    Set-FlatButton $btnQRZ; Set-FlatButton $btnClearS; Set-FlatButton $btnSaveS; Set-FlatButton $btnCancel; Set-FlatButton $btnDefaultTabs

    $btnClearS.Add_Click({ $txtCall.Text = ''; $txtName.Text = ''; $txtGrid.Text = ''; $txtITU.Text = ''; $txtCQ.Text = ''; $txtUser.Text = ''; $txtPass.Text = ''; $txtApi.Text = ''; $txtDxCall.Text = '' })

    $dlg.AcceptButton = $btnSaveS; $dlg.CancelButton = $btnCancel
    $updateQRZEnabled = { $btnQRZ.Enabled = $rbAuto.Checked; if (-not $rbAuto.Checked) { $btnQRZ.Text = 'Manual mode' } else { $btnQRZ.Text = 'Download from QRZ' } }
    $rbAuto.Add_CheckedChanged($updateQRZEnabled); $rbManual.Add_CheckedChanged($updateQRZEnabled); & $updateQRZEnabled

    $btnQRZ.Add_Click({
        try {
            $call = $txtCall.Text.Trim().ToUpper()
            $u = $txtUser.Text.Trim()
            $p = $txtPass.Text
            $k = $txtApi.Text.Trim()
            $missing = @()
            if (-not $call) { $missing += 'Callsign' }
            if (-not $u) { $missing += 'QRZ Username' }
            if (-not $p -and -not $k) { $missing += 'QRZ Password (or API Key)' }
            if ($missing.Count -gt 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Please fill in:`n`n  - " + ($missing -join "`n  - ") + "`n`n" +
                    "Requires an active QRZ XML Data subscription for callsign lookups.",
                    'Missing details', 'OK', 'Warning') | Out-Null
                return
            }
            if ($script:QRZSessionUser -ne $u) { Reset-QRZCache }
            $btnQRZ.Enabled = $false; $btnQRZ.Text = 'Querying...'; $dlg.Refresh()
            try {
                $sess = Get-QRZSessionCached -User $u -Pass $p -ApiKey $k
                if (-not $sess.Ok) {
                    $errText = $sess.Error
                    $extra = ''
                    if ($errText -match '(?i)blocked') {
                        $extra = "`n`nThis is a QRZ-side block on your IP address.  Wait 20 minutes without retrying, then click once.  Repeated clicks extend the block."
                    } elseif ($errText -match '(?i)incorrect|invalid') {
                        $extra = "`n`nQRZ does not recognise that username/password combination.  The username can be your QRZ login name OR your callsign (case-sensitive).  Check the QRZ website first."
                    } elseif ($errText -match '(?i)subscription') {
                        $extra = "`n`nQRZ's XML Data API requires a paid subscription.  Check Account -> XML Subscription on qrz.com."
                    }
                    [System.Windows.Forms.MessageBox]::Show(
                        "QRZ login failed.`n`nQRZ said: `"$errText`"`n`nFull response:`n$($sess.Raw)$extra",
                        'QRZ login error', 'OK', 'Warning') | Out-Null
                    return
                }
                $cs = Get-QRZCallsign -SessionKey $sess.Key -Callsign $call
                if ($null -eq $cs) { throw 'No data returned for that callsign.' }
                $fname=''; try { $fname = [string]$cs.fname } catch {}
                $lname=''; try { $lname = [string]$cs.name } catch {}
                $full = ($fname + ' ' + $lname).Trim(); if ($full) { $txtName.Text = $full }
                $g=''; try { $g = [string]$cs.grid } catch {}; if ($g) { $txtGrid.Text = $g.ToUpper() }
                $itu=''; try { $itu = [string]$cs.ituzone } catch {}; if ($itu) { $txtITU.Text = $itu }
                $cq=''; try { $cq = [string]$cs.cqzone } catch {}; if ($cq) { $txtCQ.Text = $cq }
                if ((-not $itu -or -not $cq) -and $g) {
                    $z = Get-ZonesFromGrid $g
                    if (-not $itu -and $z.ITU) { $txtITU.Text = $z.ITU }
                    if (-not $cq -and $z.CQ) { $txtCQ.Text = $z.CQ }
                }
                $btnQRZ.Text = 'Downloaded!'
                [System.Windows.Forms.MessageBox]::Show("Downloaded from QRZ:`n`nCall: $call`nName: $full`nGrid: $g`nITU: $($txtITU.Text)`nCQ: $($txtCQ.Text)", 'QRZ Success')
            } catch {
                [System.Windows.Forms.MessageBox]::Show("QRZ error: $_", 'QRZ')
            } finally {
                $btnQRZ.Enabled = $rbAuto.Checked
                if ($btnQRZ.Text -eq 'Querying...') { $btnQRZ.Text = 'Download from QRZ' }
            }
        } catch { [System.Windows.Forms.MessageBox]::Show("Unexpected error: $_", 'QRZ') }
    })

    Apply-Theme $dlg

    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:Settings.Callsign = $txtCall.Text.Trim().ToUpper(); $script:Settings.Name = $txtName.Text.Trim()
        $script:Settings.Grid = $txtGrid.Text.Trim().ToUpper(); $script:Settings.ITUZone = $txtITU.Text.Trim(); $script:Settings.CQZone = $txtCQ.Text.Trim()
        $script:Settings.QRZUser = $txtUser.Text.Trim(); $script:Settings.QRZPass = $txtPass.Text
        $script:Settings.QRZApiKey = $txtApi.Text.Trim()
        $script:Settings.DxCallsign = $txtDxCall.Text.Trim().ToUpper()
        $script:Settings.AutoLocate = $rbAuto.Checked; $script:Settings.ShowClock = $chkShowClock.Checked; $script:Settings.Clock24h = $rb24.Checked
        $script:Settings.UseMiles = $rbMi.Checked
        $script:Settings.ShowGridLabelBg = $chkGridLabelBg.Checked
        $script:Settings.Theme = if ($rbDark.Checked) { 'Dark' } else { 'Light' }
        $vis = @()
        foreach ($def in $script:TabDefs) { if ($tabChecks.ContainsKey($def.Key) -and $tabChecks[$def.Key].Checked) { $vis += $def.Key } }
        if ($vis -notcontains 'Log') { $vis += 'Log' }
        $script:Settings.VisibleTabs = $vis
        Save-Settings
        if ($script:Settings.Grid) { $txtSearch.Text = $script:Settings.Grid }
        Apply-TabVisibility
        Apply-Theme $form
        Update-Ribbon; Update-Status; Refresh-LogView; Render-AllMaps
    }
    $dlg.Dispose()
}

function Show-ColourForm {
    $dlg = [System.Windows.Forms.Form]::new(); $dlg.Text = 'Change Colours'; $dlg.ClientSize = [System.Drawing.Size]::new(500, 540); $dlg.StartPosition = 'CenterParent'; $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
    $lblInfo = [System.Windows.Forms.Label]::new(); $lblInfo.Text = 'Pick colours for each element. Click a swatch to change it.'; $lblInfo.Location = [System.Drawing.Point]::new(15, 15); $lblInfo.Size = [System.Drawing.Size]::new(470, 20); $dlg.Controls.Add($lblInfo)
    $items = @(
        @{ Name='Ribbon background';     Key='ColorRibbon';       Default=[System.Drawing.Color]::FromArgb(30,60,110) },
        @{ Name='Callsign text';         Key='ColorCallsign';     Default=[System.Drawing.Color]::White },
        @{ Name='Clock text';            Key='ColorClock';        Default=[System.Drawing.Color]::FromArgb(200,240,200) },
        @{ Name='ITU / CQ zone text';    Key='ColorZones';        Default=[System.Drawing.Color]::FromArgb(255,220,150) },
        @{ Name='4-Grid Square';         Key='Color4Char';        Default=[System.Drawing.Color]::FromArgb(175,230,175) },
        @{ Name='6-Grid Square';         Key='Color6Char';        Default=[System.Drawing.Color]::FromArgb(40,175,60) },
        @{ Name='Selected square';       Key='ColorSelection';    Default=[System.Drawing.Color]::FromArgb(210,100,0) },
        @{ Name='Grid label text (map)'; Key='ColorGridLabelText';Default=[System.Drawing.Color]::FromArgb(20,20,20) },
        @{ Name='Grid label box (map)';  Key='ColorGridLabelBg';  Default=[System.Drawing.Color]::White }
    )
    $y = 50; $swatches = @{}
    foreach ($it in $items) {
        $l = [System.Windows.Forms.Label]::new(); $l.Text = $it.Name + ':'; $l.Location = [System.Drawing.Point]::new(15, ($y + 5)); $l.Size = [System.Drawing.Size]::new(190, 20); $dlg.Controls.Add($l)
        $sw = [System.Windows.Forms.Panel]::new(); $sw.Location = [System.Drawing.Point]::new(210, $y); $sw.Size = [System.Drawing.Size]::new(60, 26); $sw.BorderStyle = 'FixedSingle'; $sw.Cursor = [System.Windows.Forms.Cursors]::Hand
        $c = Get-ColorFromString $script:Settings.($it.Key) $it.Default
        $sw.BackColor = $c; $sw.Tag = $it.Key; $dlg.Controls.Add($sw); $swatches[$it.Key] = $sw
        $y += 40
    }
    foreach ($key in $swatches.Keys) { $swatches[$key].Add_Click({ $cd = [System.Windows.Forms.ColorDialog]::new(); $cd.Color = $this.BackColor; if ($cd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $this.BackColor = $cd.Color }; $cd.Dispose() }) }
    $lblNote = [System.Windows.Forms.Label]::new(); $lblNote.Text = 'To hide the box behind grid labels, uncheck it in Settings.'; $lblNote.Location = [System.Drawing.Point]::new(15, ($y + 5)); $lblNote.Size = [System.Drawing.Size]::new(470, 20); $lblNote.ForeColor = [System.Drawing.Color]::Gray; $lblNote.Font = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Italic); $dlg.Controls.Add($lblNote)
    $btnReset = [System.Windows.Forms.Button]::new(); $btnReset.Text = 'Reset defaults'; $btnReset.Location = [System.Drawing.Point]::new(15, ($y + 35)); $btnReset.Size = [System.Drawing.Size]::new(130, 30); $dlg.Controls.Add($btnReset)
    $btnReset.Add_Click({
        $swatches['ColorRibbon'].BackColor = [System.Drawing.Color]::FromArgb(30,60,110)
        $swatches['ColorCallsign'].BackColor = [System.Drawing.Color]::White
        $swatches['ColorClock'].BackColor = [System.Drawing.Color]::FromArgb(200,240,200)
        $swatches['ColorZones'].BackColor = [System.Drawing.Color]::FromArgb(255,220,150)
        $swatches['Color4Char'].BackColor = [System.Drawing.Color]::FromArgb(175,230,175)
        $swatches['Color6Char'].BackColor = [System.Drawing.Color]::FromArgb(40,175,60)
        $swatches['ColorSelection'].BackColor = [System.Drawing.Color]::FromArgb(210,100,0)
        $swatches['ColorGridLabelText'].BackColor = [System.Drawing.Color]::FromArgb(20,20,20)
        $swatches['ColorGridLabelBg'].BackColor = [System.Drawing.Color]::White
    })
    $btnOK = [System.Windows.Forms.Button]::new(); $btnOK.Text = 'Save'; $btnOK.Location = [System.Drawing.Point]::new(295, ($y + 35)); $btnOK.Size = [System.Drawing.Size]::new(90, 30); $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK; $dlg.Controls.Add($btnOK)
    $btnCancel = [System.Windows.Forms.Button]::new(); $btnCancel.Text = 'Cancel'; $btnCancel.Location = [System.Drawing.Point]::new(395, ($y + 35)); $btnCancel.Size = [System.Drawing.Size]::new(90, 30); $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dlg.Controls.Add($btnCancel)
    Set-FlatButton $btnReset; Set-FlatButton $btnOK; Set-FlatButton $btnCancel
    $dlg.AcceptButton = $btnOK; $dlg.CancelButton = $btnCancel
    Apply-Theme $dlg
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($key in $swatches.Keys) { $script:Settings.$key = Set-ColorToString $swatches[$key].BackColor }
        Save-Settings
        Update-Ribbon
        Render-AllMaps
    }
    $dlg.Dispose()
}

function Refresh-Propagation {
    if ($null -eq $script:PropGrid) { return }
    $script:PropStatus.Text = 'Fetching propagation data from hamqsl.com...'
    [System.Windows.Forms.Application]::DoEvents()
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $wc = [System.Net.WebClient]::new(); $wc.Headers.Add('User-Agent', 'Mozilla/5.0')
        $xml = [xml]$wc.DownloadString('https://www.hamqsl.com/solarxml.php'); $wc.Dispose()
        $sd = $xml.solar.solardata
        $script:PropHeader.Text = "Solar Flux: $($sd.solarflux)    A-index: $($sd.aindex)    K-index: $($sd.kindex)    Sunspots: $($sd.sunspots)    Updated: $($sd.updated)"
        $script:PropGrid.Rows.Clear(); $map = @{}
        foreach ($b in $sd.calculatedconditions.band) {
            $name = [string]$b.name; $t = [string]$b.time; $val = [string]$b.'#text'
            if (-not $val) { $val = [string]$b }
            if (-not $map.ContainsKey($name)) { $map[$name] = @{ Day='-'; Night='-' } }
            if ($t -eq 'day') { $map[$name].Day = $val }
            if ($t -eq 'night') { $map[$name].Night = $val }
        }
        foreach ($name in $map.Keys) {
            $idx = $script:PropGrid.Rows.Add($name, $map[$name].Day, $map[$name].Night)
            $row = $script:PropGrid.Rows[$idx]
            foreach ($col in 1..2) {
                $v = $row.Cells[$col].Value
                if ($v -match 'Good') { $row.Cells[$col].Style.BackColor = [System.Drawing.Color]::LightGreen; $row.Cells[$col].Style.ForeColor = [System.Drawing.Color]::Black }
                elseif ($v -match 'Fair') { $row.Cells[$col].Style.BackColor = [System.Drawing.Color]::Khaki; $row.Cells[$col].Style.ForeColor = [System.Drawing.Color]::Black }
                elseif ($v -match 'Poor') { $row.Cells[$col].Style.BackColor = [System.Drawing.Color]::LightSalmon; $row.Cells[$col].Style.ForeColor = [System.Drawing.Color]::Black }
                elseif ($v -match 'Band Cl') { $row.Cells[$col].Style.BackColor = [System.Drawing.Color]::LightGray; $row.Cells[$col].Style.ForeColor = [System.Drawing.Color]::Black }
            }
        }
        $vhfRows = @(
            @('6m',   'Sporadic E in season',  'Sporadic E less common'),
            @('4m',   'Sporadic E in season',  'Rare'),
            @('2m',   'Tropo / Sporadic E',    'Tropo possible'),
            @('70cm', 'Tropo / line of sight', 'Tropo possible')
        )
        foreach ($vr in $vhfRows) {
            $idx = $script:PropGrid.Rows.Add($vr[0], $vr[1], $vr[2])
            $script:PropGrid.Rows[$idx].Cells[0].Style.BackColor = [System.Drawing.Color]::LightSteelBlue
            $script:PropGrid.Rows[$idx].Cells[0].Style.ForeColor = [System.Drawing.Color]::Black
        }
        $script:PropStatus.Text = "Loaded $($script:PropGrid.Rows.Count) band rows. HF data: hamqsl.com (N0NBH)."
    } catch { $script:PropStatus.Text = "Could not fetch propagation data: $_" }
}

# ============ MAIN FORM ============
$form = [System.Windows.Forms.Form]::new()
$form.Text = 'Grid Square Worked  -  D&C Ham Adventure (M7ANI) 2026'
$form.ClientSize = [System.Drawing.Size]::new(1200, 800); $form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'Sizable'; $form.MaximizeBox = $true; $form.MinimizeBox = $true
$form.MinimumSize = [System.Drawing.Size]::new(850, 660); $form.WindowState = 'Maximized'

$menu = [System.Windows.Forms.MenuStrip]::new()
$miFile = [System.Windows.Forms.ToolStripMenuItem]::new('File')
$miLoad = [System.Windows.Forms.ToolStripMenuItem]::new('Load grids...')
$miSave = [System.Windows.Forms.ToolStripMenuItem]::new('Save grids...')
$miExit = [System.Windows.Forms.ToolStripMenuItem]::new('Exit')
$miFile.DropDownItems.Add($miLoad) | Out-Null
$miFile.DropDownItems.Add($miSave) | Out-Null
$miFile.DropDownItems.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
$miFile.DropDownItems.Add($miExit) | Out-Null
$menu.Items.Add($miFile) | Out-Null
$miSettings = [System.Windows.Forms.ToolStripMenuItem]::new('Settings')
$miOpenSettings = [System.Windows.Forms.ToolStripMenuItem]::new('Settings...')
$miChangeColour = [System.Windows.Forms.ToolStripMenuItem]::new('Change Colour...')
$miSettings.DropDownItems.Add($miOpenSettings) | Out-Null
$miSettings.DropDownItems.Add($miChangeColour) | Out-Null
$menu.Items.Add($miSettings) | Out-Null
$miHelp = [System.Windows.Forms.ToolStripMenuItem]::new('Help')
$miManual = [System.Windows.Forms.ToolStripMenuItem]::new('Manual...')
$miAbout = [System.Windows.Forms.ToolStripMenuItem]::new('About')
$miContact = [System.Windows.Forms.ToolStripMenuItem]::new('Contact / Bug reports')
$miHelp.DropDownItems.Add($miManual) | Out-Null
$miHelp.DropDownItems.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
$miHelp.DropDownItems.Add($miContact) | Out-Null
$miHelp.DropDownItems.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
$miHelp.DropDownItems.Add($miAbout) | Out-Null
$menu.Items.Add($miHelp) | Out-Null
$form.MainMenuStrip = $menu; $form.Controls.Add($menu)
$script:MainMenu = $menu

$ribbon = [System.Windows.Forms.Panel]::new(); $ribbon.Location = [System.Drawing.Point]::new(0, 24); $ribbon.Size = [System.Drawing.Size]::new($form.ClientSize.Width, 40); $ribbon.BackColor = [System.Drawing.Color]::FromArgb(30, 60, 110); $ribbon.Anchor = 'Top,Left,Right'; $form.Controls.Add($ribbon)
$script:RibbonPanel = $ribbon
$ribbonCopy = [System.Windows.Forms.Label]::new(); $ribbonCopy.Text = '© D&C Ham Adventure (M7ANI) 2026'; $ribbonCopy.Font = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Italic); $ribbonCopy.ForeColor = [System.Drawing.Color]::FromArgb(180, 200, 220); $ribbonCopy.BackColor = [System.Drawing.Color]::Transparent; $ribbonCopy.Dock = 'Right'; $ribbonCopy.Width = 240; $ribbonCopy.TextAlign = 'MiddleRight'; $ribbon.Controls.Add($ribbonCopy)
$ribbonCall = [System.Windows.Forms.Label]::new(); $ribbonCall.Text = 'Set your callsign in Settings'; $ribbonCall.Font = [System.Drawing.Font]::new('Segoe UI', 12, [System.Drawing.FontStyle]::Bold); $ribbonCall.ForeColor = [System.Drawing.Color]::White; $ribbonCall.BackColor = [System.Drawing.Color]::Transparent; $ribbonCall.Location = [System.Drawing.Point]::new(12, 8); $ribbonCall.AutoSize = $true; $ribbon.Controls.Add($ribbonCall); $script:RibbonCall = $ribbonCall
$ribbonName = [System.Windows.Forms.Label]::new(); $ribbonName.Font = [System.Drawing.Font]::new('Segoe UI', 10); $ribbonName.ForeColor = [System.Drawing.Color]::FromArgb(220, 230, 245); $ribbonName.BackColor = [System.Drawing.Color]::Transparent; $ribbonName.Location = [System.Drawing.Point]::new(120, 12); $ribbonName.AutoSize = $true; $ribbon.Controls.Add($ribbonName); $script:RibbonName = $ribbonName
$ribbonClock = [System.Windows.Forms.Label]::new(); $ribbonClock.Font = [System.Drawing.Font]::new('Consolas', 9, [System.Drawing.FontStyle]::Bold); $ribbonClock.ForeColor = [System.Drawing.Color]::FromArgb(200, 240, 200); $ribbonClock.BackColor = [System.Drawing.Color]::Transparent; $ribbonClock.Location = [System.Drawing.Point]::new(240, 13); $ribbonClock.AutoSize = $true; $ribbonClock.Text = ''; $ribbon.Controls.Add($ribbonClock); $script:ClockLabel = $ribbonClock
$ribbonGrid = [System.Windows.Forms.Label]::new(); $ribbonGrid.Font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold); $ribbonGrid.ForeColor = [System.Drawing.Color]::FromArgb(180, 220, 255); $ribbonGrid.BackColor = [System.Drawing.Color]::Transparent; $ribbonGrid.Location = [System.Drawing.Point]::new(530, 11); $ribbonGrid.AutoSize = $true; $ribbon.Controls.Add($ribbonGrid); $script:RibbonGrid = $ribbonGrid
$ribbonZones = [System.Windows.Forms.Label]::new(); $ribbonZones.Font = [System.Drawing.Font]::new('Segoe UI', 9); $ribbonZones.ForeColor = [System.Drawing.Color]::FromArgb(255, 220, 150); $ribbonZones.BackColor = [System.Drawing.Color]::Transparent; $ribbonZones.Location = [System.Drawing.Point]::new(680, 13); $ribbonZones.AutoSize = $true; $ribbon.Controls.Add($ribbonZones); $script:RibbonZones = $ribbonZones
$ribbonGridCount = [System.Windows.Forms.Label]::new(); $ribbonGridCount.Font = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Bold); $ribbonGridCount.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 200); $ribbonGridCount.BackColor = [System.Drawing.Color]::Transparent; $ribbonGridCount.Location = [System.Drawing.Point]::new(850, 13); $ribbonGridCount.AutoSize = $true; $ribbonGridCount.Text = 'Grids logged: 0'; $ribbon.Controls.Add($ribbonGridCount); $script:GridCountLabel = $ribbonGridCount

$topBase = 70
$lblSearch = [System.Windows.Forms.Label]::new(); $lblSearch.Text = 'Search:'; $lblSearch.Location = [System.Drawing.Point]::new(15, ($topBase+3)); $lblSearch.Size = [System.Drawing.Size]::new(55, 20); $lblSearch.Anchor = 'Top,Left'; $lblSearch.BackColor = 'Transparent'; $form.Controls.Add($lblSearch)
$txtSearch = [System.Windows.Forms.TextBox]::new(); $txtSearch.Location = [System.Drawing.Point]::new(75, $topBase); $txtSearch.Size = [System.Drawing.Size]::new(90, 22); $txtSearch.CharacterCasing = 'Upper'; $txtSearch.Text = 'IO83'; $txtSearch.Anchor = 'Top,Left'; $form.Controls.Add($txtSearch)
$btnGo = [System.Windows.Forms.Button]::new(); $btnGo.Text = 'Go'; $btnGo.Location = [System.Drawing.Point]::new(170, ($topBase-1)); $btnGo.Size = [System.Drawing.Size]::new(45, 24); $btnGo.Anchor = 'Top,Left'; $form.Controls.Add($btnGo)
$btnADIF = [System.Windows.Forms.Button]::new(); $btnADIF.Text = 'Upload ADIF'; $btnADIF.Location = [System.Drawing.Point]::new(225, ($topBase-2)); $btnADIF.Size = [System.Drawing.Size]::new(95, 26); $btnADIF.Anchor = 'Top,Left'; $form.Controls.Add($btnADIF)
$btnSave = [System.Windows.Forms.Button]::new(); $btnSave.Text = 'Save'; $btnSave.Location = [System.Drawing.Point]::new(330, ($topBase-2)); $btnSave.Size = [System.Drawing.Size]::new(65, 26); $btnSave.Anchor = 'Top,Left'; $form.Controls.Add($btnSave)
$btnLoad = [System.Windows.Forms.Button]::new(); $btnLoad.Text = 'Load'; $btnLoad.Location = [System.Drawing.Point]::new(400, ($topBase-2)); $btnLoad.Size = [System.Drawing.Size]::new(65, 26); $btnLoad.Anchor = 'Top,Left'; $form.Controls.Add($btnLoad)
$btnClear = [System.Windows.Forms.Button]::new(); $btnClear.Text = 'Clear'; $btnClear.Location = [System.Drawing.Point]::new(470, ($topBase-2)); $btnClear.Size = [System.Drawing.Size]::new(65, 26); $btnClear.Anchor = 'Top,Left'; $form.Controls.Add($btnClear)
$lblZoom = [System.Windows.Forms.Label]::new(); $lblZoom.Text = 'Zoom:'; $lblZoom.Location = [System.Drawing.Point]::new(545, ($topBase-1)); $lblZoom.Size = [System.Drawing.Size]::new(45, 20); $lblZoom.Anchor = 'Top,Left'; $lblZoom.BackColor = 'Transparent'; $form.Controls.Add($lblZoom)
$zoomSlider = [System.Windows.Forms.TrackBar]::new(); $zoomSlider.Minimum = 0; $zoomSlider.Maximum = 95; $zoomSlider.TickFrequency = 5; $zoomSlider.LargeChange = 5; $zoomSlider.SmallChange = 1; $zoomSlider.Location = [System.Drawing.Point]::new(590, ($topBase-4)); $zoomSlider.Size = [System.Drawing.Size]::new(200, 30); $zoomSlider.Anchor = 'Top,Left'; $form.Controls.Add($zoomSlider); $script:ZoomSlider = $zoomSlider
$btnReset = [System.Windows.Forms.Button]::new(); $btnReset.Text = 'Reset'; $btnReset.Location = [System.Drawing.Point]::new(880, ($topBase-2)); $btnReset.Size = [System.Drawing.Size]::new(65, 26); $btnReset.Anchor = 'Top,Left'; $form.Controls.Add($btnReset)

$top2 = $topBase + 32
$lblMode = [System.Windows.Forms.Label]::new(); $lblMode.Text = 'Mode:'; $lblMode.Location = [System.Drawing.Point]::new(15, ($top2+3)); $lblMode.Size = [System.Drawing.Size]::new(45, 20); $lblMode.Anchor = 'Top,Left'; $lblMode.BackColor = 'Transparent'; $form.Controls.Add($lblMode)
$cboMode = [System.Windows.Forms.ComboBox]::new(); $cboMode.Location = [System.Drawing.Point]::new(60, $top2); $cboMode.Size = [System.Drawing.Size]::new(90, 22); $cboMode.DropDownStyle = 'DropDownList'; $cboMode.Anchor = 'Top,Left'; foreach ($m in $script:ModeList) { $cboMode.Items.Add($m) | Out-Null }; $cboMode.SelectedIndex = 0; $form.Controls.Add($cboMode); $script:CboMode = $cboMode
$lblBand = [System.Windows.Forms.Label]::new(); $lblBand.Text = 'Band:'; $lblBand.Location = [System.Drawing.Point]::new(165, ($top2+3)); $lblBand.Size = [System.Drawing.Size]::new(45, 20); $lblBand.Anchor = 'Top,Left'; $lblBand.BackColor = 'Transparent'; $form.Controls.Add($lblBand)
$cboBand = [System.Windows.Forms.ComboBox]::new(); $cboBand.Location = [System.Drawing.Point]::new(210, $top2); $cboBand.Size = [System.Drawing.Size]::new(90, 22); $cboBand.DropDownStyle = 'DropDownList'; $cboBand.Anchor = 'Top,Left'; foreach ($b in $script:BandList) { $cboBand.Items.Add($b) | Out-Null }; $cboBand.SelectedIndex = 0; $form.Controls.Add($cboBand); $script:CboBand = $cboBand
$lblMapFilterNote = [System.Windows.Forms.Label]::new(); $lblMapFilterNote.Text = 'Selection is for the maps'; $lblMapFilterNote.Location = [System.Drawing.Point]::new(310, ($top2+3)); $lblMapFilterNote.Size = [System.Drawing.Size]::new(220, 20); $lblMapFilterNote.Anchor = 'Top,Left'; $lblMapFilterNote.ForeColor = [System.Drawing.Color]::Gray; $lblMapFilterNote.Font = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Italic); $lblMapFilterNote.BackColor = 'Transparent'; $form.Controls.Add($lblMapFilterNote)

$topLegend = $top2 + 26
$lblLegendTitle = [System.Windows.Forms.Label]::new(); $lblLegendTitle.Text = 'Legend:'; $lblLegendTitle.Location = [System.Drawing.Point]::new(15, ($topLegend+3)); $lblLegendTitle.Size = [System.Drawing.Size]::new(55, 20); $lblLegendTitle.BackColor = 'Transparent'; $form.Controls.Add($lblLegendTitle)
$sw4 = [System.Windows.Forms.Panel]::new(); $sw4.Location = [System.Drawing.Point]::new(70, ($topLegend+2)); $sw4.Size = [System.Drawing.Size]::new(20, 20); $sw4.BorderStyle = 'FixedSingle'; $form.Controls.Add($sw4); $script:LegendSw4 = $sw4
$lblLegend4 = [System.Windows.Forms.Label]::new(); $lblLegend4.Text = '= 4 Grid'; $lblLegend4.Location = [System.Drawing.Point]::new(95, ($topLegend+3)); $lblLegend4.Size = [System.Drawing.Size]::new(70, 20); $lblLegend4.BackColor = 'Transparent'; $form.Controls.Add($lblLegend4)
$sw6 = [System.Windows.Forms.Panel]::new(); $sw6.Location = [System.Drawing.Point]::new(170, ($topLegend+2)); $sw6.Size = [System.Drawing.Size]::new(20, 20); $sw6.BorderStyle = 'FixedSingle'; $form.Controls.Add($sw6); $script:LegendSw6 = $sw6
$lblLegend6 = [System.Windows.Forms.Label]::new(); $lblLegend6.Text = '= 6 Grid'; $lblLegend6.Location = [System.Drawing.Point]::new(195, ($topLegend+3)); $lblLegend6.Size = [System.Drawing.Size]::new(70, 20); $lblLegend6.BackColor = 'Transparent'; $form.Controls.Add($lblLegend6)
$swSel = [System.Windows.Forms.Panel]::new(); $swSel.Location = [System.Drawing.Point]::new(270, ($topLegend+2)); $swSel.Size = [System.Drawing.Size]::new(20, 20); $swSel.BorderStyle = 'FixedSingle'; $form.Controls.Add($swSel); $script:LegendSwSel = $swSel
$lblLegendSel = [System.Windows.Forms.Label]::new(); $lblLegendSel.Text = '= Current Selection'; $lblLegendSel.Location = [System.Drawing.Point]::new(295, ($topLegend+3)); $lblLegendSel.Size = [System.Drawing.Size]::new(180, 20); $lblLegendSel.BackColor = 'Transparent'; $form.Controls.Add($lblLegendSel)

$top3 = $topLegend + 26
$lblStatus = [System.Windows.Forms.Label]::new(); $lblStatus.Location = [System.Drawing.Point]::new(15, $top3); $lblStatus.Size = [System.Drawing.Size]::new(1170, 20); $lblStatus.BackColor = 'Transparent'; $lblStatus.Text = 'Ready.'; $lblStatus.Anchor = 'Top,Left,Right'; $form.Controls.Add($lblStatus); $script:LblStatusCtrl = $lblStatus

$lblCopyright = [System.Windows.Forms.Label]::new(); $lblCopyright.Text = '© D&C Ham Adventure (M7ANI) 2026  -  Grid Square Worked'; $lblCopyright.AutoSize = $false; $lblCopyright.TextAlign = 'MiddleRight'; $lblCopyright.ForeColor = [System.Drawing.Color]::Gray; $lblCopyright.BackColor = 'Transparent'; $lblCopyright.Font = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Italic); $lblCopyright.Dock = 'Bottom'; $lblCopyright.Height = 20; $form.Controls.Add($lblCopyright)

$topTabs = $top3 + 24
$tabs = [System.Windows.Forms.TabControl]::new()
$tabs.Location = [System.Drawing.Point]::new(15, $topTabs); $tabs.Size = [System.Drawing.Size]::new(1170, 660); $tabs.Anchor = 'Top,Bottom,Left,Right'
$tabs.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed; $tabs.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed
$tabs.ItemSize = [System.Drawing.Size]::new(110, 26); $tabs.Padding = [System.Drawing.Point]::new(0, 0); $tabs.Font = [System.Drawing.Font]::new('Segoe UI', 9.5)
$script:TabCtrl = $tabs
$tabs.Add_GotFocus({ try { $f = $this.FindForm(); if ($null -ne $f) { $f.ActiveControl = $null } } catch { } })
$tabs.Add_DrawItem({
    param($sender, $e)
    try {
        $t = Get-ThemeColors $script:Settings.Theme
        $idx = $e.Index
        if ($idx -lt 0 -or $idx -ge $sender.TabPages.Count) { return }
        $rect = $sender.GetTabRect($idx)
        $isSel = (($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0)

        $bg = if ($isSel) { $t.TabSelBg } else { $t.TabUnselBg }
        $brush = [System.Drawing.SolidBrush]::new($bg)
        $e.Graphics.FillRectangle($brush, $rect)
        $brush.Dispose()

        if (-not $isSel) {
            $pen = [System.Drawing.Pen]::new($t.ButtonBorder, 1)
            $e.Graphics.DrawRectangle($pen, $rect.X, $rect.Y, $rect.Width - 1, $rect.Height - 1)
            $pen.Dispose()
        } else {
            $pen = [System.Drawing.Pen]::new($t.TabSelLine, 2)
            $e.Graphics.DrawLine($pen, $rect.Left, ($rect.Bottom - 1), $rect.Right, ($rect.Bottom - 1))
            $pen.Dispose()
        }

        $label = $sender.TabPages[$idx].Text
        $flags = [System.Windows.Forms.TextFormatFlags]::HorizontalCenter `
               -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter `
               -bor [System.Windows.Forms.TextFormatFlags]::SingleLine `
               -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
        [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $label, $sender.Font, $rect, $t.TabText, $flags)
    } catch { }
})
$tabs.Add_SelectedIndexChanged({
    try {
        $idx = $tabs.SelectedIndex
        if ($idx -ge 0 -and $idx -lt $script:VisibleKeys.Count) {
            $script:ActiveMapKey = $script:VisibleKeys[$idx]
            if ($null -ne $script:HoverLabel) { $script:HoverLabel.Visible = $false }
            $tabs.Invalidate()
            Update-Status
            Update-ZoomSlider
            if ($script:ActiveMapKey -eq 'Propagation') { Refresh-Propagation }
            elseif ($script:ActiveMapKey -eq 'NOAA') { Refresh-NOAA }
            elseif ($script:ActiveMapKey -eq 'Log') { Refresh-LogView }
            if ($script:MapBoxes.ContainsKey($script:ActiveMapKey)) {
                $bk = $script:ActiveMapKey
                try { $script:MapBoxes[$bk].BeginInvoke([System.Action]{ try { Render-Map $bk } catch {} }) | Out-Null } catch {}
            }
            $form.ActiveControl = $null
        }
    } catch { }
})

foreach ($def in $script:TabDefs) {
    $tp = [System.Windows.Forms.TabPage]::new()
    $tp.Text = $def.Label
    $tp.BackColor = 'White'
    $script:TabPages[$def.Key] = $tp

    if ($def.Type -eq 'Map') {
        $box = [System.Windows.Forms.PictureBox]::new()
        $box.Dock = 'Fill'; $box.BackColor = [System.Drawing.Color]::FromArgb(214, 230, 244)
        $box.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Stretch
        $box.Cursor = [System.Windows.Forms.Cursors]::Cross; $box.Tag = $def.Key
        $tp.Controls.Add($box); $script:MapBoxes[$def.Key] = $box
        $box.Add_MouseDown({ param($s, $e); if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }; $mk = $s.Tag; $view = $script:MapViews[$mk]; $script:Drag.Active = $true; $script:Drag.Moved = $false; $script:Drag.StartX = $e.X; $script:Drag.StartY = $e.Y; $script:Drag.StartCenterLon = $view.CenterLon; $script:Drag.StartCenterLat = $view.CenterLat; $script:Drag.MapKey = $mk; if ($null -ne $script:HoverLabel) { $script:HoverLabel.Visible = $false } })
        $box.Add_MouseMove({ param($s, $e); try { if ($script:Drag.Active -and $script:Drag.MapKey -eq $s.Tag) { $dx = $e.X - $script:Drag.StartX; $dy = $e.Y - $script:Drag.StartY; if ([math]::Abs($dx) -gt 3 -or [math]::Abs($dy) -gt 3) { $script:Drag.Moved = $true }; if ($script:Drag.Moved) { $view = $script:MapViews[$s.Tag]; $ppd = $view.PPD; $view.CenterLon = $script:Drag.StartCenterLon - $dx / $ppd; $view.CenterLat = $script:Drag.StartCenterLat + $dy / $ppd; Clamp-View $s.Tag; Render-Map $s.Tag; if ($null -ne $script:HoverLabel) { $script:HoverLabel.Visible = $false } }; return }; if ($script:Drag.Active) { return }; $mk = $s.Tag; $view = $script:MapViews[$mk]; $ppd = $view.PPD; $lonMin = $view.CenterLon - ($s.Width / 2.0) / $ppd; $latMax = $view.CenterLat + ($s.Height / 2.0) / $ppd; $lon = $lonMin + $e.X / $ppd; $lat = $latMax - $e.Y / $ppd; $subPx = (2.0/24.0) * $ppd; $level = 4; if ($subPx -ge 28) { $level = 6 }; $loc = Get-LocatorAtLevel -Lon $lon -Lat $lat -Level $level; $info = Get-HoverInfoForLocator -Loc $loc; if ($info) { $script:HoverLabel.Text = $info; $pt = $s.PointToScreen([System.Drawing.Point]::new($e.X + 18, $e.Y + 18)); $pt = $form.PointToClient($pt); $maxX = $form.ClientSize.Width - $script:HoverLabel.Width - 4; $maxY = $form.ClientSize.Height - $script:HoverLabel.Height - 4; if ($pt.X -gt $maxX) { $pt.X = [math]::Max(4, $maxX) }; if ($pt.Y -gt $maxY) { $pt.Y = [math]::Max(4, $maxY) }; $script:HoverLabel.Location = $pt; $script:HoverLabel.Visible = $true; $script:HoverLabel.BringToFront() } else { $script:HoverLabel.Visible = $false } } catch { } })
        $box.Add_MouseLeave({ if ($null -ne $script:HoverLabel) { $script:HoverLabel.Visible = $false } })
        $box.Add_MouseUp({ param($s, $e); try { $mk = $s.Tag; if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { if (-not $script:Drag.Active) { return }; $wasDrag = $script:Drag.Moved; if ($script:Drag.MapKey -eq $mk -and -not $wasDrag) { $script:Drag.Active = $false; $script:Drag.Moved = $false; Add-CellAt -MapKey $mk -PixelX $e.X -PixelY $e.Y }; $script:Drag.Active = $false; $script:Drag.Moved = $false } elseif ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) { if ($script:Drag.Active) { $script:Drag.Active = $false; $script:Drag.Moved = $false }; Remove-CellAt -MapKey $mk -PixelX $e.X -PixelY $e.Y } } catch { } })
        $box.Add_ClientSizeChanged({ param($s, $e); try { $script:RenderTimer.Stop(); $script:RenderTimer.Start() } catch { } })
        $box.Add_Resize({ param($s, $e); try { $mk = $s.Tag; $s.BeginInvoke([System.Action]{ try { if ($s.Width -ge 50 -and $s.Height -ge 50) { Render-Map $mk } } catch { } }) | Out-Null } catch { } })
    }
    elseif ($def.Type -eq 'Log') {
        $logTop = [System.Windows.Forms.Panel]::new(); $logTop.Dock = 'Top'; $logTop.Height = 90; $tp.Controls.Add($logTop)
        $script:DistHeader = [System.Windows.Forms.Label]::new(); $script:DistHeader.Dock = 'Top'; $script:DistHeader.Height = 34
        $script:DistHeader.Font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $script:DistHeader.TextAlign = 'MiddleLeft'
        $script:DistHeader.Text = 'Log: Upload an ADIF file to populate.'
        $logTop.Controls.Add($script:DistHeader)

        $lblLB = [System.Windows.Forms.Label]::new(); $lblLB.Text = 'Band:'; $lblLB.Location = [System.Drawing.Point]::new(10, 50); $lblLB.Size = [System.Drawing.Size]::new(40, 20); $logTop.Controls.Add($lblLB)
        $script:LogBandCombo = [System.Windows.Forms.ComboBox]::new()
        $script:LogBandCombo.Location = [System.Drawing.Point]::new(55, 47); $script:LogBandCombo.Size = [System.Drawing.Size]::new(85, 22)
        $script:LogBandCombo.DropDownStyle = 'DropDownList'
        foreach ($b in $script:BandList) { $script:LogBandCombo.Items.Add($b) | Out-Null }
        $idx = $script:LogBandCombo.Items.IndexOf($script:Settings.LogFilterBand)
        $script:LogBandCombo.SelectedIndex = if ($idx -ge 0) { $idx } else { 0 }
        $logTop.Controls.Add($script:LogBandCombo)

        $lblLM = [System.Windows.Forms.Label]::new(); $lblLM.Text = 'Mode:'; $lblLM.Location = [System.Drawing.Point]::new(150, 50); $lblLM.Size = [System.Drawing.Size]::new(45, 20); $logTop.Controls.Add($lblLM)
        $script:LogModeCombo = [System.Windows.Forms.ComboBox]::new()
        $script:LogModeCombo.Location = [System.Drawing.Point]::new(195, 47); $script:LogModeCombo.Size = [System.Drawing.Size]::new(85, 22)
        $script:LogModeCombo.DropDownStyle = 'DropDownList'
        foreach ($m in $script:ModeList) { $script:LogModeCombo.Items.Add($m) | Out-Null }
        $idx = $script:LogModeCombo.Items.IndexOf($script:Settings.LogFilterMode)
        $script:LogModeCombo.SelectedIndex = if ($idx -ge 0) { $idx } else { 0 }
        $logTop.Controls.Add($script:LogModeCombo)

        $lblLS = [System.Windows.Forms.Label]::new(); $lblLS.Text = 'Show:'; $lblLS.Location = [System.Drawing.Point]::new(295, 50); $lblLS.Size = [System.Drawing.Size]::new(45, 20); $logTop.Controls.Add($lblLS)
        $script:DistCombo = [System.Windows.Forms.ComboBox]::new()
        $script:DistCombo.Location = [System.Drawing.Point]::new(340, 47); $script:DistCombo.Size = [System.Drawing.Size]::new(180, 22)
        $script:DistCombo.DropDownStyle = 'DropDownList'
        foreach ($opt in @('All (longest first)','All (shortest first)','Top 10 longest','Top 10 shortest','Most recent first')) { $script:DistCombo.Items.Add($opt) | Out-Null }
        $script:DistCombo.SelectedIndex = 0
        $logTop.Controls.Add($script:DistCombo)

        $btnLogRefresh = [System.Windows.Forms.Button]::new(); $btnLogRefresh.Text = 'Refresh'; $btnLogRefresh.Location = [System.Drawing.Point]::new(530, 46); $btnLogRefresh.Size = [System.Drawing.Size]::new(80, 26)
        $logTop.Controls.Add($btnLogRefresh)

        $lblLogNote = [System.Windows.Forms.Label]::new()
        $lblLogNote.Text = 'Upload an ADIF file to populate. Filters apply to this view only.'
        $lblLogNote.Location = [System.Drawing.Point]::new(620, 51); $lblLogNote.Size = [System.Drawing.Size]::new(490, 18)
        $lblLogNote.ForeColor = [System.Drawing.Color]::Gray; $lblLogNote.Font = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Italic); $logTop.Controls.Add($lblLogNote)

        $script:DistGrid = [System.Windows.Forms.DataGridView]::new()
        $script:DistGrid.Dock = 'Fill'; $script:DistGrid.ReadOnly = $true
        $script:DistGrid.AllowUserToAddRows = $false; $script:DistGrid.AllowUserToDeleteRows = $false; $script:DistGrid.AllowUserToResizeRows = $false
        $script:DistGrid.RowHeadersVisible = $false; $script:DistGrid.MultiSelect = $false; $script:DistGrid.SelectionMode = 'FullRowSelect'
        $script:DistGrid.AutoSizeColumnsMode = 'Fill'
        $script:DistGrid.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $script:DistGrid.Font = [System.Drawing.Font]::new('Consolas', 9)
        $script:DistGrid.Columns.Add('Date','Date') | Out-Null
        $script:DistGrid.Columns.Add('Time','Time') | Out-Null
        $script:DistGrid.Columns.Add('Call','Call') | Out-Null
        $script:DistGrid.Columns.Add('Band','Band') | Out-Null
        $script:DistGrid.Columns.Add('Mode','Mode') | Out-Null
        $script:DistGrid.Columns.Add('Grid','Grid') | Out-Null
        $script:DistGrid.Columns.Add('Dist','Distance') | Out-Null
        $tp.Controls.Add($script:DistGrid); $script:DistGrid.BringToFront()

        $script:LogBandCombo.Add_SelectedIndexChanged({
            $script:Settings.LogFilterBand = [string]$script:LogBandCombo.SelectedItem
            Save-Settings
            Refresh-LogView
        })
        $script:LogModeCombo.Add_SelectedIndexChanged({
            $script:Settings.LogFilterMode = [string]$script:LogModeCombo.SelectedItem
            Save-Settings
            Refresh-LogView
        })
        $script:DistCombo.Add_SelectedIndexChanged({ Refresh-LogView })
        $btnLogRefresh.Add_Click({ Refresh-LogView })
        Set-FlatButton $btnLogRefresh
    }
    elseif ($def.Type -eq 'Propagation') {
        $propTop = [System.Windows.Forms.Panel]::new(); $propTop.Dock = 'Top'; $propTop.Height = 80; $tp.Controls.Add($propTop)
        $script:PropHeader = [System.Windows.Forms.Label]::new(); $script:PropHeader.Dock = 'Top'; $script:PropHeader.Height = 34
        $script:PropHeader.Font = [System.Drawing.Font]::new('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
        $script:PropHeader.TextAlign = 'MiddleLeft'; $script:PropHeader.Text = 'Loading...'
        $propTop.Controls.Add($script:PropHeader)
        $script:PropStatus = [System.Windows.Forms.Label]::new(); $script:PropStatus.Dock = 'Top'; $script:PropStatus.Height = 22
        $script:PropStatus.Font = [System.Drawing.Font]::new('Segoe UI', 9)
        $script:PropStatus.Text = 'Ready.'
        $propTop.Controls.Add($script:PropStatus)
        $btnRefreshProp = [System.Windows.Forms.Button]::new(); $btnRefreshProp.Text = 'Refresh'
        $btnRefreshProp.Location = [System.Drawing.Point]::new(10, 52); $btnRefreshProp.Size = [System.Drawing.Size]::new(90, 26)
        $propTop.Controls.Add($btnRefreshProp)
        $lblPropNote = [System.Windows.Forms.Label]::new(); $lblPropNote.Text = 'HF data: hamqsl.com (N0NBH).  6m / 4m / 2m / 70cm: general seasonal notes.'
        $lblPropNote.Location = [System.Drawing.Point]::new(110, 57); $lblPropNote.Size = [System.Drawing.Size]::new(600, 18)
        $lblPropNote.ForeColor = [System.Drawing.Color]::Gray; $propTop.Controls.Add($lblPropNote)
        $propGrid = [System.Windows.Forms.DataGridView]::new(); $propGrid.Dock = 'Fill'; $propGrid.ReadOnly = $true
        $propGrid.AllowUserToAddRows = $false; $propGrid.AllowUserToDeleteRows = $false; $propGrid.AllowUserToResizeRows = $false
        $propGrid.RowHeadersVisible = $false; $propGrid.MultiSelect = $false; $propGrid.SelectionMode = 'FullRowSelect'
        $propGrid.AutoSizeColumnsMode = 'Fill'
        $propGrid.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $propGrid.Font = [System.Drawing.Font]::new('Segoe UI', 10)
        $propGrid.Columns.Add('Band','Band') | Out-Null; $propGrid.Columns.Add('Day','Day') | Out-Null; $propGrid.Columns.Add('Night','Night') | Out-Null
        $tp.Controls.Add($propGrid); $propGrid.BringToFront(); $script:PropGrid = $propGrid
        $btnRefreshProp.Add_Click({ Refresh-Propagation })
        Set-FlatButton $btnRefreshProp
    }
    elseif ($def.Type -eq 'NOAA') {
        $noaaTop = [System.Windows.Forms.Panel]::new(); $noaaTop.Dock = 'Top'; $noaaTop.Height = 100; $tp.Controls.Add($noaaTop)
        $script:NoaaHeader = [System.Windows.Forms.Label]::new(); $script:NoaaHeader.Dock = 'Top'; $script:NoaaHeader.Height = 34
        $script:NoaaHeader.Font = [System.Drawing.Font]::new('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
        $script:NoaaHeader.TextAlign = 'MiddleLeft'
        $script:NoaaHeader.Text = 'NOAA SWPC - Solar and Geomagnetic data'
        $noaaTop.Controls.Add($script:NoaaHeader)
        $script:NoaaStatus = [System.Windows.Forms.Label]::new(); $script:NoaaStatus.Dock = 'Top'; $script:NoaaStatus.Height = 22
        $script:NoaaStatus.Font = [System.Drawing.Font]::new('Segoe UI', 9)
        $script:NoaaStatus.Text = 'Click Refresh to load.'
        $noaaTop.Controls.Add($script:NoaaStatus)
        $btnRefreshNoaa = [System.Windows.Forms.Button]::new(); $btnRefreshNoaa.Text = 'Refresh'
        $btnRefreshNoaa.Location = [System.Drawing.Point]::new(10, 58); $btnRefreshNoaa.Size = [System.Drawing.Size]::new(90, 26)
        $noaaTop.Controls.Add($btnRefreshNoaa)
        $lblNoaaNote = [System.Windows.Forms.Label]::new()
        $lblNoaaNote.Text = 'Source: NOAA Space Weather Prediction Center.  Double-click a row to read the full alert text.'
        $lblNoaaNote.Location = [System.Drawing.Point]::new(110, 62); $lblNoaaNote.Size = [System.Drawing.Size]::new(650, 18)
        $lblNoaaNote.ForeColor = [System.Drawing.Color]::Gray; $noaaTop.Controls.Add($lblNoaaNote)
        $noaaGrid = [System.Windows.Forms.DataGridView]::new(); $noaaGrid.Dock = 'Fill'; $noaaGrid.ReadOnly = $true
        $noaaGrid.AllowUserToAddRows = $false; $noaaGrid.AllowUserToDeleteRows = $false; $noaaGrid.AllowUserToResizeRows = $false
        $noaaGrid.RowHeadersVisible = $false; $noaaGrid.MultiSelect = $false; $noaaGrid.SelectionMode = 'FullRowSelect'
        $noaaGrid.AutoSizeColumnsMode = 'Fill'
        $noaaGrid.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $noaaGrid.Font = [System.Drawing.Font]::new('Segoe UI', 9)
        $noaaGrid.Columns.Add('Time','Issued') | Out-Null
        $noaaGrid.Columns.Add('Summary','Alert (double-click to open)') | Out-Null
        $noaaGrid.Columns[0].Width = 200
        $tp.Controls.Add($noaaGrid); $noaaGrid.BringToFront(); $script:NoaaGrid = $noaaGrid
        $btnRefreshNoaa.Add_Click({ Refresh-NOAA })
        $noaaGrid.Add_CellDoubleClick({
            param($sender, $e)
            try {
                if ($e.RowIndex -lt 0) { return }
                $row = $sender.Rows[$e.RowIndex]
                $msg = $row.Tag
                if (-not $msg) { $msg = [string]$row.Cells[1].Value }
                [System.Windows.Forms.MessageBox]::Show($msg, 'NOAA Alert', 'OK', 'Information') | Out-Null
            } catch { }
        })
        Set-FlatButton $btnRefreshNoaa
    }
    elseif ($def.Type -eq 'DXCluster') {
        $dxTop = [System.Windows.Forms.Panel]::new(); $dxTop.Dock = 'Top'; $dxTop.Height = 130; $tp.Controls.Add($dxTop)
        $lblDxHost = [System.Windows.Forms.Label]::new(); $lblDxHost.Text = 'Cluster host:'; $lblDxHost.Location = [System.Drawing.Point]::new(10, 12); $lblDxHost.Size = [System.Drawing.Size]::new(85, 20); $dxTop.Controls.Add($lblDxHost)
        $script:DxHostBox = [System.Windows.Forms.ComboBox]::new()
        $script:DxHostBox.Location = [System.Drawing.Point]::new(100, 9); $script:DxHostBox.Size = [System.Drawing.Size]::new(220, 22)
        $script:DxHostBox.DropDownStyle = 'DropDown'
        foreach ($pres in $script:DxPresets) { $script:DxHostBox.Items.Add($pres.Host) | Out-Null }
        $script:DxHostBox.Text = $script:Settings.DxHost
        $dxTop.Controls.Add($script:DxHostBox)
        $script:DxHostBox.Add_SelectedIndexChanged({
            try {
                $h = [string]$script:DxHostBox.SelectedItem
                foreach ($pres in $script:DxPresets) {
                    if ($pres.Host -eq $h) { $script:DxPortBox.Text = $pres.Port; break }
                }
            } catch { }
        })
        $lblDxPort = [System.Windows.Forms.Label]::new(); $lblDxPort.Text = 'Port:'; $lblDxPort.Location = [System.Drawing.Point]::new(330, 12); $lblDxPort.Size = [System.Drawing.Size]::new(35, 20); $dxTop.Controls.Add($lblDxPort)
        $script:DxPortBox = [System.Windows.Forms.TextBox]::new(); $script:DxPortBox.Location = [System.Drawing.Point]::new(365, 9); $script:DxPortBox.Size = [System.Drawing.Size]::new(60, 22); $script:DxPortBox.Text = $script:Settings.DxPort; $dxTop.Controls.Add($script:DxPortBox)
        $btnDxConnect = [System.Windows.Forms.Button]::new(); $btnDxConnect.Text = 'Connect'; $btnDxConnect.Location = [System.Drawing.Point]::new(435, 8); $btnDxConnect.Size = [System.Drawing.Size]::new(80, 26); $dxTop.Controls.Add($btnDxConnect)
        $btnDxTest = [System.Windows.Forms.Button]::new(); $btnDxTest.Text = 'Test'; $btnDxTest.Location = [System.Drawing.Point]::new(520, 8); $btnDxTest.Size = [System.Drawing.Size]::new(60, 26); $dxTop.Controls.Add($btnDxTest)
        $btnDxTestAll = [System.Windows.Forms.Button]::new(); $btnDxTestAll.Text = 'Test All'; $btnDxTestAll.Location = [System.Drawing.Point]::new(585, 8); $btnDxTestAll.Size = [System.Drawing.Size]::new(75, 26); $dxTop.Controls.Add($btnDxTestAll)
        $btnDxDisconnect = [System.Windows.Forms.Button]::new(); $btnDxDisconnect.Text = 'Disconnect'; $btnDxDisconnect.Location = [System.Drawing.Point]::new(665, 8); $btnDxDisconnect.Size = [System.Drawing.Size]::new(90, 26); $dxTop.Controls.Add($btnDxDisconnect)
        $btnDxClear = [System.Windows.Forms.Button]::new(); $btnDxClear.Text = 'Clear'; $btnDxClear.Location = [System.Drawing.Point]::new(760, 8); $btnDxClear.Size = [System.Drawing.Size]::new(60, 26); $dxTop.Controls.Add($btnDxClear)
        $lblDxFB = [System.Windows.Forms.Label]::new(); $lblDxFB.Text = 'Band:'; $lblDxFB.Location = [System.Drawing.Point]::new(10, 44); $lblDxFB.Size = [System.Drawing.Size]::new(40, 20); $dxTop.Controls.Add($lblDxFB)
        $script:DxBandCombo = [System.Windows.Forms.ComboBox]::new()
        $script:DxBandCombo.Location = [System.Drawing.Point]::new(55, 41); $script:DxBandCombo.Size = [System.Drawing.Size]::new(90, 22)
        $script:DxBandCombo.DropDownStyle = 'DropDownList'
        foreach ($b in $script:DxBandList) { $script:DxBandCombo.Items.Add($b) | Out-Null }
        $idx = $script:DxBandCombo.Items.IndexOf($script:Settings.DxFilterBand)
        $script:DxBandCombo.SelectedIndex = if ($idx -ge 0) { $idx } else { 0 }
        $dxTop.Controls.Add($script:DxBandCombo)
        $lblDxFM = [System.Windows.Forms.Label]::new(); $lblDxFM.Text = 'Mode:'; $lblDxFM.Location = [System.Drawing.Point]::new(155, 44); $lblDxFM.Size = [System.Drawing.Size]::new(45, 20); $dxTop.Controls.Add($lblDxFM)
        $script:DxModeCombo = [System.Windows.Forms.ComboBox]::new()
        $script:DxModeCombo.Location = [System.Drawing.Point]::new(200, 41); $script:DxModeCombo.Size = [System.Drawing.Size]::new(90, 22)
        $script:DxModeCombo.DropDownStyle = 'DropDownList'
        foreach ($m in $script:DxModeList) { $script:DxModeCombo.Items.Add($m) | Out-Null }
        $idx = $script:DxModeCombo.Items.IndexOf($script:Settings.DxFilterMode)
        $script:DxModeCombo.SelectedIndex = if ($idx -ge 0) { $idx } else { 0 }
        $dxTop.Controls.Add($script:DxModeCombo)
        $lblDxFT = [System.Windows.Forms.Label]::new(); $lblDxFT.Text = 'Text:'; $lblDxFT.Location = [System.Drawing.Point]::new(300, 44); $lblDxFT.Size = [System.Drawing.Size]::new(40, 20); $dxTop.Controls.Add($lblDxFT)
        $script:DxTextFilter = [System.Windows.Forms.TextBox]::new()
        $script:DxTextFilter.Location = [System.Drawing.Point]::new(340, 41); $script:DxTextFilter.Size = [System.Drawing.Size]::new(180, 22)
        $script:DxTextFilter.Text = $script:Settings.DxFilterText
        $dxTop.Controls.Add($script:DxTextFilter)
        $btnDxApplyFilter = [System.Windows.Forms.Button]::new(); $btnDxApplyFilter.Text = 'Save filters'
        $btnDxApplyFilter.Location = [System.Drawing.Point]::new(530, 40); $btnDxApplyFilter.Size = [System.Drawing.Size]::new(90, 26)
        $dxTop.Controls.Add($btnDxApplyFilter)
        $lblDxFilterNote = [System.Windows.Forms.Label]::new()
        $lblDxFilterNote.Text = '(Filters apply to new spots as they arrive.)'
        $lblDxFilterNote.Location = [System.Drawing.Point]::new(625, 45); $lblDxFilterNote.Size = [System.Drawing.Size]::new(280, 18)
        $lblDxFilterNote.ForeColor = [System.Drawing.Color]::Gray; $lblDxFilterNote.Font = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)
        $dxTop.Controls.Add($lblDxFilterNote)
        $script:DxStatus = [System.Windows.Forms.Label]::new(); $script:DxStatus.Location = [System.Drawing.Point]::new(10, 72); $script:DxStatus.Size = [System.Drawing.Size]::new(1100, 20); $script:DxStatus.Font = [System.Drawing.Font]::new('Segoe UI', 9); $script:DxStatus.Text = 'Not connected. Pick a host and click Connect, or click Test All to check every host.'; $dxTop.Controls.Add($script:DxStatus)
        $lblDxNote = [System.Windows.Forms.Label]::new(); $lblDxNote.Text = 'Tip: Set your DX Cluster callsign in Settings. Click Test All to find which hosts work from your network.'
        $lblDxNote.Location = [System.Drawing.Point]::new(10, 94); $lblDxNote.Size = [System.Drawing.Size]::new(1100, 18); $lblDxNote.ForeColor = [System.Drawing.Color]::Gray; $lblDxNote.Font = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Italic); $dxTop.Controls.Add($lblDxNote)
        $script:DxList = [System.Windows.Forms.ListBox]::new()
        $script:DxList.Dock = 'Fill'; $script:DxList.Font = [System.Drawing.Font]::new('Consolas', 9)
        $script:DxList.HorizontalScrollbar = $true; $script:DxList.IntegralHeight = $false
        $tp.Controls.Add($script:DxList); $script:DxList.BringToFront()

        $btnDxTest.Add_Click({
            $h = $script:DxHostBox.Text.Trim(); $p = 8000
            try { $p = [int]$script:DxPortBox.Text.Trim() } catch { $p = 8000 }
            if (-not $h) { $script:DxStatus.Text = 'Please enter a cluster host first.'; return }
            $script:DxStatus.Text = "Testing ${h}:${p} ..."
            [System.Windows.Forms.Application]::DoEvents()
            $r = Test-DXConnection -HostName $h -Port $p
            if ($r.Ok) { $script:DxStatus.Text = "Test PASSED - ${h}:${p} is reachable. Click Connect to stream spots." }
            else { $script:DxStatus.Text = "Test FAILED - $($r.Msg)" }
        })

        $btnDxTestAll.Add_Click({
            try {
                $btnDxTestAll.Enabled = $false
                $script:DxList.Items.Clear()
                $script:DxStatus.Text = "Testing all $($script:DxPresets.Count) hosts, please wait ... (this may take a couple of minutes)"
                [System.Windows.Forms.Application]::DoEvents()
                $results = Test-AllDXHosts -ResultList $script:DxList
                $passed = @($results | Where-Object { $_.Ok })
                $failed = @($results | Where-Object { -not $_.Ok })
                $script:DxList.Items.Add('') | Out-Null
                $script:DxList.Items.Add("=== Summary: $($passed.Count) passed, $($failed.Count) failed ===") | Out-Null
                if ($passed.Count -gt 0) {
                    $script:DxList.Items.Add("Working hosts from your network:") | Out-Null
                    foreach ($p in $passed) { $script:DxList.Items.Add("  $($p.Host):$($p.Port)") | Out-Null }
                } else {
                    $script:DxList.Items.Add("None reachable - your ISP is likely blocking outbound telnet entirely.") | Out-Null
                }
                $script:DxList.TopIndex = $script:DxList.Items.Count - 1
                $script:DxStatus.Text = "Test complete. $($passed.Count) passed, $($failed.Count) failed. See the list above for working hosts."
            } catch {
                $script:DxStatus.Text = "Test All error: $_"
            } finally {
                $btnDxTestAll.Enabled = $true
            }
        })

        $btnDxConnect.Add_Click({
            $h = $script:DxHostBox.Text.Trim(); $p = 8000
            try { $p = [int]$script:DxPortBox.Text.Trim() } catch { $p = 8000 }
            if (-not $h) { $script:DxStatus.Text = 'Please enter a cluster host.'; return }
            $login = $script:Settings.DxCallsign
            if (-not $login) { $login = $script:Settings.Callsign }
            if (-not $login) { $login = 'guest' }
            $script:Settings.DxHost = $h; $script:Settings.DxPort = [string]$p
            Save-Settings
            $script:DxList.Items.Clear()
            $script:DxStatus.Text = "Testing ${h}:${p} before connecting ..."
            [System.Windows.Forms.Application]::DoEvents()
            $r = Test-DXConnection -HostName $h -Port $p
            if (-not $r.Ok) {
                $script:DxStatus.Text = "Cannot reach ${h}:${p} - $($r.Msg)"
                [System.Windows.Forms.MessageBox]::Show(
                    "Could not reach ${h}:${p}`n`n$($r.Msg)`n`nThings to try:`n" +
                    "  - Click Test All to find hosts that work from your network`n" +
                    "  - Try hrd.wa9pie.net on port 8000 (works on most UK ISPs)`n" +
                    "  - Try dxc.nc7j.com on port 7373`n" +
                    "  - Check your antivirus / Windows Firewall",
                    'DX Cluster - connection failed', 'OK', 'Warning') | Out-Null
                return
            }
            if (Start-DXCluster -HostName $h -Port $p -Login $login) {
                $script:DxStatus.Text = "Connecting to ${h}:${p} as $login ..."
            } else {
                $script:DxStatus.Text = "Failed to start worker."
            }
        })
        $btnDxDisconnect.Add_Click({ Stop-DXCluster; $script:DxStatus.Text = 'Disconnected.' })
        $btnDxClear.Add_Click({ try { $script:DxList.Items.Clear() } catch {} })
        $btnDxApplyFilter.Add_Click({
            $script:Settings.DxFilterBand = [string]$script:DxBandCombo.SelectedItem
            $script:Settings.DxFilterMode = [string]$script:DxModeCombo.SelectedItem
            $script:Settings.DxFilterText = $script:DxTextFilter.Text.Trim()
            Save-Settings
            $script:DxStatus.Text = "Filters saved. Band: $($script:Settings.DxFilterBand) | Mode: $($script:Settings.DxFilterMode) | Text: $($script:Settings.DxFilterText)"
        })
        Set-FlatButton $btnDxConnect; Set-FlatButton $btnDxTest; Set-FlatButton $btnDxTestAll; Set-FlatButton $btnDxDisconnect; Set-FlatButton $btnDxClear; Set-FlatButton $btnDxApplyFilter
    }
}

$form.Controls.Add($tabs)

$hover = [System.Windows.Forms.Label]::new(); $hover.AutoSize = $true
$hover.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 220)
$hover.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30); $hover.BorderStyle = 'FixedSingle'
$hover.Padding = [System.Windows.Forms.Padding]::new(6, 4, 6, 4); $hover.Font = [System.Drawing.Font]::new('Segoe UI', 9)
$hover.Visible = $false; $form.Controls.Add($hover); $hover.BringToFront(); $script:HoverLabel = $hover

$form.Add_MouseWheel({ param($s, $e); try { foreach ($key in $script:MapKeys) { $box = $script:MapBoxes[$key]; if ($null -eq $box -or -not $box.Visible) { continue }; $pt = $box.PointToClient([System.Windows.Forms.Cursor]::Position); if ($pt.X -ge 0 -and $pt.X -lt $box.Width -and $pt.Y -ge 0 -and $pt.Y -lt $box.Height) { Handle-Zoom -MapKey $key -PixelX $pt.X -PixelY $pt.Y -Delta $e.Delta; break } } } catch { } })

$cboMode.Add_SelectedIndexChanged({ Apply-Filters }); $cboBand.Add_SelectedIndexChanged({ Apply-Filters })

$zoomSlider.Add_Scroll({
    try {
        $mk = $script:ActiveMapKey
        if (-not $script:MapViews.ContainsKey($mk)) { return }
        $newPpd = [math]::Pow(10, $zoomSlider.Value / 20.0)
        if ($newPpd -lt 0.5) { $newPpd = 0.5 }; if ($newPpd -gt 50000) { $newPpd = 50000 }
        $script:MapViews[$mk].PPD = $newPpd
        Clamp-View $mk
        Render-Map $mk
        Update-Status
    } catch { }
})

function Do-Select { try { $raw = $txtSearch.Text.Trim().ToUpper(); if ($raw -notmatch '^[A-Z]{2}\d{2}([A-Z]{2})?$') { [System.Windows.Forms.MessageBox]::Show('Enter 4 or 6 chars, e.g. IO83 or IO83VA.', 'Invalid Locator'); return }; $mk = $script:ActiveMapKey; if (-not $script:MapViews.ContainsKey($mk)) { $mk = 'UK' }; $b = Get-BoundsFromLocator $raw.Substring(0,4); if ($null -eq $b) { return }; $view = $script:MapViews[$mk]; $view.CenterLon = ($b.LonMin + $b.LonMax) / 2; $view.CenterLat = ($b.LatMin + $b.LatMax) / 2; if ($raw.Length -ge 6) { $b6 = Get-BoundsFromLocator $raw; if ($null -ne $b6) { $view.CenterLon = ($b6.LonMin + $b6.LonMax) / 2; $view.CenterLat = ($b6.LatMin + $b6.LatMax) / 2 }; $view.PPD = 2000 } else { $view.PPD = 400 }; Clamp-View $mk; $script:CurrentBase = $raw.Substring(0,4); Render-AllMaps; Update-Status; Update-ZoomSlider } catch { } }
$btnGo.Add_Click({ Do-Select; $form.ActiveControl = $null })
$txtSearch.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { Do-Select; $_.SuppressKeyPress = $true } })

$btnReset.Add_Click({
    try {
        $ans = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to reset the grid?`n`nThis will clear all confirmed grid squares.`n`nA new ADIF file will need to be uploaded to repopulate.", 'Reset Grid', 'YesNo', 'Warning')
        if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $script:Manual4.Clear(); $script:Manual6.Clear(); $script:LogEntries.Clear()
        Apply-Filters
        Save-LogData
        $script:LblStatusCtrl.Text = 'Grid reset. Upload a new ADIF to repopulate.'
    } catch { }
})

$btnADIF.Add_Click({ try { $ofd = [System.Windows.Forms.OpenFileDialog]::new(); $ofd.Filter = 'ADIF files (*.adi;*.adif)|*.adi;*.adif|All files (*.*)|*.*'; $ofd.Title = 'Select ADIF file'; if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { try { $script:LblStatusCtrl.Text = 'Parsing ADIF...'; $form.Refresh(); $entries = Parse-ADIFText -text (Get-Content -Path $ofd.FileName -Raw); $script:LogEntries.Clear(); foreach ($e in $entries) { $script:LogEntries.Add($e) | Out-Null }; $existing = @{}; foreach ($item in $cboBand.Items) { $existing[[string]$item] = $true }; foreach ($e in $script:LogEntries) { if ($e.Band -and -not $existing.ContainsKey($e.Band)) { $cboBand.Items.Add($e.Band) | Out-Null; $existing[$e.Band] = $true } }; Apply-Filters; Save-LogData; $script:LblStatusCtrl.Text = "ADIF loaded and saved: $($script:LogEntries.Count) QSOs." } catch { [System.Windows.Forms.MessageBox]::Show("Error reading ADIF: $_", 'ADIF Error') } } } catch { } })

$btnSave.Add_Click({ try { $sfd = [System.Windows.Forms.SaveFileDialog]::new(); $sfd.Filter = 'Grid files (*.grid.json)|*.grid.json|JSON (*.json)|*.json|All files (*.*)|*.*'; $sfd.Title = 'Save confirmed grids'; $sfd.FileName = 'maidenhead-confirmed.json'; if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { if (Save-GridFile -Path $sfd.FileName) { $script:LblStatusCtrl.Text = "Saved to $($sfd.FileName)" } else { [System.Windows.Forms.MessageBox]::Show("Save failed.", 'Save Error') } } } catch { } })
$btnLoad.Add_Click({ try { $ofd = [System.Windows.Forms.OpenFileDialog]::new(); $ofd.Filter = 'Grid files (*.grid.json)|*.grid.json|JSON (*.json)|*.json|All files (*.*)|*.*'; $ofd.Title = 'Load confirmed grids'; if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { if (Load-GridFile -Path $ofd.FileName) { Apply-Filters; Save-LogData; $script:LblStatusCtrl.Text = "Loaded: $($script:LogEntries.Count) QSOs." } else { [System.Windows.Forms.MessageBox]::Show("Load failed.", 'Load Error') } } } catch { } })
$btnClear.Add_Click({ try { $script:Manual4.Clear(); $script:Manual6.Clear(); $script:LogEntries.Clear(); Apply-Filters; Save-LogData; $script:LblStatusCtrl.Text = 'All cleared.' } catch { } })

$miOpenSettings.Add_Click({ Show-SettingsForm })
$miChangeColour.Add_Click({ Show-ColourForm })
$miManual.Add_Click({ Show-ManualForm })
$miLoad.Add_Click({ $btnLoad.PerformClick() })
$miSave.Add_Click({ $btnSave.PerformClick() })
$miExit.Add_Click({ $form.Close() })

$miContact.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
        "Contact / Bug reports`n`n" +
        "If you find any bugs, or want to get in touch:`n`n" +
        "  TikTok:  dc.ham.adventure`n" +
        "  Discord: D&C Ham Adventure`n`n" +
        "Thank you for using Grid Square Worked!",
        'Contact Us')
})

$miAbout.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
        "Grid Square Worked`n`n" +
        "© D&C Ham Adventure (M7ANI) 2026`n`n" +
        "IMPORTANT: This is a hobby project made for fun.  Grid" + "`n" +
        "square data is not verified and some squares may be off." + "`n" +
        "Please do not rely on this for awards, contests or" + "`n" +
        "anything official.  Always check against your own log." + "`n`n" +
        "See Help -> Manual for full documentation.`n`n" +
        "Quick summary:`n" +
        "  - Upload an ADIF file to populate the maps.`n" +
        "  - Left-click a square to add it manually.`n" +
        "  - Right-click a square to remove it.`n" +
        "  - Mode/Band on the toolbar filter the maps only.`n" +
        "  - Log tab has its own filters.`n" +
        "  - Propagation, NOAA SWPC and DX Cluster tabs are live feeds.`n" +
        "  - QRZ lookup requires a paid QRZ XML Data subscription.`n" +
        "  - DX Cluster: use Test All to find working hosts.`n" +
        "  - Light / Dark theme in Settings.`n`n" +
        "Settings -> Visible tabs lets you choose what shows.",
        'About')
})

Set-FlatButton $btnGo; Set-FlatButton $btnADIF
Set-FlatButton $btnSave; Set-FlatButton $btnLoad; Set-FlatButton $btnClear
Set-FlatButton $btnReset

$script:RenderTimer = [System.Windows.Forms.Timer]::new(); $script:RenderTimer.Interval = 250
$script:RenderTimer.Add_Tick({
    try {
        $script:RenderTimer.Stop()
        foreach ($key in $script:MapKeys) {
            if (-not $script:MapBoxes.ContainsKey($key)) { continue }
            $b = $script:MapBoxes[$key]
            if ($null -eq $b -or -not $b.IsHandleCreated) { continue }
            if (-not $b.Visible) { continue }
            if ($b.Width -lt 50 -or $b.Height -lt 50) { continue }
            Render-Map $key
        }
    } catch { }
})
$form.Add_Resize({ try { $script:RenderTimer.Stop(); $script:RenderTimer.Start() } catch { } })
$form.Add_ResizeEnd({ try { $script:RenderTimer.Stop(); $script:RenderTimer.Start() } catch { } })
$form.Add_SizeChanged({ try { $script:RenderTimer.Stop(); $script:RenderTimer.Start() } catch { } })
$form.Add_ResizeBegin({ if ($null -ne $script:HoverLabel) { $script:HoverLabel.Visible = $false } })
$form.Add_WindowStateChanged({ try { $script:RenderTimer.Stop(); $script:RenderTimer.Start() } catch { } })

$script:ClockTimer = [System.Windows.Forms.Timer]::new(); $script:ClockTimer.Interval = 1000
$script:ClockTimer.Add_Tick({ Update-Clock })
$script:CleanTimer = [System.Windows.Forms.Timer]::new(); $script:CleanTimer.Interval = 3000
$script:CleanTimer.Add_Tick({ try { [WinCleaner]::CloseOurTooltips() } catch { } })

$script:DxTimer = [System.Windows.Forms.Timer]::new(); $script:DxTimer.Interval = 400
$script:DxTimer.Add_Tick({
    try {
        if ($null -eq $script:DxList) { return }
        if ($null -eq $script:DxQueue) { return }
        $bandF = 'All'; $modeF = 'All'; $textF = ''
        if ($null -ne $script:DxBandCombo -and $null -ne $script:DxBandCombo.SelectedItem) { $bandF = [string]$script:DxBandCombo.SelectedItem }
        if ($null -ne $script:DxModeCombo -and $null -ne $script:DxModeCombo.SelectedItem) { $modeF = [string]$script:DxModeCombo.SelectedItem }
        if ($null -ne $script:DxTextFilter) { $textF = $script:DxTextFilter.Text.Trim() }
        $line = $null
        $added = 0
        while ($script:DxQueue.TryDequeue([ref]$line)) {
            if (-not (Test-DxSpotMatches -Line $line -Band $bandF -Mode $modeF -Text $textF)) { continue }
            $script:DxList.Items.Add($line) | Out-Null
            $added++
            if ($script:DxList.Items.Count -gt 500) { $script:DxList.Items.RemoveAt(0) }
            if ($line -like '---*') { if ($null -ne $script:DxStatus) { $script:DxStatus.Text = $line.Trim('-').Trim() } }
            if ($line -like 'ERROR:*') { if ($null -ne $script:DxStatus) { $script:DxStatus.Text = $line } }
        }
        if ($added -gt 0 -and $script:DxList.Items.Count -gt 0) {
            try { $script:DxList.TopIndex = $script:DxList.Items.Count - 1 } catch {}
        }
    } catch { }
})

Load-Settings
if ($script:Settings.Grid) { $txtSearch.Text = $script:Settings.Grid }
$lblStatus.Text = 'Loading world map imagery (first run may take a moment)...'
$form.Refresh()
if (Initialize-WorldImage) { $lblStatus.Text = 'Ready.' }
else { $lblStatus.Text = 'Offline - using simplified coastlines.' }
$hadData = Load-LogData
Rebuild-Confirmed
Apply-TabVisibility
Apply-Theme $form

$script:StartupTimer = [System.Windows.Forms.Timer]::new(); $script:StartupTimer.Interval = 300
$script:StartupTimer.Add_Tick({ try { $script:StartupTimer.Stop(); Render-AllMaps; Update-Status; Update-Clock; Update-ZoomSlider; Update-Legend; Refresh-LogView } catch { } })

$form.Add_Shown({
    Update-Ribbon
    Render-AllMaps
    Update-Status
    Update-Clock
    Update-ZoomSlider
    Update-Legend
    Refresh-LogView
    $script:StartupTimer.Start()
    $script:ClockTimer.Start()
    $script:CleanTimer.Start()
    $script:DxTimer.Start()
    try { [WinCleaner]::CloseOurTooltips() } catch { }
    if ($hadData) { try { $script:LblStatusCtrl.Text = "Reloaded previous log: $($script:LogEntries.Count) QSOs." } catch {} }
})

[void]$form.ShowDialog()

try { if ($null -ne $script:ClockTimer) { $script:ClockTimer.Stop(); $script:ClockTimer.Dispose() } } catch { }
try { if ($null -ne $script:RenderTimer) { $script:RenderTimer.Stop(); $script:RenderTimer.Dispose() } } catch { }
try { if ($null -ne $script:StartupTimer) { $script:StartupTimer.Stop(); $script:StartupTimer.Dispose() } } catch { }
try { if ($null -ne $script:CleanTimer) { $script:CleanTimer.Stop(); $script:CleanTimer.Dispose() } } catch { }
try { if ($null -ne $script:DxTimer) { $script:DxTimer.Stop(); $script:DxTimer.Dispose() } } catch { }
try { Stop-DXCluster } catch { }

if ($null -ne $script:WorldImg) { $script:WorldImg.Dispose() }
foreach ($b in $script:MapBitmaps.Values) { $b.Dispose() }