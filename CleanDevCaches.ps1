Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# تابع برای گرفتن رمز عبور
# function Prompt-Password {
#     param([string]$message)
#     $securePassword = Read-Host -AsSecureString $message
#     return $securePassword
# }

$folderPassword = Join-Path $env:LOCALAPPDATA "CleanDevCaches"
$PasswordFile = Join-Path $folderPassword "Password.txt"
# مسیر پیش‌فرض بکاپ
$defaultBackupPath = Join-Path $env:LOCALAPPDATA "CleanDevCaches\Backups"

function Ask-Password($Title) {
    Add-Type -AssemblyName PresentationFramework
    $passwordBox = New-Object System.Windows.Controls.PasswordBox
    $passwordBox.Width = 200

    $button = New-Object System.Windows.Controls.Button
    $button.Content = "OK"
    $button.Width = 80
    $button.Margin = "5"

    $stackPanel = New-Object System.Windows.Controls.StackPanel
    $stackPanel.Orientation = "Vertical"
    $stackPanel.Margin = "15"
    $stackPanel.AddChild($passwordBox)
    $stackPanel.AddChild($button)

    $window = New-Object System.Windows.Window
    $window.Title = $Title
    $window.SizeToContent = "WidthAndHeight"
    $window.WindowStartupLocation = "CenterScreen"
    $window.Content = $stackPanel
    $window.ResizeMode = "NoResize"

    # رویدادها
    $passwordBox.Add_KeyDown({
            if ($_.Key -eq "Enter") { 
                $window.DialogResult = $true
                $window.Close() 
            }
        })

    $button.Add_Click({
            $window.DialogResult = $true
            $window.Close()
        })

    $result = $window.ShowDialog()
    if ($result -eq $true) {
        return $passwordBox.Password
    }

    return $null
}

