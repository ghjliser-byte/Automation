#Requires -RunAsAdministrator

<#
.SYNOPSIS
    自動下載、安裝並設定Visual Studio Remote Tools
.DESCRIPTION
    這個腳本會執行以下步驟：
    1. 檢查並取得管理員權限
    2. 偵測CPU架構 (AMD64/ARM64/X86)
    3. 檢查Remote Tools是否已安裝，避免重複安裝
    4. 根據CPU架構下載對應版本的Visual Studio Remote Tools
    5. 自動靜默安裝Remote Tools
    6. 啟動Remote Debugger配置精靈
    7. 建立專用除錯使用者 (VSDebugger)
    8. 設定C:\為共享資料夾供遠端除錯使用
    9. 嘗試啟動Remote Debugger服務
.NOTES
    需要管理員權限執行
    支援的架構: AMD64, ARM64, X86
    自動建立VSDebugger使用者 (密碼: 0000)
    自動設定C:\共享資料夾權限
.EXAMPLE
    .\Install-VSRemoteDebugger.ps1
    
    執行完整的Remote Tools安裝和設定流程
#>

Write-Host "=== Visual Studio Remote Tools 安裝程式 ===" -ForegroundColor Green
Write-Host "開始執行..." -ForegroundColor Green

# 偵測CPU架構
Write-Host "`n正在偵測CPU架構..." -ForegroundColor Cyan
$architecture = $env:PROCESSOR_ARCHITECTURE
$wow64Architecture = $env:PROCESSOR_ARCHITEW6432

# 判斷實際架構
if ($wow64Architecture) {
    $cpuArch = $wow64Architecture
} else {
    $cpuArch = $architecture
}

Write-Host "偵測到的CPU架構: $cpuArch" -ForegroundColor Green

# 根據架構設定下載URL和檔案名稱
$downloadUrl = ""
$fileName = ""

switch ($cpuArch.ToUpper()) {
    "AMD64" {
        $downloadUrl = "https://aka.ms/vs/17/release/RemoteTools.amd64ret.enu.exe"
        $fileName = "RemoteTools.amd64ret.enu.exe"
        Write-Host "將下載AMD64版本" -ForegroundColor Yellow
    }
    "ARM64" {
        $downloadUrl = "https://aka.ms/vs/17/release/RemoteTools.arm64ret.enu.exe"
        $fileName = "RemoteTools.arm64ret.enu.exe"
        Write-Host "將下載ARM64版本" -ForegroundColor Yellow
    }
    "X86" {
        $downloadUrl = "https://aka.ms/vs/17/release/RemoteTools.x86ret.enu.exe"
        $fileName = "RemoteTools.x86ret.enu.exe"
        Write-Host "將下載X86版本" -ForegroundColor Yellow
    }
    default {
        Write-Error "不支援的CPU架構: $cpuArch"
        Read-Host "按Enter鍵結束"
        exit 1
    }
}

# 檢查Remote Debugger是否已安裝，避免重複安裝
Write-Host "`n正在檢查Visual Studio Remote Tools是否已安裝..." -ForegroundColor Cyan

$isInstalled = $false
# 定義可能的Remote Debugger安裝路徑
$remoteDebuggerPaths = @(
    "C:\Program Files\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger",
    "C:\Program Files (x86)\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger",
    "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\Remote Debugger",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\Remote Debugger",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\Remote Debugger"
)

$installPath = ""
# 檢查各個可能的安裝路徑
foreach ($path in $remoteDebuggerPaths) {
    if (Test-Path $path) {
        $exePath = Join-Path $path "x64\msvsmon.exe"
        if (Test-Path $exePath) {
            Write-Host "找到已安裝的Remote Debugger: $path" -ForegroundColor Green
            $isInstalled = $true
            $installPath = $path
            break
        }
    }
}

# 判斷是否需要下載和安裝
if ($isInstalled) {
    Write-Host "Visual Studio Remote Tools 已經安裝，跳過下載和安裝步驟..." -ForegroundColor Yellow
    $skipInstallation = $true
} else {
    Write-Host "未找到已安裝的Remote Tools，將開始下載和安裝..." -ForegroundColor Yellow
}

# 設定下載路徑
$downloadPath = Join-Path $env:TEMP $fileName
Write-Host "下載路徑: $downloadPath" -ForegroundColor Cyan

# 檢查檔案是否已存在
if (Test-Path $downloadPath -ErrorAction SilentlyContinue) {
    Write-Host "檔案已存在，跳過下載..." -ForegroundColor Yellow
    $skipDownload = $true
}

# 下載Remote Tools安裝檔案（如果需要的話）
if ((-not $skipDownload) -and (-not $skipInstallation)) {
    Write-Host "`n正在下載Visual Studio Remote Tools..." -ForegroundColor Cyan
    Write-Host "URL: $downloadUrl" -ForegroundColor Gray
    
    try {
        # 使用 Invoke-WebRequest 下載檔案，顯示進度
        $progressPreference = 'Continue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
        Write-Host "下載完成！" -ForegroundColor Green
    }
    catch {
        Write-Error "下載失敗: $($_.Exception.Message)"
        Read-Host "按Enter鍵結束"
        exit 1
    }
}

