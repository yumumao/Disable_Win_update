# 设置执行策略
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# 获取脚本所在目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BatFile = Join-Path $ScriptDir "disable_update_daily.bat"

# 检查BAT文件是否存在
if (-not (Test-Path $BatFile)) {
    Write-Host "错误：找不到 disable_update_daily.bat 文件在 $BatFile"
    exit 1
}

# 检查今天是否已经执行过
$LogFile = "$env:TEMP\DisableUpdate_LastRun.txt"
$Today = Get-Date -Format "M/d/yyyy"

# 检查是否是系统启动后不久（10分钟内）
try {
    $BootTime = (Get-WmiObject Win32_OperatingSystem).ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime)
    $SystemUptime = (Get-Date) - $BootTime
    $IsRecentBoot = $SystemUptime.TotalMinutes -lt 10
} catch {
    $IsRecentBoot = $false
}

if ($IsRecentBoot) {
    # 如果是系统启动后不久，设置为启动触发器并直接执行
    $env:TRIGGER_SOURCE = "触发器系统启动"
    try {
        # 传递admin参数给BAT文件
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatFile`" admin" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory $ScriptDir
        exit $process.ExitCode
    } catch {
        Write-Host "执行BAT文件失败: $_"
        exit 1
    }
}

# 检查今天是否已经执行过（移到启动检查之后，因为启动触发器应该总是执行）
if (Test-Path $LogFile) {
    $LastRun = Get-Content $LogFile -ErrorAction SilentlyContinue
    if ($LastRun -eq $Today) {
        # 今天已经执行过，退出
        exit 0
    }
}

# 检查当前时间
$CurrentTime = Get-Date
$CurrentHour = $CurrentTime.Hour

# 如果是凌晨0点附近（0:00-0:05），直接执行
if ($CurrentHour -eq 0 -and $CurrentTime.Minute -le 5) {
    try {
        # 设置环境变量为00点触发器
        $env:TRIGGER_SOURCE = "触发器00"
        # 直接执行bat文件
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatFile`" admin" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory $ScriptDir
        exit $process.ExitCode
    } catch {
        Write-Host "执行BAT文件失败: $_"
        exit 1
    }
}

# 检查是否在预定义的触发器时间
$TriggerHours = @(3, 6, 12, 18, 21)
if ($TriggerHours -contains $CurrentHour) {
    # 其他时间检查空闲状态
    try {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public class IdleChecker {
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    
    public static TimeSpan GetIdleTime() {
        LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
        lastInputInfo.cbSize = (uint)Marshal.SizeOf(lastInputInfo);
        GetLastInputInfo(ref lastInputInfo);
        return TimeSpan.FromMilliseconds(Environment.TickCount - lastInputInfo.dwTime);
    }
}
'@

        $IdleTime = [IdleChecker]::GetIdleTime()
        if ($IdleTime.TotalMinutes -ge 3) {
            # 空闲超过3分钟，执行任务
            try {
                # 根据当前时间设置具体的触发器环境变量
                switch ($CurrentHour) {
                    3  { $env:TRIGGER_SOURCE = "触发器03" }
                    6  { $env:TRIGGER_SOURCE = "触发器06" }
                    12 { $env:TRIGGER_SOURCE = "触发器12" }
                    18 { $env:TRIGGER_SOURCE = "触发器18" }
                    21 { $env:TRIGGER_SOURCE = "触发器21" }
                    default { $env:TRIGGER_SOURCE = "触发器$($CurrentTime.ToString('HH'))" }
                }
                
                $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatFile`" admin" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory $ScriptDir
                exit $process.ExitCode
            } catch {
                Write-Host "执行BAT文件失败: $_"
                exit 1
            }
        } else {
            # 用户活跃，不执行
            exit 0
        }
    } catch {
        # 如果空闲检查失败，直接执行（避免阻塞）
        try {
            # 根据当前时间设置具体的触发器环境变量
            switch ($CurrentHour) {
                3  { $env:TRIGGER_SOURCE = "触发器03" }
                6  { $env:TRIGGER_SOURCE = "触发器06" }
                12 { $env:TRIGGER_SOURCE = "触发器12" }
                18 { $env:TRIGGER_SOURCE = "触发器18" }
                21 { $env:TRIGGER_SOURCE = "触发器21" }
                default { $env:TRIGGER_SOURCE = "触发器$($CurrentTime.ToString('HH'))" }
            }
            
            $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatFile`" admin" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory $ScriptDir
            exit $process.ExitCode
        } catch {
            Write-Host "执行BAT文件失败: $_"
            exit 1
        }
    }
}

# 如果不在触发器时间，正常退出
exit 0