function Get-Or-CreatePassword {
    if (!(Test-Path $folderPassword)) {
        New-Item -ItemType Directory -Path $folderPassword | Out-Null
    }

    if (!(Test-Path $PasswordFile)) {
        # اولین اجرا: ساخت رمز جدید (کاربر دو بار باید تایید کند)
        [System.Windows.Forms.MessageBox]::Show("This is your first run. Please choose and confirm a new password.", "Set password", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

        $p1 = Ask-Password "Enter new password"
        if ([string]::IsNullOrWhiteSpace($p1)) { throw "Password not set." }

        $p2 = Ask-Password "Confirm new password"
        if ($p1 -ne $p2) { [System.Windows.Forms.MessageBox]::Show("The passwords do not match. Try again."); throw "Password confirmation mismatch." }

        # نوشتن دقیق (بدون newline اضافی)
        [System.IO.File]::WriteAllText($PasswordFile, $p1, [System.Text.Encoding]::UTF8)
        # return $p1
        # پیام به کاربر
        [System.Windows.Forms.MessageBox]::Show(
            "Password created successfully. Please restart the application and log in with your new password.",
            "Password Set",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        # خروج از برنامه بعد از ایجاد رمز
        exit
    }

    # خواندن و Trim کردن (حذف newline یا space اضافی)
    # $saved = (Get-Content -Path $PasswordFile -Raw)
    $saved = [System.IO.File]::ReadAllText($PasswordFile, [System.Text.Encoding]::UTF8)
    if ($null -eq $saved) { return "" }
    return $saved.Trim()
}

function Check-Login {
    try {
        $saved = Get-Or-CreatePassword
        # اگر مقدار null یا غیر رشته‌ای بود، یک رشته خالی بذار
        if (-not [string]::IsNullOrEmpty($saved)) {
            $saved = [string]$saved
        }
        else {
            $saved = ""
        }

        $input = Ask-Password "Enter password"
        if ($input -eq $null -or $input -eq "") { 
            [System.Windows.Forms.MessageBox]::Show("No password entered. Exiting.", "Login Failed") | Out-Null
            return $false
        }

        # Trim هر دو طرف برای ایمنی (کاربر ممکنه اشتباها space زده باشه)
        if ($input.Trim() -eq $saved.Trim()) {
            return $true
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("The password is wrong. Exiting.", "Login failed") | Out-Null
            return $false
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error setting/reading password: $_ .Exiting.", "Error") | Out-Null
        return $false
    }
}



function Change-Password {
    if (!(Test-Path $PasswordFile)) {
        [System.Windows.Forms.MessageBox]::Show("No password has been set yet.", "Change password", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    # خواندن رمز ذخیره‌شده
    # $saved = (Get-Content -Path $PasswordFile -Raw)
    $saved = Get-Or-CreatePassword

    # ابتدا رمز فعلی را بپرس
    $cur = Ask-Password "Enter current password"
    if ($cur -eq $null) { return } 
    if ($cur.Trim() -ne $saved.Trim()) {
        [System.Windows.Forms.MessageBox]::Show("The current password is incorrect.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # حالا رمز جدید را بپرس و دوباره تایید کن
    $new1 = Ask-Password "Enter new password"
    if ($new1 -eq $null -or [string]::IsNullOrWhiteSpace($new1)) {
        [System.Windows.Forms.MessageBox]::Show("The new password is invalid.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    $new2 = Ask-Password "Confirm new password"
    if ($new1 -ne $new2) {
        [System.Windows.Forms.MessageBox]::Show("The passwords do not match.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    # نوشتن رمز جدید (بدون newline اضافی)
    try {
        [System.IO.File]::WriteAllText($PasswordFile, $new1)
        [System.Windows.Forms.MessageBox]::Show("Password changed successfully.", "OK", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error saving password: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# رمز عبور صحیح که به صورت SecureString ذخیره می‌شود
# $correctPassword = ConvertTo-SecureString "2541366" -AsPlainText -Force
# درخواست رمز عبور از کاربر
# $userPassword = Prompt-Password "Enter the password to start cleanup process:"

# تبدیل SecureString به رشته عادی برای مقایسه
# $securePassword = [System.Net.NetworkCredential]::new("", $userPassword).Password

# مقایسه رشته‌های رمز عبور
# if ($securePassword -ne "2541366") {
#     [System.Windows.Forms.MessageBox]::Show("Incorrect password. Exiting.", "Access Denied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
#     exit
# }

if (-not (Check-Login)) {
    # [System.Windows.Forms.MessageBox]::Show("Incorrect password. Exiting.", "Access Denied") | Out-Null
    exit
}


# در صورتی که رمز عبور صحیح باشد، ادامه کار
# [System.Windows.Forms.MessageBox]::Show("Password correct. Starting cleanup...", "Access Granted", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

# ... ادامه اسکریپت

# -----------------------
# Utility functions
# -----------------------

function Get-FolderSizeMB {
    param($path)
    try {
        if (-not (Test-Path $path)) { return 0 }
        
        # فقط فایل‌ها رو بگیر و اندازه‌شون رو جمع بزن
        $files = Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue
        if ($files.Count -eq 0) { return 0 }
        
        $sum = ($files | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { return 0 }
        return [math]::Round($sum / 1MB, 2)
    }
    catch {
        return 0
    }
}

function Get-CustomPaths {
    $folder = Join-Path $env:LOCALAPPDATA "CleanDevCaches"
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    return Join-Path $folder "customPaths.json"
}

function Get-Settings {
    $folder = Join-Path $env:LOCALAPPDATA "CleanDevCaches"
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    return Join-Path $folder "settings.json"
}

function Save-CustomPaths {
    param([string[]]$customPaths)

    $jsonPath = Get-CustomPaths
    $data = @{ Paths = $customPaths }
    $json = $data | ConvertTo-Json -Depth 5
    Set-Content -Path $jsonPath -Value $json -Encoding UTF8
}

function Save-Settings {
    param([hashtable]$settings)
    $settingsPath = Get-Settings
    $json = $settings | ConvertTo-Json -Depth 5
    Set-Content -Path $settingsPath -Value $json -Encoding UTF8
}

function Load-CustomPaths {
    $jsonPath = Get-CustomPaths

    if (Test-Path $jsonPath) {
        try {
            $data = Get-Content $jsonPath | ConvertFrom-Json
            return $data.Paths
        }
        catch {
            return @()
        }
    }
    return @()
}

function Load-Settings {
    $settingsPath = Get-Settings
    if (Test-Path $settingsPath) {
        try {
            $json = Get-Content $settingsPath -Raw
            $settings = $json | ConvertFrom-Json
            
            # تبدیل PSCustomObject به Hashtable
            $hashtable = @{}
            $settings.PSObject.Properties | ForEach-Object {
                $hashtable[$_.Name] = $_.Value
            }
            
            return $hashtable
        }
        catch {
            Write-Host "Error loading settings: $_"
            return @{}
        }
    }
    # Write-Host "Settings file not found: $settingsPath"
    return @{}
}

# کمک‌تابع برای تبدیل مقدار سلول به عدد (خالی => 0)
# function Convert-ToDoubleSafe {
#     param($v)
#     if ($null -eq $v -or $v -eq "" ) { return 0.0 }
#     try { return [double]::Parse($v) } catch { return 0.0 }
# }

function Convert-ToDoubleSafe {
    param($v)

    # مقدار خالی => 0
    if ($null -eq $v -or $v -eq "") { return 0.0 }

    # اگر از قبل عدد است، مستقیم برگردان
    if ($v -is [double] -or $v -is [int] -or $v -is [decimal]) {
        return [double]$v
    }

    # متن ورودی و حذف کاراکترهای غیر ضروری (به جز ارقام و '.' و ',' و '-')
    $s = $v.ToString().Trim()
    $s = $s -replace "[^\d\.,\-]", ""

    if ($s -eq "") { return 0.0 }

    $parsed = 0.0
    $numStyle = [System.Globalization.NumberStyles]::Number
    $cultureInv = [System.Globalization.CultureInfo]::InvariantCulture
    $cultureCur = [System.Globalization.CultureInfo]::CurrentCulture

    # 1) تلاش با Invariant (نقطه به عنوان اعشاری)
    if ([double]::TryParse($s, $numStyle, $cultureInv, [ref]$parsed)) { return $parsed }

    # 2) تلاش با CurrentCulture (ممکنه کاما اعشاری باشه)
    if ([double]::TryParse($s, $numStyle, $cultureCur, [ref]$parsed)) { return $parsed }

    # 3) اگر هم ',' و هم '.' وجود دارد، حدس بزنیم کدوم اعشاری است:
    if ($s -match "[\.,]" ) {
        # حالت A: فرض کن ',' اعشاری و '.' هزارگان -> remove dots, replace comma->dot
        $t = $s -replace "\.", "" -replace ",", "."
        if ([double]::TryParse($t, $numStyle, $cultureInv, [ref]$parsed)) { return $parsed }

        # حالت B: فرض کن '.' اعشاری و ',' هزارگان -> remove commas
        $t2 = $s -replace ",", ""
        if ([double]::TryParse($t2, $numStyle, $cultureInv, [ref]$parsed)) { return $parsed }
    }

    # 4) اگر فقط '.' هست ولی سیستم کاما می‌خواهد، سعی کن کاما بذاری
    if ($s -match "\.") {
        $t = $s -replace ",", ""
        if ([double]::TryParse($t, $numStyle, $cultureInv, [ref]$parsed)) { return $parsed }
    }

    # 5) اگر فقط ',' هست ولی سیستم نقطه می‌خواهد، تبدیل کن
    if ($s -match ",") {
        $t = $s -replace "\.", "" -replace ",", "."
        if ([double]::TryParse($t, $numStyle, $cultureInv, [ref]$parsed)) { return $parsed }
    }

    return 0.0
}


function Confirm-Action {
    param($message)
    $res = [System.Windows.Forms.MessageBox]::Show($message, "Operation confirmation", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    return $res -eq [System.Windows.Forms.DialogResult]::Yes
}

# -----------------------
# helper for Recycle Bin size parsing
# -----------------------
function Convert-SizeStringToMB {
    param([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return 0.0 }
    $s = $s.Trim()
    $s = $s -replace ',', '.'
    if ($s -match '^([\d\.]+)\s*KB$') {
        return ([double]$matches[1]) / 1024
    }
    elseif ($s -match '^([\d\.]+)\s*MB$') {
        return [double]$matches[1]
    }
    elseif ($s -match '^([\d\.]+)\s*GB$') {
        return [double]$matches[1] * 1024
    }
    elseif ($s -match '^([\d\.,]+)$') {
        $num = $s -replace '[^\d\.]', ''
        return [math]::Round([double]$num / 1MB, 2)
    }
    else {
        return 0.0
    }
}

function Get-RecycleBinSizeMB {
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycle = $shell.Namespace(0xA)
        if ($null -eq $recycle) { return 0.0 }
        $items = $recycle.Items()
        if ($items.Count -eq 0) { return 0.0 }

        $sizeCol = $null
        for ($col = 0; $col -lt 60; $col++) {
            $hdr = $recycle.GetDetailsOf($null, $col)
            if ($hdr -and $hdr -match 'Size') {
                $sizeCol = $col
                break
            }
        }
        if ($sizeCol -eq $null) { $sizeCol = 2 }

        $totalMB = 0.0
        for ($i = 0; $i -lt $items.Count; $i++) {
            $it = $items.Item($i)
            $val = $recycle.GetDetailsOf($it, $sizeCol)
            $mb = Convert-SizeStringToMB $val
            $totalMB += $mb
        }
        return [math]::Round($totalMB, 2)
    }
    catch {
        return 0.0
    }
}

function Get-UniquePhysicalPaths {
    param([string[]]$paths)
    
    $physicalPaths = @()
    
    foreach ($path in $paths) {
        if ($path -eq "Recycle Bin") {
            $physicalPaths += $path
            continue
        }
        
        try {
            # اگر مسیر شامل wildcard هست
            if ($path -match '[\*\?\[\]]') {
                $foundPaths = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
                if ($foundPaths) {
                    $physicalPaths += $foundPaths
                }
            }
            else {
                # فقط اگر مسیر وجود داره پردازش کن
                if (Test-Path $path -ErrorAction SilentlyContinue) {
                    # گرفتن مسیر فیزیکی واقعی
                    $item = Get-Item $path -ErrorAction SilentlyContinue
                    if ($item -and $item.LinkType) {
                        # اگر لینک سمبولیک یا junction هست
                        $target = (Get-Item $item.Target -ErrorAction SilentlyContinue).FullName
                        if ($target) {
                            Write-Host "Link: $path -> $target"
                            $physicalPaths += $target
                        }
                    }
                    elseif ($item) {
                        # مسیر معمولی
                        $physicalPaths += $item.FullName
                    }
                }
            }
        }
        catch {
            # خطا رو نادیده بگیر
            Write-Host "Path not accessible: $path" -ForegroundColor Yellow
        }
    }
    
    return $physicalPaths | Select-Object -Unique
}


# -----------------------
# Default paths 
# -----------------------
$defaultPaths = @(
    "Recycle Bin",
    "C:\Windows\Temp",
    "$env:LOCALAPPDATA\Temp",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2",
    "$env:LOCALAPPDATA\Postman\Cache", # کش Postman
    "$env:LOCALAPPDATA\Genymobile\Genymotion\cache",  # کش Genymotion 
    "D:\Genymobile\Genymotion\cache",
    "$env:APPDATA\Code\Cache",
    "$env:APPDATA\Code - Insiders\Cache",
    "$env:USERPROFILE\.gradle\caches",
    "$env:TEMP",
    "D:\Android\.gradle\caches",
    "$env:USERPROFILE\.gradle\daemon",
    "$env:USERPROFILE\.gradle\wrapper\dists",

    # کش‌های  Edge
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker\CacheStorage",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Session Storage",


    # پوشه‌های کش مایکروسافت
    "$env:LOCALAPPDATA\Microsoft\Windows\Caches",
    "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCookies",
    "$env:LOCALAPPDATA\Microsoft\Terminal Server Client\Cache",
    "$env:LOCALAPPDATA\Microsoft\VisualStudio\*\Cache",
    
    # کش‌های WebView2
    "$env:LOCALAPPDATA\Microsoft\VisualStudio\WebView2Cache\*\EBWebView\Default\Cache\Cache_Data",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\EBWebView\Default\Cache\Cache_Data",
    
    "$env:LOCALAPPDATA\Microsoft\VSCommon\*\Cache",
    "$env:LOCALAPPDATA\Microsoft\Team Foundation\*\Cache",
    "$env:LOCALAPPDATA\Microsoft\CLR_v4*\Temp",
    "$env:LOCALAPPDATA\Microsoft\WebsiteCache",
    
    # کش‌های OneDrive
    "$env:LOCALAPPDATA\Microsoft\OneDrive\logs",
    "$env:LOCALAPPDATA\Microsoft\OneDrive\cache",
    "$env:USERPROFILE\OneDrive\cache"
)

# -----------------------
# GUI
# -----------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "CleanDevCaches - Full GUI (with scan, edit, backup, safe D: control, Recycle Bin)"
$form.Width = 1014
$form.Height = 716
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog   # یا FixedSingle
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.MaximumSize = $form.Size
$form.MinimumSize = $form.Size

# DataGridView
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Width = 959
$grid.Height = 339
$grid.Top = 10
$grid.Left = 20
$grid.AllowUserToAddRows = $false
$grid.RowHeadersVisible = $false
$grid.MultiSelect = $false
$grid.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$grid.AutoSizeColumnsMode = "None"
# $grid.AutoSizeRowsMode = "None"
$grid.AllowUserToResizeColumns = $false
$grid.AllowUserToResizeRows = $false
$grid.RowTemplate.Height = 24

# جلوگیری از Highlight شدن سلول‌ها
$grid.SelectionMode = "CellSelect"
$grid.ClearSelection()
$grid.DefaultCellStyle.SelectionBackColor = $grid.DefaultCellStyle.BackColor
$grid.DefaultCellStyle.SelectionForeColor = $grid.DefaultCellStyle.ForeColor

# Columns: Enable checkbox, Path, SizeMB, Note
$colEnabled = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$colEnabled.Name = "Enabled"
$colEnabled.HeaderText = "Choice"
$colEnabled.Width = 48
$grid.Columns.Add($colEnabled) | Out-Null #or [void]$grid.Columns.Add($colEnabled)

$colPath = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colPath.Name = "Path"
$colPath.HeaderText = "Path"
$colPath.Width = 642
$colPath.ReadOnly = $true
$grid.Columns.Add($colPath) | Out-Null

$colSize = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colSize.Name = "Size"
$colSize.HeaderText = "Size (MB)"
$colSize.Width = 95
$colSize.ReadOnly = $true
$grid.Columns.Add($colSize) | Out-Null

$colNote = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colNote.Name = "Note"
$colNote.HeaderText = "Note"
$colNote.Width = 114
$colNote.ReadOnly = $true
$grid.Columns.Add($colNote) | Out-Null

# ستون نوع مسیر (مخفی) — برای تشخیص default/custom
$colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colType.Name = "Type"
$colType.HeaderText = "Type"
$colType.Visible = $false     # مخفی کن
$grid.Columns.Add($colType) | Out-Null

$colDelete = New-Object System.Windows.Forms.DataGridViewButtonColumn
$colDelete.Name = "Delete"
$colDelete.HeaderText = "Delete"
$colDelete.Text = "X"
$colDelete.UseColumnTextForButtonValue = $true
$colDelete.Width = 40
$colDelete.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightCoral
$colDelete.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$colDelete.FlatStyle = "Popup"

$grid.Columns.Add($colDelete) | Out-Null

# گرفتن مسیر های موجود و یونیک دیفالت
$uniquePaths = Get-UniquePhysicalPaths -paths $defaultPaths

# Fill grid with defaults
foreach ($p in $uniquePaths) {
    $row = $grid.Rows.Add()
    
    # $grid.Rows[$row].Cells[0].Value = $true #ستون ها با ایندکس هم میشود دریافت کرد ولی با نام راحت و بهتر است
    # $grid.Rows[$row].Cells[1].Value = $p
    # $grid.Rows[$row].Cells[2].Value = ""
    # $grid.Rows[$row].Cells[3].Value = ""
    # $grid.Rows[$row].Cells[4].Value = "default"   # نوع مسیر
    $grid.Rows[$row].Cells["Enabled"].Value = $true #ستون ها با ایندکس هم میشود دریافت کرد ولی با نام راحت و بهتر است
    $grid.Rows[$row].Cells["Path"].Value = $p
    $grid.Rows[$row].Cells["Size"].Value = ""
    $grid.Rows[$row].Cells["Note"].Value = ""
    $grid.Rows[$row].Cells["Type"].Value = "default"

    # غیرفعال کردن دکمه حذف
    $grid.Rows[$row].Cells["Delete"].ReadOnly = $true
    $grid.Rows[$row].Cells["Delete"].Style.BackColor = [System.Drawing.Color]::Gray
}

# Fill grid with defaults
# foreach ($p in $defaultPaths) {

#     $row = $grid.Rows.Add()

#     # $grid.Rows[$row].Cells[0].Value = $true #ستون ها با ایندکس هم میشود دریافت کرد ولی با نام راحت و بهتر است
#     # $grid.Rows[$row].Cells[1].Value = $p
#     # $grid.Rows[$row].Cells[2].Value = ""
#     # $grid.Rows[$row].Cells[3].Value = ""
#     # $grid.Rows[$row].Cells[4].Value = "default"   # نوع مسیر

#     $grid.Rows[$row].Cells["Enabled"].Value = $true #ستون ها با ایندکس هم میشود دریافت کرد ولی با نام راحت و بهتر است
#     $grid.Rows[$row].Cells["Path"].Value = $p
#     $grid.Rows[$row].Cells["Size"].Value = ""
#     $grid.Rows[$row].Cells["Note"].Value = ""
#     $grid.Rows[$row].Cells["Type"].Value = "default"

#     # غیرفعال کردن دکمه حذف
#     $grid.Rows[$row].Cells["Delete"].ReadOnly = $true
#     $grid.Rows[$row].Cells["Delete"].Style.BackColor = [System.Drawing.Color]::Gray
# }

#  مسیرهای کاربر
$customPaths = Load-CustomPaths
foreach ($p in $customPaths) {
    $row = $grid.Rows.Add()
    $grid.Rows[$row].Cells["Enabled"].Value = $true 
    $grid.Rows[$row].Cells["Path"].Value = $p
    $grid.Rows[$row].Cells["Size"].Value = ""
    $grid.Rows[$row].Cells["Note"].Value = ""
    $grid.Rows[$row].Cells["Type"].Value = "custom"    # نوع مسیر
}

$grid.Add_CellContentClick({
        param($sender, $e)

        # اگر روی هدر کلیک شده یا index نامعتبر است، بیرون می‌آییم
        if ($e.RowIndex -lt 0) { return }

        # اگر ستون حذف نبود، کاری نکن
        if ($grid.Columns[$e.ColumnIndex].Name -ne "Delete") { return }

        $row = $grid.Rows[$e.RowIndex]
        $path = $row.Cells["Path"].Value
        $type = $row.Cells["Type"].Value


        # مسیر پیش‌فرض قابل حذف نیست
        if ($type -eq "default") {
            [System.Windows.Forms.MessageBox]::Show("The default path cannot be deleted.")
            return
        }

        # پیام هشدار
        $msg = "Delete this path?`n`n$path"
        $res = [System.Windows.Forms.MessageBox]::Show($msg, "Delete Path", "YesNo", "Warning")

        if ($res -ne "Yes") { return }

        # حذف ردیف
        $grid.Rows.RemoveAt($e.RowIndex)

        # ذخیره دوباره مسیرها
        $newList = @()
        foreach ($r in $grid.Rows) {
            if ($r.IsNewRow) { continue }
            $val = $r.Cells["Path"].Value
            $t = $r.Cells["Type"].Value
            if ($val -and $t -eq "custom") {
                $newList += $val 
            }
        }
        Save-CustomPaths $newList
        Log "Path removed and saved: $path"
    })

$form.Controls.Add($grid)

# Buttons and controls
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "Scan Sizes"
$btnScan.Top = 410
$btnScan.Left = 20
$btnScan.Width = 200
$form.Controls.Add($btnScan)

$chkAllowNonSystemDrives = New-Object System.Windows.Forms.CheckBox
$chkAllowNonSystemDrives.Text = "Allow cleaning of non-system drives (if not enabled, paths on drives other than C: will not be cleaned)"
$chkAllowNonSystemDrives.Top = 410
$chkAllowNonSystemDrives.Left = 240
$chkAllowNonSystemDrives.Width = 600
$chkAllowNonSystemDrives.Checked = $false
$form.Controls.Add($chkAllowNonSystemDrives)

$chkBackup = New-Object System.Windows.Forms.CheckBox
$chkBackup.Text = "Backup before cleanup (keep only the latest backup)"
$chkBackup.Top = 440
$chkBackup.Left = 240
$chkBackup.Width = 420
$chkBackup.Checked = $true
$form.Controls.Add($chkBackup)

$txtBackupDir = New-Object System.Windows.Forms.TextBox
$txtBackupDir.Top = 440
$txtBackupDir.Left = 680
$txtBackupDir.Width = 220
# $txtBackupDir.Text = "D:\DevCacheBackup"
$form.Controls.Add($txtBackupDir)

# در ابتدای اسکریپت - بارگذاری تنظیمات
$settings = Load-Settings

if ($settings.BackupPath -and (Test-Path (Split-Path $settings.BackupPath -Qualifier))) {
    $txtBackupDir.Text = $settings.BackupPath
}
else {
    $txtBackupDir.Text = $defaultBackupPath
    # فقط اگر مسیر ذخیره شده وجود نداره یا معتبر نیست، ذخیره کن
    if ([string]::IsNullOrEmpty($settings.BackupPath) -or -not (Test-Path (Split-Path $settings.BackupPath -Qualifier))) {
        $settings.BackupPath = $defaultBackupPath
        Save-Settings $settings
    }
}

$btnBrowseBackup = New-Object System.Windows.Forms.Button
$btnBrowseBackup.Text = "Browse"
$btnBrowseBackup.Top = 428
$btnBrowseBackup.Left = 903
$btnBrowseBackup.Width = 57
$btnBrowseBackup.Height = 40
$btnBrowseBackup.Add_Click({
        $fd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fd.Description = "Select folder for backups"
        if ($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtBackupDir.Text = $fd.SelectedPath
            # خودکار در $txtBackupDir.Add_TextChanged ذخیره میشه
        }
    })
$form.Controls.Add($btnBrowseBackup)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Clean"
$btnStart.Top = 480
$btnStart.Left = 20
$btnStart.Width = 220
$btnStart.Height = 40
$form.Controls.Add($btnStart)

$btnAddNewRow = New-Object System.Windows.Forms.Button
$btnAddNewRow.Text = "Add new path"
$btnAddNewRow.Top = 480
$btnAddNewRow.Left = 260
$btnAddNewRow.Width = 140
$btnAddNewRow.Height = 40
$btnAddNewRow.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Select a folder to add to cleanup list"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $selectedPath = $dialog.SelectedPath

            # جلوگیری از تکراری بودن مسیر
            $exists = $grid.Rows | ForEach-Object { $_.Cells["Path"].Value } | Where-Object { $_ -eq $selectedPath }
            if ($exists.Count -gt 0) {
                [System.Windows.Forms.MessageBox]::Show("This path is already added.", "Duplicate Path")
                return
            }

            # اضافه به گرید
            $idx = $grid.Rows.Add()
            $grid.Rows[$idx].Cells["Enabled"].Value = $true
            # $grid.Rows[$idx].Cells["Path"].Value = "C:\path\to\cache"
            $grid.Rows[$idx].Cells["Path"].Value = $selectedPath
            $grid.Rows[$idx].Cells["Size"].Value = ""
            $grid.Rows[$idx].Cells["Type"].Value = "custom"
            # ذخیره در فایل
            $allPaths = @()
            foreach ($r in $grid.Rows) {
                if ($r.Cells["Path"].Value -and $r.Cells["Type"].Value -eq "custom") {
                    $allPaths += $r.Cells["Path"].Value
                }
            }

            Save-CustomPaths $allPaths

            Log "Path added and saved: $path"
        }
    })
$form.Controls.Add($btnAddNewRow)

# $btnRemove = New-Object System.Windows.Forms.Button
# $btnRemove.Text = "Delete selected row"
# $btnRemove.Top = 480
# $btnRemove.Left = 420
# $btnRemove.Width = 140
# $btnRemove.Height = 40
# $btnRemove.Add_Click({
#         if ($grid.SelectedRows.Count -gt 0) {
#             $grid.Rows.RemoveAt($grid.SelectedRows[0].Index)
#         }
#     })
# $form.Controls.Add($btnRemove)

$btnChangePassword = New-Object System.Windows.Forms.Button
$btnChangePassword.Text = "Change password"
$btnChangePassword.Top = 480
$btnChangePassword.Left = 420
$btnChangePassword.Width = 140
$btnChangePassword.Height = 40
$btnChangePassword.Add_Click({
        Change-Password
    })
$form.Controls.Add($btnChangePassword)

# New button: Delete Backups folder (with optional zip backup)
$btnDeleteBackups = New-Object System.Windows.Forms.Button
$btnDeleteBackups.Text = "Delete Backups Folder"
$btnDeleteBackups.Top = 480
$btnDeleteBackups.Left = 580
$btnDeleteBackups.Width = 180
$btnDeleteBackups.Height = 40
# $btnDeleteBackups.Add_Click({
#         $backupDir = $txtBackupDir.Text
#         if ([string]::IsNullOrWhiteSpace($backupDir) -or -not (Test-Path $backupDir)) {
#             [System.Windows.Forms.MessageBox]::Show("Backup folder does not exist or is empty.", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
#             return
#         }

#         # $msg = "Do you want to create a ZIP of the backup folder before deleting it?`n`nYes = create zip then delete.`nNo = delete without creating zip.`nCancel = abort."
#         $msg = "Do you want deleting backup folder?"
#         $res = [System.Windows.Forms.MessageBox]::Show($msg, "Delete Backups", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)

#         if ($res -eq [System.Windows.Forms.DialogResult]::Cancel) {
#             Log "User cancelled delete backups."
#             return
#         }

#         try {
#             if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
#                 # create a zip of the entire backup folder (placed next to it)
#                 # $parent = Split-Path -Parent $backupDir
#                 # if (-not $parent) { $parent = $backupDir } 
#                 # $zipName = Join-Path $parent ("BackupFolderBeforeDelete_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".zip")
#                 # Log "Creating zip of backup folder: $zipName"
#                 # Compress-Archive -Path (Join-Path $backupDir "*") -DestinationPath $zipName -Force -ErrorAction Stop
#                 # Log "Zip created: $zipName"
#                 # delete the backup folder contents and folder
#                 Log "Deleting backup folder: $backupDir"
#                 Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction Stop
#                 Log "Backup folder deleted."
#                 [System.Windows.Forms.MessageBox]::Show("Backup folder deleted.", "Done", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
#             }

            
#         }
#         catch {
#             Log "Error deleting backup folder: $_"
#             [System.Windows.Forms.MessageBox]::Show("Error deleting backup folder: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
#         }
#     })
$btnDeleteBackups.Add_Click({
        $backupDir = $txtBackupDir.Text
        if ([string]::IsNullOrWhiteSpace($backupDir) -or -not (Test-Path $backupDir)) {
            [System.Windows.Forms.MessageBox]::Show("Backup folder does not exist or is empty.", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }

        $msg = "Are you sure you want to delete all backup files created by this application?`n`nFolder: $backupDir"
        $res = [System.Windows.Forms.MessageBox]::Show($msg, "Delete Backup Files", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)

        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                # فقط فایل‌های بکاپ که توسط این برنامه ایجاد شدن
                $backupFiles = Get-ChildItem -Path $backupDir -Filter "Backup_*.zip" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "^Backup_\d{8}_\d{6}_.+\.zip$" }
            
                if ($backupFiles.Count -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("No backup files found in the folder.", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    return
                }

                $deletedCount = 0
                foreach ($file in $backupFiles) {
                    try {
                        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                        $deletedCount++
                        Log "Backup file deleted: $($file.Name)"
                    }
                    catch {
                        Log "Error deleting backup file $($file.Name): $_"
                    }
                }

                [System.Windows.Forms.MessageBox]::Show("$deletedCount backup file(s) deleted successfully.", "Done", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                Log "Backup files deletion completed. Total deleted: $deletedCount"
            }
            catch {
                Log "Error deleting backup files: $_"
                [System.Windows.Forms.MessageBox]::Show("Error deleting backup files: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
        else {
            Log "User cancelled backup files deletion."
        }
    })
$form.Controls.Add($btnDeleteBackups)

# Progress and log box
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Top = 540
$progress.Left = 20
$progress.Width = 960
$progress.Height = 22
# استایل Continuous با رنگ سبز
$progress.Style = "Continuous"
$progress.ForeColor = [System.Drawing.Color]::FromArgb(76, 175, 80)   # سبز زیبا
$progress.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)  # خاکستری روشن
$form.Controls.Add($progress)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Top = 570
$logBox.Left = 20
$logBox.Width = 960
$logBox.Height = 95
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)

function Log {
    param($s)
    $logBox.AppendText((Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " - " + $s + "`r`n")
}

$txtBackupDir.Add_TextChanged({
        if (-not [string]::IsNullOrWhiteSpace($txtBackupDir.Text)) {
            $settings = Load-Settings
            $settings.BackupPath = $txtBackupDir.Text
            Save-Settings $settings
            Log "Backup path updated to: $($txtBackupDir.Text)"
        }
    })

function Start-Scan {
    param (
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.DataGridView]$grid,
        
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.ProgressBar]$progress
    )

    $rowCount = $grid.Rows.Count
    if ($rowCount -eq 0) { return }
    $progress.Value = 0
    $progress.Maximum = $rowCount
    Log "Starting to scan sizes. This may take a few minutes..."
    for ($i = 0; $i -lt $rowCount; $i++) {
        if ($grid.Rows[$i].IsNewRow) { continue }
        $path = $grid.Rows[$i].Cells["Path"].Value
        if ($path -eq "Recycle Bin") {
            $size = Get-RecycleBinSizeMB
            $grid.Rows[$i].Cells["Size"].Value = Convert-ToDoubleSafe($size)
            $grid.Rows[$i].Cells["Note"].Value = "Recycle Bin"
        }
        elseif (![string]::IsNullOrWhiteSpace($path) -and (Test-Path $path)) {
            $size = Get-FolderSizeMB $path
            $grid.Rows[$i].Cells["Size"].Value = Convert-ToDoubleSafe($size)
            $grid.Rows[$i].Cells["Note"].Value = ""
        }
        else {
            $grid.Rows[$i].Cells["Size"].Value = Convert-ToDoubleSafe("")
            $grid.Rows[$i].Cells["Note"].Value = "There is no path"
            # رنگ پس‌زمینه‌ی ردیف قرمز روشن
            $grid.Rows[$i].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(255, 230, 230)
        }
        $progress.Value = $i + 1
        Start-Sleep -Milliseconds 59
        [System.Windows.Forms.Application]::DoEvents()
    }
    $progress.Value = 0  # بازنشانی پس از اتمام
    Log "Scanning sizes finished."
}

# -----------------------
# Scan Sizes button (updated to handle Recycle Bin)
# -----------------------
$btnScan.Add_Click({
        Start-Scan -grid $grid -progress $progress  
    })

# -----------------------
# Start Clean button (updated deletion loop to handle Recycle Bin)
# -----------------------
$btnStart.Add_Click({
        # build list of selected paths
        $toDelete = @()
        for ($i = 0; $i -lt $grid.Rows.Count; $i++) {
            $enabled = $grid.Rows[$i].Cells["Enabled"].Value
            $p = $grid.Rows[$i].Cells["Path"].Value
            $sz = $grid.Rows[$i].Cells["Size"].Value
  
            if ($enabled -and -not [string]::IsNullOrWhiteSpace($p)) {
                # بررسی مقدار اندازه پوشه
                if ($sz -eq "") {
                    $sz = Get-FolderSizeMB $p
                }
                else {
                    $sz = [double]$sz
                }

                # افزودن مسیر و اندازه به لیست
                $toDelete += [PSCustomObject]@{ Path = $p; SizeMB = $sz }
            }
        }

        if ($toDelete.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No path selected.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        # # Check for any D: paths if not allowed
        # $dPaths = $toDelete | Where-Object { $_.Path -match "^[dD]:" }
        # if ($dPaths.Count -gt 0 -and -not $chkAllowD.Checked) {
        #     $msg = "Note: The following path(s) are located on drive D:. It is not safe to wipe drive D unless you explicitly allow it.`n`n"
        #     $msg += ($dPaths | ForEach-Object { $_.Path + " (" + $_.SizeMB + " MB)" } ) -join "`n"
        #     $msg += "`n`nIf you are sure you want to continue, check the 'Allow cleaning of drive D:' box."
        #     $response = [System.Windows.Forms.MessageBox]::Show($msg, "Warning D:", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        #     if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
        #         $chkAllowD.Checked = $true  # تیک تایید را فعال می‌کنیم.
        #     }
        #     else {
        #         return  # اگر کاربر تایید نکرد، فرآیند متوقف می‌شود.
        #     }
        # }

        # Check for any non-C: drives paths if not allowed
        $nonSystemPaths = @($toDelete | Where-Object { 
                $_.Path -match "^[A-BD-Z]:" -and $_.Path -notmatch "^C:"
            })
    
        if ($nonSystemPaths.Count -gt 0 -and -not $chkAllowNonSystemDrives.Checked) {
            $msg = "Note: The following path(s) are located on drives other than C:. It is not safe to wipe non-system drives unless you explicitly allow it.`n`n"
            $msg += ($nonSystemPaths | ForEach-Object { $_.Path + " (" + $_.SizeMB + " MB)" } ) -join "`n"
            $msg += "`n`nIf you are sure you want to continue, check the 'Allow cleaning of non-system drives' box."
            $response = [System.Windows.Forms.MessageBox]::Show($msg, "Warning - Non-System Drives", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
                $chkAllowNonSystemDrives.Checked = $true
            }
            else {
                return # اگر کاربر تایید نکرد، فرآیند متوقف می‌شود.
            }
        }

        # Summary before cleaning
        $summary = "You are clearing the following paths:`n`n"
        $summary += ($toDelete | ForEach-Object { "$($_.Path) -> $($_.SizeMB) MB" }) -join "`n"
        $summary += "`n`nAre you sure?"
        if (-not (Confirm-Action $summary)) { Log "User canceled the operation."; return }

        # Backup if enabled
        if ($chkBackup.Checked) {
            $backupDir = $txtBackupDir.Text
            if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
            # حذف بکاپ‌های قدیمی برنامه (فقط آخرین را نگه می‌دارد)
            Get-ChildItem -Path $backupDir -Filter "Backup_*.zip" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^Backup_\d{8}_\d{6}_.+\.zip$" } |
            Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 |
            Remove-Item -Force -ErrorAction SilentlyContinue

            # بررسی فضای خالی درایو بکاپ (بعد از حذف فایل‌های قدیمی)
            $drive = [System.IO.DriveInfo]::new((Split-Path -Path $backupDir -Qualifier))
            $freeSpaceMB = [math]::Round($drive.AvailableFreeSpace / 1MB, 2)
    
            # تخمین فضای مورد نیاز (فقط پوشه‌هایی که بکاپ می‌گیریم - بدون سطل زباله)
            $estimatedSizeMB = ($toDelete | Where-Object { $_.Path -ne "Recycle Bin" } | Measure-Object -Property SizeMB -Sum).Sum
    
            # اضافه کردن 10% برای احتیاط و فایل‌های موقت
            $requiredSpaceMB = [math]::Round($estimatedSizeMB * 1.1, 2)

            if ($freeSpaceMB -lt $requiredSpaceMB) {
                $msg = @"
Not enough free space on backup drive!

Available space: $freeSpaceMB MB
Estimated required: $requiredSpaceMB MB

Do you want to continue without backup?
"@
                $result = [System.Windows.Forms.MessageBox]::Show($msg, "Low Disk Space", 
                    [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                    [System.Windows.Forms.MessageBoxIcon]::Warning)
        
                if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                    Log "Cleanup cancelled due to insufficient backup space. Free: $freeSpaceMB MB, Required: $requiredSpaceMB MB"
                    return
                }
                else {
                    $chkBackup.Checked = $false
                    Log "Continuing without backup due to low disk space. Free: $freeSpaceMB MB, Required: $requiredSpaceMB MB"
                }
            }
            else {
                Log "Starting backup. Free space: $freeSpaceMB MB, Required: $requiredSpaceMB MB" 

                # مسیرهایی که قابل فشرده شدن هستند (شامل مسیر Recycle Bin هم)
                $pathsToZip = $toDelete | ForEach-Object { $_.Path } |
                Where-Object { (Test-Path $_) -or ($_ -eq "Recycle Bin") }

                if ($pathsToZip.Count -gt 0) {
                    Log "Starting backup compression..."
                    try {
                        # مسیرهای واقعی که قابل فشرده شدن هستند (Recycle Bin را حذف می‌کنیم)
                        $compressPaths = $pathsToZip | Where-Object {
                            ($_ -ne "Recycle Bin") -and (Test-Path $_)
                        }

                        $compressPaths | ForEach-Object {
                            $path = $_
                            try {
                                # فقط فایل‌هایی که باز نیستند
                                $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue |
                                Where-Object { 
                                    try { $stream = [System.IO.File]::Open($_.FullName, 'Open', 'Read'); $stream.Close(); $true } catch { $false }
                                }
                                if ($files.Count -gt 0) {
                                    # $backupName = "Backup_" + (Get-Date -Format "yyyyMMdd_HHmmss") + "_" + [System.IO.Path]::GetFileName($path) + ".zip"
                                    $backupName = "Backup_" + (Get-Date -Format "yyyyMMdd_HHmmss") + "_" + 
                                    ($path -replace '[\\/:*?"<>|]', '_') + ".zip"
                                    $backupPath = Join-Path $backupDir $backupName
                                    Compress-Archive -Path $files.FullName -DestinationPath $backupPath -Force -ErrorAction Stop
                                    Log "Backup in: $backupPath"
                                }
                                else {
                                    Log "Nothing compressible in $path (all files may be in use or empty path)."
                                }
                            }
                            catch {
                                Log "Error compressing $path : $_"
                            }
                        }

                    }
                    catch {
                        Log "Error in backup: $_"
                    }
                }
            }
        }

        # Execute deletion
        $totalBefore = ($toDelete | Measure-Object -Property SizeMB -Sum).Sum
        $deletedSum = 0
        $beforeSize = 0
        $recycleBinPath = "Recycle Bin"  # یا مسیر خاص سطل زباله در ویندوز
        $recycleBinChecked = $false

        # تنظیم پروگرس بار برای پاک‌سازی
        $progress.Value = 0
        $progress.Maximum = $toDelete.Count
        $progress.Style = "Continuous"
    
        $currentItem = 0

        foreach ($item in $toDelete) {
            $p = $item.Path
            try {
                # اگر مسیر Recycle Bin باشد، به آن دسترسی نخواهیم داشت برای اسکن سایز
                if ($p -eq $recycleBinPath) {
                    # از آنجا که نمی‌توانیم سطل زباله را هنگام اسکن محاسبه کنیم، فقط علامت‌گذاری می‌کنیم
                    Log "Recycle Bin detected, skipping size check for this path."
                    $recycleBinChecked = $true
                    continue  # از این مسیر صرف نظر می‌کنیم
                }
                $currentItem++
                $progress.Value = $currentItem
                [System.Windows.Forms.Application]::DoEvents()
                Log "Cleaning: $p ($currentItem/$selectedCount)"
                if (Test-Path $p) {
                    Log "Delete: $p"
                    # محاسبه اندازه پیش از حذف
                    $beforeSize = Get-FolderSizeMB $p
            
                    # استفاده از Get-ChildItem برای حذف تمام فایل‌ها و زیرپوشه‌ها، حتی بدون نیاز به تایید
                    $items = Get-ChildItem -Path $p -Recurse -ErrorAction SilentlyContinue
                    foreach ($item in $items) {
                        try {
                            # حذف فایل‌ها یا پوشه‌ها بدون نمایش پیغام تایید
                            Remove-Item -LiteralPath $item.FullName -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
                            Log "Deleted: $($item.FullName)"
                        }
                        catch {
                            Log "Error deleting $($item.FullName): $_"
                        }
                    }
                    Start-Sleep -Milliseconds 200
                    # محاسبه اندازه پس از حذف
                    $afterSize = Get-FolderSizeMB $p
                   
                    # محاسبه فضای آزاد شده
                    $freed = [math]::Round(($beforeSize - $afterSize), 2)
                    if ($freed -lt 0) { $freed = 0 }
                    $deletedSum += $freed
                    Log "Freed: $freed MB (after cleanup size: $afterSize MB)"
                }
                else {
                    Log "Path not found: $p"
                }

            }
            catch {
                Log "Error deleting $p : $_"
            }
            # تأخیر کوتاه برای نمایش بهتر پروگرس
            Start-Sleep -Milliseconds 100
        }

        # سپس بعد از حذف تمام فایل‌ها، سطل زباله را خالی می‌کنیم
        # چک کردن و پاکسازی سطل زباله
        if ($recycleBinChecked) {
            $deletedSize = Get-RecycleBinSizeMB
            Log "Emptying Recycle Bin..."
            try {
                Clear-RecycleBin -Force -ErrorAction Stop
                $deletedSum += $deletedSize
                Log "Recycle Bin emptied. $deletedSize MB deleted"
            }
            catch {
                # fallback via COM
                try {
                    $shell = New-Object -ComObject Shell.Application
                    $recycle = $shell.Namespace(0xA)
                    $recycle.Items() | ForEach-Object { $recycle.InvokeVerb("delete") }
                    Start-Sleep -Milliseconds 500
                    $deletedSum += $deletedSize
                    Log "Recycle Bin emptied (fallback). $deletedSize MB deleted"
                }
                catch {
                    Log "Failed to empty Recycle Bin: $_"
                }
            }
        }


        $progress.Value = 0
        Log "Cleaning completed. Approximate total freed space: $deletedSum MB"
        # [System.Windows.Forms.MessageBox]::Show("Cleaning complete.`nAbout $deletedSum MB freed.", "Finished", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

        # نمایش پیغام برای درخواست شروع دوباره اسکن
        $choice = [System.Windows.Forms.MessageBox]::Show("Cleaning complete.`nAbout $deletedSum MB freed. Do you want to rescan?", "Finished", [System.Windows.Forms.MessageBoxButtons]::YesNo)

        # بررسی انتخاب کاربر
        if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) {
            # اگر کاربر Yes را انتخاب کند، اسکن دوباره شروع شود
            Log "rescan..."
            Start-Scan -grid $grid -progress $progress
        }
        else {
            # اگر کاربر No را انتخاب کند، اسکن متوقف می‌شود
            Log "canceled."
        }

    })

# show form
$form.Topmost = $false
$form.Add_Shown({ $form.Activate() })
$form.ShowDialog() | Out-Null