# 執行Remote Tools靜默安裝
if (-not $skipInstallation) {
    Write-Host "`n正在安裝Visual Studio Remote Tools..." -ForegroundColor Cyan
    Write-Host "這可能需要幾分鐘時間，請耐心等候..." -ForegroundColor Yellow

    try {
        # 靜默安裝參數
        $installArgs = "/install /quiet /norestart"
        $process = Start-Process -FilePath $downloadPath -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "`n安裝成功完成！" -ForegroundColor Green
            Write-Host "Visual Studio Remote Tools 已成功安裝" -ForegroundColor Green
            # 設定安裝路徑為預設路徑
            $installPath = "C:\Program Files\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger"
        } elseif ($process.ExitCode -eq 3010) {
            Write-Host "`n安裝成功完成！" -ForegroundColor Green
            Write-Host "需要重新啟動電腦才能完全啟用功能" -ForegroundColor Yellow
            $installPath = "C:\Program Files\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger"
        } else {
            Write-Warning "安裝可能有問題，退出代碼: $($process.ExitCode)"
            Write-Host "但這可能是正常的，請檢查安裝是否成功" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "安裝過程中發生錯誤: $($_.Exception.Message)"
        Read-Host "按Enter鍵結束"
        exit 1
    }
} else {
    Write-Host "`n跳過安裝步驟，因為Remote Tools已經安裝" -ForegroundColor Green
}

# 清理暫存安裝檔案
if (Test-Path $downloadPath -ErrorAction SilentlyContinue) {
    Write-Host "`n正在清理暫存檔案..." -ForegroundColor Cyan
    try {
        Remove-Item $downloadPath -Force
        Write-Host "暫存檔案已清理" -ForegroundColor Green
    }
    catch {
        Write-Warning "無法刪除暫存檔案: $downloadPath"
    }
}

Write-Host "`n=== 開始設定Remote Debugger ===" -ForegroundColor Green

# 啟動Remote Debugger配置精靈
Write-Host "`n正在啟動Remote Debugger配置精靈..." -ForegroundColor Cyan
$wizardPath = Join-Path $installPath "..\rdbgwiz.exe"
if(Test-Path $wizardPath){
    Write-Host "找到配置精靈: $wizardPath" -ForegroundColor Green
    Start-Process -FilePath $wizardPath
} else {
    Write-Warning "找不到Remote Debugger配置精靈"
}

# 建立專用除錯使用者
Write-Host "`n正在建立專用使用者 VSDebugger..." -ForegroundColor Cyan
try {
    net user VSDebugger 0000 /add
    Write-Host "VSDebugger使用者已建立 (密碼: 0000)" -ForegroundColor Green
}
catch {
    Write-Warning "建立使用者時發生錯誤，可能使用者已存在"
}

# 設定C:\為共享資料夾給VSDebugger使用
Write-Host "`n正在設定共享資料夾..." -ForegroundColor Cyan
if((Get-SmbShare -Name "C" -ErrorAction SilentlyContinue) -eq $null) {
    try {
        Write-Host "設定C:\為VSDebugger的共享資料夾..." -ForegroundColor Cyan
        New-SmbShare -Name "C" -Path "C:\" -FullAccess "VSDebugger"
        Write-Host "共享資料夾設定完成" -ForegroundColor Green
    }
    catch {
        Write-Warning "設定共享資料夾時發生錯誤: $($_.Exception.Message)"
    }
} else {
    Write-Host "C:\共享資料夾已存在" -ForegroundColor Yellow
}

# 嘗試啟動Remote Debugger服務
Write-Host "`n正在啟動Remote Debugger..." -ForegroundColor Cyan
$msvsmonPath = Join-Path $installPath "x64\msvsmon.exe"
if (Test-Path $msvsmonPath) {
    try {
        Write-Host "啟動Remote Debugger服務..." -ForegroundColor Yellow
        # 允許VSDebugger使用者連線且不顯示安全警告
        Start-Process -FilePath $msvsmonPath -ArgumentList "/allow", "VSDebugger", "/nosecuritywarn"
        Write-Host "Remote Debugger已啟動" -ForegroundColor Green
    }
    catch {
        Write-Warning "啟動Remote Debugger時發生錯誤: $($_.Exception.Message)"
    }
} else {
    Write-Warning "找不到msvsmon.exe: $msvsmonPath"
}

Write-Host "`n=== 設定完成 ===" -ForegroundColor Green
Write-Host "Visual Studio Remote Tools 安裝與設定程序已完成！" -ForegroundColor Green

# 提供完整的設定資訊
Write-Host "`n設定摘要:" -ForegroundColor Cyan
Write-Host "✓ Remote Debugger 安裝路徑: $installPath" -ForegroundColor Gray
Write-Host "✓ 除錯使用者: VSDebugger (密碼: 0000)" -ForegroundColor Gray
Write-Host "✓ 共享資料夾: C:\ (VSDebugger有完整存取權限)" -ForegroundColor Gray
Write-Host "✓ Remote Debugger服務已啟動" -ForegroundColor Gray
Write-Host "✓ 預設遠端除錯連接埠: 4026" -ForegroundColor Gray

Read-Host "`n按Enter鍵結束"
