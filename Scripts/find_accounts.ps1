# find_accounts.ps1 v20 - Find accounts with <=300 original articles
# v20: Fallback account name recognition from homepage avatar area when article page OCR fails
# Records account name + original article count, stops when 3 matches found
Add-Type -AssemblyName System.Windows.Forms
Add-Type -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, int delta, uint info);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);
[DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
[DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern IntPtr FindWindow(string className, string windowName);
'@ -Name Win32 -Namespace W

$TargetCount = 3  # Stop after finding 3 accounts with <=300 original articles
$MaxScan = 30     # Max articles to scan before giving up
$Threshold = 300
$VK_MENU = 0x12
$KEYEVENTF_KEYUP = 0x0002

$articlePositions = @(
    @{ X = 920; Y = 220 },
    @{ X = 920; Y = 400 },
    @{ X = 920; Y = 580 },
    @{ X = 920; Y = 760 }
)

$matchedAccounts = @()
$visitedHashes = @{}  # Avoid duplicate accounts

function Log($msg) {
    [System.Console]::WriteLine($msg)
}

function Get-ForegroundTitle {
    $hwnd = [W.Win32]::GetForegroundWindow()
    $sb = New-Object System.Text.StringBuilder 256
    [W.Win32]::GetWindowText($hwnd, $sb, 256) | Out-Null
    return $sb.ToString()
}

function IsArticleOpen {
    # Check if foreground window IS WeChatAppEx (not just process exists)
    # This prevents false positive when clicking blank area with stale WeChatAppEx still running
    $fgHwnd = [W.Win32]::GetForegroundWindow()
    $sb = New-Object System.Text.StringBuilder 256
    [W.Win32]::GetWindowText($fgHwnd, $sb, 256) | Out-Null
    $fgTitle = $sb.ToString()
    
    # Get WeChatAppEx main window title for comparison
    $appExProc = Get-Process -Name "WeChatAppEx" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $appExProc) { return $false }
    
    $appExHwnd = $appExProc.MainWindowHandle
    return ($fgHwnd -eq $appExHwnd)
}

function Close-StaleArticleWindow {
    $stale = Get-Process -Name "WeChatAppEx" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
    if ($stale) {
        foreach ($proc in $stale) {
            $hwnd = $proc.MainWindowHandle
            [W.Win32]::ShowWindow($hwnd, 9) | Out-Null
            Start-Sleep -Milliseconds 100
            [W.Win32]::SetForegroundWindow($hwnd) | Out-Null
            Start-Sleep -Milliseconds 200
            [W.Win32]::keybd_event(0x12, 0, 0, 0)
            Start-Sleep -Milliseconds 50
            [W.Win32]::keybd_event(0x73, 0, 0, 0)
            Start-Sleep -Milliseconds 50
            [W.Win32]::keybd_event(0x73, 0, 0x0002, 0)
            Start-Sleep -Milliseconds 50
            [W.Win32]::keybd_event(0x12, 0, 0x0002, 0)
            Start-Sleep -Milliseconds 500
            Log "  >> Closed stale WeChatAppEx window"
        }
    }
}

function Focus-Window($procName) {
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $proc) { return $false }
    $hwnd = $proc.MainWindowHandle
    [W.Win32]::ShowWindow($hwnd, 3) | Out-Null
    Start-Sleep -Milliseconds 200
    [W.Win32]::keybd_event($VK_MENU, 0, 0, 0)
    Start-Sleep -Milliseconds 100
    [W.Win32]::keybd_event($VK_MENU, 0, $KEYEVENTF_KEYUP, 0)
    Start-Sleep -Milliseconds 200
    [W.Win32]::BringWindowToTop($hwnd) | Out-Null
    Start-Sleep -Milliseconds 200
    [W.Win32]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 1000
    return $true
}

function Focus-Weixin {
    $ok = Focus-Window "Weixin"
    if ($ok) {
        $title = Get-ForegroundTitle
        Log "  >> Foreground: $title"
    }
    return $ok
}

function Scroll-Down {
    Focus-Weixin
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(920, 500)
    for ($i = 0; $i -lt 5; $i++) {
        [W.Win32]::mouse_event(0x0800, 0, 0, -120, 0)
        Start-Sleep -Milliseconds 200
    }
    Log "  >> Scrolled down"
}

