#Requires -RunAsAdministrator

<#
.SYNOPSIS
    自動下載並安裝Visual Studio Remote Tools
.DESCRIPTION
    這個腳本會：
    1. 檢查管理員權限
    2. 偵測CPU架構
    3. 下載對應架構的Visual Studio Remote Tools
    4. 自動安裝
.EXAMPLE
    .\Install-VSRemoteDebugger.ps1
#>

# 檢查是否以管理員身份執行
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 如果不是管理員，重新以管理員身份啟動
if (-not (Test-Administrator)) {
    Write-Host "需要管理員權限來執行此腳本..." -ForegroundColor Yellow
    Write-Host "正在重新啟動為管理員模式..." -ForegroundColor Yellow
    
    # 重新以管理員身份執行腳本
    $scriptPath = $MyInvocation.MyCommand.Path
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
    exit
} 

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

# 檢查Remote Debugger是否已安裝
Write-Host "`n正在檢查Visual Studio Remote Tools是否已安裝..." -ForegroundColor Cyan

$isInstalled = $false
$remoteDebuggerPaths = @(
    "C:\Program Files\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger",
    "C:\Program Files (x86)\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger",
    "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\Remote Debugger",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\Remote Debugger",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\Remote Debugger"
)

$installPath = ""
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

if ($isInstalled) {
    Write-Host "Visual Studio Remote Tools 已經安裝，跳過安裝步驟..." -ForegroundColor Yellow
    $skipInstallation = $true
} else {
    Write-Host "未找到已安裝的Remote Tools，將開始安裝..." -ForegroundColor Yellow
}

# 設定下載路徑
$downloadPath = Join-Path $env:TEMP $fileName
Write-Host "下載路徑: $downloadPath" -ForegroundColor Cyan

# 檢查檔案是否已存在
if (Test-Path $downloadPath) {
    Write-Host "檔案已存在，跳過下載..." -ForegroundColor Yellow
    $skipDownload = $true
}

# 下載檔案
if (-not $skipDownload) {
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

# 驗證檔案是否存在
if (-not (Test-Path $downloadPath)) {
    Write-Error "找不到下載的檔案: $downloadPath"
    Read-Host "按Enter鍵結束"
    exit 1
}

# 取得檔案大小
$fileSize = (Get-Item $downloadPath).Length
$fileSizeMB = [math]::Round($fileSize / 1MB, 2)
Write-Host "檔案大小: $fileSizeMB MB" -ForegroundColor Cyan

# 安裝Remote Tools
if (-not $skipInstallation) {
    Write-Host "`n正在安裝Visual Studio Remote Tools..." -ForegroundColor Cyan
    Write-Host "這可能需要幾分鐘時間，請耐心等候..." -ForegroundColor Yellow

    try {
        # 靜默安裝
        $installArgs = "/install /quiet /norestart"
        $process = Start-Process -FilePath $downloadPath -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "`n安裝成功完成！" -ForegroundColor Green
            Write-Host "Visual Studio Remote Tools 已成功安裝" -ForegroundColor Green
        } elseif ($process.ExitCode -eq 3010) {
            Write-Host "`n安裝成功完成！" -ForegroundColor Green
            Write-Host "需要重新啟動電腦才能完全啟用功能" -ForegroundColor Yellow
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

# 清理下載的檔案
Write-Host "`n正在清理暫存檔案..." -ForegroundColor Cyan
try {
    Remove-Item $downloadPath -Force
    Write-Host "暫存檔案已清理" -ForegroundColor Green
}
catch {
    Write-Warning "無法刪除暫存檔案: $downloadPath"
}

Write-Host "`n=== 安裝完成 ===" -ForegroundColor Green
Write-Host "Visual Studio Remote Tools 安裝程序已完成！" -ForegroundColor Green

# 啟動Wizard
$wizardPath = Join-Path $installPath "..\rdbgwiz.exe"
if(Test-Path $wizardPath){
    Start-Process -FilePath $wizardPath
}

# 建立專用User
Write-Host "`n正在建立專用使用者 VSDebugger..." -ForegroundColor Cyan
net user VSDebugger 0000 /add

# set C:\ as shared folder for VSDebugger
if((Get-SmbShare -Name "C" -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host "設定C:\為VSDebugger的共享資料夾..." -ForegroundColor Cyan
    New-SmbShare -Name "C" -Path "C:\" -FullAccess "VSDebugger"
}

# 提供額外資訊
Write-Host "`n額外資訊:" -ForegroundColor Cyan
Write-Host "- Remote Debugger 通常安裝在: C:\Program Files\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger\" -ForegroundColor Gray
Write-Host "- 您可以在開始功能表中找到 'Remote Debugger' 來啟動服務" -ForegroundColor Gray
Write-Host "- 預設遠端除錯連接埠為 4026" -ForegroundColor Gray

Read-Host "`n按Enter鍵結束"
