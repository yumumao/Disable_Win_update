# 设置当前进程的执行策略
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# 检查是否以管理员身份运行，如果不是则自动提升权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "检测到需要管理员权限，正在请求提升权限..." -ForegroundColor Yellow
    
    try {
        # 自动以管理员身份重新启动脚本
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
        Start-Process PowerShell -Argument $arguments -Verb RunAs -Wait
        exit
    } catch {
        Write-Host "无法获取管理员权限，请手动以管理员身份运行此脚本" -ForegroundColor Red
        Write-Host "或者右键点击PowerShell选择'以管理员身份运行'" -ForegroundColor Red
        pause
        exit
    }
}

Write-Host "已获得管理员权限，开始创建计划任务..." -ForegroundColor Green

$TaskName = "DisableWindowsUpdateDaily"
$WrapperScriptPath = Join-Path $PSScriptRoot "wrapper_script.ps1"
$ActualScriptPath = Join-Path $PSScriptRoot "disable_update_daily.bat"

# 检查 disable_update_daily.bat 是否存在
if (-not (Test-Path $ActualScriptPath)) {
    Write-Host "错误: 找不到 disable_update_daily.bat 文件" -ForegroundColor Red
    Write-Host "请确保该文件与此脚本在同一目录下" -ForegroundColor Red
    pause
    exit
}

# 创建包装脚本
$WrapperScript = @"
# 设置执行策略
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# 检查今天是否已经执行过
`$LogFile = "`$env:TEMP\DisableUpdate_LastRun.txt"
`$Today = Get-Date -Format "M/d/yyyy"

if (Test-Path `$LogFile) {
    `$LastRun = Get-Content `$LogFile -ErrorAction SilentlyContinue
    if (`$LastRun -eq `$Today) {
        # 今天已经执行过，退出
        exit 0
    }
}

# 检查当前时间
`$CurrentTime = Get-Date
`$CurrentHour = `$CurrentTime.Hour

# 如果是凌晨0点附近（0:00-0:05），直接执行
if (`$CurrentHour -eq 0 -and `$CurrentTime.Minute -le 5) {
    try {
        # 直接执行bat文件
        `$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ```"$ActualScriptPath```"" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory "$PSScriptRoot"
        exit `$process.ExitCode
    } catch {
        exit 1
    }
}

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

    `$IdleTime = [IdleChecker]::GetIdleTime()
    if (`$IdleTime.TotalMinutes -ge 3) {
        # 空闲超过3分钟，执行任务
        try {
            `$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ```"$ActualScriptPath```"" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory "$PSScriptRoot"
            exit `$process.ExitCode
        } catch {
            exit 1
        }
    }
} catch {
    # 如果空闲检查失败，直接执行（避免阻塞）
    try {
        `$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ```"$ActualScriptPath```"" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory "$PSScriptRoot"
        exit `$process.ExitCode
    } catch {
        exit 1
    }
}

# 如果没有满足执行条件，正常退出
exit 0
"@

# 保存包装脚本
$WrapperScript | Out-File -FilePath $WrapperScriptPath -Encoding UTF8

# 删除已存在的任务（如果有）
try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "已清理旧的计划任务（如果存在）" -ForegroundColor Gray
} catch {
    Write-Host "清理旧任务时出现问题（可能不存在旧任务）" -ForegroundColor Gray
}

# 创建任务动作（使用包装脚本）
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File `"$WrapperScriptPath`""

# 创建触发器 - 增加凌晨3点和夜晚21点
$Trigger1 = New-ScheduledTaskTrigger -Daily -At "00:00"  # 凌晨0点（强制执行）
$Trigger2 = New-ScheduledTaskTrigger -Daily -At "03:00"  # 凌晨3点
$Trigger3 = New-ScheduledTaskTrigger -Daily -At "06:00"  # 早上6点
$Trigger4 = New-ScheduledTaskTrigger -Daily -At "12:00"  # 中午12点
$Trigger5 = New-ScheduledTaskTrigger -Daily -At "18:00"  # 下午6点
$Trigger6 = New-ScheduledTaskTrigger -Daily -At "21:00"  # 夜晚9点
$Triggers = @($Trigger1, $Trigger2, $Trigger3, $Trigger4, $Trigger5, $Trigger6)

# 创建任务设置
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -WakeToRun `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

# 创建任务主体（以SYSTEM身份运行）
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# 注册计划任务
try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal -Description "每日禁用Windows更新服务 - 智能执行（多时间点检查）" -ErrorAction Stop
    Write-Host "? 计划任务创建成功！" -ForegroundColor Green
} catch {
    Write-Host "? 创建计划任务时出现错误: $_" -ForegroundColor Red
    pause
    exit
}

Write-Host ""
Write-Host "==================== 任务配置信息 ====================" -ForegroundColor Cyan
Write-Host "任务名称: $TaskName" -ForegroundColor Yellow
Write-Host "目标脚本: $ActualScriptPath" -ForegroundColor Yellow
Write-Host "包装脚本: $WrapperScriptPath" -ForegroundColor Yellow
Write-Host "" -ForegroundColor White
Write-Host "执行逻辑: " -ForegroundColor Yellow
Write-Host "  1. 每天凌晨0:00强制执行 disable_update_daily.bat" -ForegroundColor Cyan
Write-Host "  2. 多个时间点检查（3:00, 6:00, 12:00, 18:00, 21:00）" -ForegroundColor Cyan
Write-Host "  3. 非凌晨时段需要空闲3分钟才执行" -ForegroundColor Cyan
Write-Host "  4. 每天只会执行一次（通过日志文件控制）" -ForegroundColor Cyan
Write-Host "  5. 会唤醒计算机执行任务" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White
Write-Host "执行时间点: 0:00（强制）, 3:00, 6:00, 12:00, 18:00, 21:00" -ForegroundColor Gray
Write-Host "可在任务计划程序中查看和管理此任务" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "脚本执行完成！现在你可以：" -ForegroundColor Green
Write-Host "1. 在任务计划程序中查看创建的任务" -ForegroundColor White
Write-Host "2. 手动运行任务进行测试" -ForegroundColor White
Write-Host "3. 查看日志文件了解执行情况" -ForegroundColor White

pause