function Extract-OriginalCount($ocrLines) {
    # Extract only original article count from OCR lines (account homepage)
    $originalCount = $null
    
    foreach ($line in $ocrLines) {
        $textPart = if ($line -match '\|\s*(.+)$') { $Matches[1].Trim() } else { "" }
        if ($textPart -eq "") { continue }
        $noSpace = $textPart -replace '\s', ''
        
        # Find "篇" character (U+7BC7)
        $pianIdx = -1
        for ($pi = 0; $pi -lt $noSpace.Length; $pi++) {
            if ([int]$noSpace[$pi] -eq 0x7BC7) { $pianIdx = $pi; break }
        }
        
        if ($pianIdx -gt 0) {
            $beforePian = $noSpace.Substring(0, $pianIdx)
            $numBeforePian = ($beforePian.ToCharArray() | Where-Object { $_ -match '\d' }) -join ''
            if ($numBeforePian.Length -ge 1) {
                $originalCount = [int]$numBeforePian
                Log "  >> Original count: $originalCount from: $textPart"
                break
            }
        }
    }
    
    return $originalCount
}

function Process-Article($cx, $cy, $num) {
    $maxRetry = 2
    for ($r = 0; $r -le $maxRetry; $r++) {
        Log "  Clicking #$num at ($cx, $cy) attempt $($r+1)"
        
        # Only clean stale window on first attempt
        if ($r -eq 0) { Close-StaleArticleWindow }
        
        # Make sure WeChat is in foreground before clicking
        Focus-Weixin | Out-Null
        Start-Sleep -Milliseconds 200
        
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($cx, $cy)
        Start-Sleep -Milliseconds 200
        [W.Win32]::mouse_event(0x0002, 0, 0, 0, 0)
        Start-Sleep -Milliseconds 100
        [W.Win32]::mouse_event(0x0004, 0, 0, 0, 0)
        Start-Sleep -Milliseconds 1200
        
        if (-not (IsArticleOpen)) {
            Log "  >> Miss (clicked blank area)! Retrying..."
            continue
        }
        Log "  >> Article #$num opened OK"
        
        # Focus article window FIRST, then screenshot for account name
        Start-Sleep -Milliseconds 800
        Focus-Window "WeChatAppEx" | Out-Null
        Start-Sleep -Milliseconds 500
        
        # Step 1: OCR article page to get account name
        & powershell -ExecutionPolicy Bypass -File "D:\workbuddy\temps\screenshot.ps1" "D:\workbuddy\temps\ocr_article.png" 2>$null | Out-Null
        Start-Sleep -Milliseconds 500
        $ocrResult1 = & powershell -ExecutionPolicy Bypass -File "D:\workbuddy\temps\win_ocr.ps1" "D:\workbuddy\temps\ocr_article.png" 2>$null 3>$null
        $ocrLines1 = @($ocrResult1 | Where-Object { $_ -is [string] -and $_ -match "center=" })
        
        # Account name: article page bottom area, X 400-700, Y 950-1000
        $accountName = $null
        foreach ($line in $ocrLines1) {
            if ($line -match "center=\((\d+),(\d+)\)") {
                $cx = [int]$Matches[1]
                $cy = [int]$Matches[2]
                $textPart = if ($line -match '\|\s*(.+)$') { $Matches[1].Trim() } else { "" }
                $noSpace = $textPart -replace '\s', ''
                # Account name at bottom of article page: X 400-700, Y 950-1000
                if ($cx -gt 400 -and $cx -lt 700 -and $cy -gt 950 -and $cy -lt 1000) {
                    if ($noSpace.Length -ge 2 -and $noSpace.Length -le 30) {
                        # Skip UI elements like single digit "0"
                        if ($noSpace.Length -ge 3) {
                            $accountName = $textPart -replace '\s+', ' '
                            Log "  >> Account name: $accountName (center=$cx,$cy)"
                            break
                        }
                    }
                }
            }
        }
        # If not found, try wider range: X 400-750, Y 880-1000
        if (-not $accountName) {
            foreach ($line in $ocrLines1) {
                if ($line -match "center=\((\d+),(\d+)\)") {
                    $cx = [int]$Matches[1]
                    $cy = [int]$Matches[2]
                    $textPart = if ($line -match '\|\s*(.+)$') { $Matches[1].Trim() } else { "" }
                    $noSpace = $textPart -replace '\s', ''
                    if ($cx -gt 400 -and $cx -lt 750 -and $cy -gt 880 -and $cy -lt 1000) {
                        if ($noSpace.Length -ge 3 -and $noSpace.Length -le 30) {
                            $accountName = $textPart -replace '\s+', ' '
                            Log "  >> Account name (wide): $accountName (center=$cx,$cy)"
                            break
                        }
                    }
                }
            }
        }
        if (-not $accountName) { $accountName = "(unknown)" }
        
        # Step 2: Click profile at (330, 650) to enter account homepage
        $profileClicked = $false
        for ($pr = 0; $pr -le 2; $pr++) {
            [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(330, 650)
            Start-Sleep -Milliseconds 300
            [W.Win32]::mouse_event(0x0002, 0, 0, 0, 0)
            Start-Sleep -Milliseconds 100
            [W.Win32]::mouse_event(0x0004, 0, 0, 0, 0)
            Start-Sleep -Milliseconds 1500
            $fgTitle = Get-ForegroundTitle
            # Check for "公众号" (U+516C U+4F17 U+53F7)
            if ($fgTitle -like "*$([char]0x516C)$([char]0x4F17)$([char]0x53F7)*") {
                Log "  >> Entered account homepage"
                $profileClicked = $true
                break
            }
            Log "  >> Profile attempt $($pr+1) failed (fg: $fgTitle)"
        }
        
        if (-not $profileClicked) {
            Log "  >> Could not enter homepage, skipping"
            return @{ Success = $true; Account = $null }
        }
        
        # Focus for screenshot
        Focus-Window "WeChatAppEx" | Out-Null
        Start-Sleep -Milliseconds 500
        
        # Screenshot and OCR
        & powershell -ExecutionPolicy Bypass -File "D:\workbuddy\temps\screenshot.ps1" "D:\workbuddy\temps\ocr_original.png" 2>$null | Out-Null
        Start-Sleep -Milliseconds 500
        $ocrResult = & powershell -ExecutionPolicy Bypass -File "D:\workbuddy\temps\win_ocr.ps1" "D:\workbuddy\temps\ocr_original.png" 2>$null 3>$null
        $ocrLines = @($ocrResult | Where-Object { $_ -is [string] -and $_ -match "center=" })
        Log "  >> OCR lines: $($ocrLines.Count)"
        
        # Extract original count from homepage OCR
        $originalCount = Extract-OriginalCount $ocrLines
        
        # Step 3: If account name still unknown, try homepage avatar area (next to circular avatar)
        if ($accountName -eq "(unknown)") {
            Log "  >> Account name not found on article page, trying homepage avatar area..."
            # Account name is to the right of the circular avatar on the homepage
            # Avatar is approximately X 150-210, Y 220-280, name is to its right: X 220-500, Y 220-300
            $homeAccountName = $null
            foreach ($line in $ocrLines) {
                if ($line -match "center=\((\d+),(\d+)\)") {
                    $hx = [int]$Matches[1]
                    $hy = [int]$Matches[2]
                    $textPart = if ($line -match '\|\s*(.+)$') { $Matches[1].Trim() } else { "" }
                    $noSpace = $textPart -replace '\s', ''
                    # Name area: X 220-550, Y 200-320 (right of avatar)
                    if ($hx -gt 220 -and $hx -lt 550 -and $hy -gt 200 -and $hy -lt 320) {
                        if ($noSpace.Length -ge 2 -and $noSpace.Length -le 30) {
                            # Filter out common UI elements and noise
                            $skipWords = @([string][char]0x002B + [string][char]0x5173 + [string][char]0x6CE8, [string][char]0x5173 + [string][char]0x6CE8, [string][char]0x641C + [string][char]0x7D22, [string][char]0x516C + [string][char]0x4F17 + [string][char]0x53F7, [string][char]0x53D6 + [string][char]0x6D88, [string][char]0x786E + [string][char]0x8BA4)
                            $isNoise = $false
                            foreach ($sw in $skipWords) {
                                if ($noSpace -like "*$sw*") { $isNoise = $true; break }
                            }
                            if (-not $isNoise) {
                                $homeAccountName = $textPart -replace '\s+', ' '
                                Log "  >> Account name (homepage): $homeAccountName (center=$hx,$hy)"
                                break
                            }
                        }
                    }
                }
            }
            # If primary area not found, try wider range
            if (-not $homeAccountName) {
                foreach ($line in $ocrLines) {
                    if ($line -match "center=\((\d+),(\d+)\)") {
                        $hx = [int]$Matches[1]
                        $hy = [int]$Matches[2]
                        $textPart = if ($line -match '\|\s*(.+)$') { $Matches[1].Trim() } else { "" }
                        $noSpace = $textPart -replace '\s', ''
                        # Wider: X 200-600, Y 180-360
                        if ($hx -gt 200 -and $hx -lt 600 -and $hy -gt 180 -and $hy -lt 360) {
                            if ($noSpace.Length -ge 3 -and $noSpace.Length -le 30) {
                                $skipWords2 = @([string][char]0x002B + [string][char]0x5173 + [string][char]0x6CE8, [string][char]0x5173 + [string][char]0x6CE8, [string][char]0x641C + [string][char]0x7D22, [string][char]0x516C + [string][char]0x4F17 + [string][char]0x53F7, [string][char]0x53D6 + [string][char]0x6D88, [string][char]0x786E + [string][char]0x8BA4, [string][char]0x7BC7 + [string][char]0x539F + [string][char]0x521B)
                                $isNoise = $false
                                foreach ($sw in $skipWords2) {
                                    if ($noSpace -like "*$sw*") { $isNoise = $true; break }
                                }
                                if (-not $isNoise) {
                                    $homeAccountName = $textPart -replace '\s+', ' '
                                    Log "  >> Account name (homepage wide): $homeAccountName (center=$hx,$hy)"
                                    break
                                }
                            }
                        }
                    }
                }
            }
            if ($homeAccountName) { $accountName = $homeAccountName }
        }
        
        return @{ Success = $true; Name = $accountName; Count = $originalCount }
    }
    
    Log "  >> Failed to open article #$num"
    return @{ Success = $false; Account = $null }
}

# Main loop
$scanned = 0
$round = 0

while ($matchedAccounts.Count -lt $TargetCount -and $scanned -lt $MaxScan) {
    $round++
    Log "--- Round $round (scanned: $scanned, found: $($matchedAccounts.Count)/$TargetCount) ---"
    
    for ($i = 0; $i -lt $articlePositions.Count; $i++) {
        if ($matchedAccounts.Count -ge $TargetCount) { break }
        if ($scanned -ge $MaxScan) { break }
        
        Focus-Weixin | Out-Null
        $pos = $articlePositions[$i]
        $result = Process-Article $pos.X $pos.Y ($scanned + 1)
        
        if ($result.Success) {
            $scanned++
            
            if ($result.Count) {
                $count = $result.Count
                $name = $result.Name
                if (-not $name) { $name = "(unknown)" }
                $hash = "$name|$count"
                
                if ($visitedHashes.ContainsKey($hash)) {
                    Log "  >> Duplicate: $name ($count), skipping"
                } else {
                    $visitedHashes[$hash] = $true
                    Log "  >> Found: $name - $count original articles"
                    
                    if ($count -le $Threshold) {
                        $matchedAccounts += @{ Name = $name; Count = $count }
                        Log "  *** MATCH! $name has $count original articles (<= $Threshold) ***"
                    } else {
                        Log "  >> $name has $count original articles (> $Threshold), not a match"
                    }
                }
            } else {
                Log "  >> Could not extract article count"
            }
        }
    }
    
    if ($matchedAccounts.Count -ge $TargetCount) { break }
    if ($scanned -ge $MaxScan) { break }
    
    Log "  Scrolling..."
    Scroll-Down
}

# Summary
Log ""
Log "========================================="
Log "  RESULTS: Found $($matchedAccounts.Count) accounts with <= $Threshold original articles"
Log "========================================="
for ($m = 0; $m -lt $matchedAccounts.Count; $m++) {
    $acc = $matchedAccounts[$m]
    Log "  $($m+1). $($acc.Name) - $($acc.Count) original articles"
}
Log "========================================="
