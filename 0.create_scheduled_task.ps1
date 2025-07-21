[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Test
)

# 设置当前进程的执行策略
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# 日志记录函数
$LogFile = Join-Path $PSScriptRoot "task_creation_log.txt"
function Write-Log {
    param($Message, $Color = "White")
    $TimeStamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $Message -ForegroundColor $Color
}

# 任务名称和路径
$TaskName = "DisableWindowsUpdateDaily"
$ActualScriptPath = Join-Path $PSScriptRoot "disable_update_daily.bat"

# 卸载模式
if ($Uninstall) {
    Write-Log "开始卸载计划任务..." "Yellow"
    
    try {
        # 删除计划任务
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($ExistingTask) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Log "计划任务已删除" "Green"
        } else {
            Write-Log "未找到要删除的计划任务" "Yellow"
        }
        
        # 删除临时执行记录
        $TempLogFile = "$env:TEMP\DisableUpdate_LastRun.txt"
        if (Test-Path $TempLogFile) {
            Remove-Item $TempLogFile -Force
            Write-Log "临时执行记录已清除" "Green"
        }
        
        Write-Log "卸载完成！" "Green"
        
    } catch {
        Write-Log "卸载过程中出现错误: $_" "Red"
    }
    
    pause
    exit
}

# 检查是否以管理员身份运行，如果不是则自动提升权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "检测到需要管理员权限，正在请求提升权限..." "Yellow"
    
    try {
        # 保持原有参数
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
        if ($Test) { $arguments += " -Test" }
        if ($Uninstall) { $arguments += " -Uninstall" }
        
        Start-Process PowerShell -Argument $arguments -Verb RunAs -Wait
        exit
    } catch {
        Write-Log "无法获取管理员权限，请手动以管理员身份运行此脚本" "Red"
        Write-Log "或者右键点击PowerShell选择'以管理员身份运行'" "Red"
        pause
        exit
    }
}

# 显示分隔符（不记录到日志）
Write-Host "==========================================================================" -ForegroundColor Gray

# 在日志文件开头添加分隔符（不显示时间）
"==========================================================================" | Out-File -FilePath $LogFile -Append -Encoding UTF8

Write-Log "已获得管理员权限，开始创建计划任务..." "Green"

# 检查 disable_update_daily.bat 是否存在
if (-not (Test-Path $ActualScriptPath)) {
    Write-Log "错误: 找不到 disable_update_daily.bat 文件" "Red"
    Write-Log "请确保该文件与此脚本在同一目录下" "Red"
    Write-Log "当前目录: $PSScriptRoot" "Gray"
    pause
    exit
}

Write-Log "找到目标BAT文件: $ActualScriptPath" "Green"

# 删除已存在的任务（如果有）
try {
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ExistingTask) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Log "已清理旧的计划任务" "Gray"
    }
} catch {
    Write-Log "清理旧任务时出现问题（可能不存在旧任务）" "Gray"
}

# 创建任务动作（直接调用BAT文件）
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$ActualScriptPath`" admin" -WorkingDirectory $PSScriptRoot

# 创建触发器 - 增加开机启动
$TriggerBoot = New-ScheduledTaskTrigger -AtStartup  # 开机启动
$Trigger1 = New-ScheduledTaskTrigger -Daily -At "00:00"  # 凌晨0点
$Trigger2 = New-ScheduledTaskTrigger -Daily -At "03:00"  # 凌晨3点
$Trigger3 = New-ScheduledTaskTrigger -Daily -At "06:00"  # 早上6点
$Trigger4 = New-ScheduledTaskTrigger -Daily -At "12:00"  # 中午12点
$Trigger5 = New-ScheduledTaskTrigger -Daily -At "18:00"  # 下午6点
$Trigger6 = New-ScheduledTaskTrigger -Daily -At "21:00"  # 夜晚9点
$Triggers = @($TriggerBoot, $Trigger1, $Trigger2, $Trigger3, $Trigger4, $Trigger5, $Trigger6)

Write-Log "已配置 $($Triggers.Count) 个触发器（包含开机启动）" "Green"

# 创建任务设置
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -WakeToRun `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -RunOnlyIfNetworkAvailable:$false `
    -Hidden

# 创建任务主体（以SYSTEM身份运行）
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# 注册计划任务
try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal -Description "每日禁用Windows更新服务 - 多时间点执行（开机启动 + 定时检查）" -ErrorAction Stop
    Write-Log "计划任务创建成功！" "Green"
} catch {
    Write-Log "创建计划任务时出现错误: $_" "Red"
    pause
    exit
}

# 验证任务创建
Start-Sleep -Seconds 2
try {
    $CreatedTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Write-Log "任务验证成功 - 状态: $($CreatedTask.State)" "Green"
    
    # 获取任务详细信息
    $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($TaskInfo) {
        Write-Log "任务信息 - 上次运行: $($TaskInfo.LastRunTime), 下次运行: $($TaskInfo.NextRunTime)" "Cyan"
    }
    
    # 显示触发器信息
    $TaskTriggers = (Get-ScheduledTask -TaskName $TaskName).Triggers
    Write-Log "触发器配置:" "Cyan"
    foreach ($trigger in $TaskTriggers) {
        if ($trigger.CimClass.CimClassName -eq "MSFT_TaskBootTrigger") {
            Write-Log "   - 系统启动时" "Gray"
        } elseif ($trigger.CimClass.CimClassName -eq "MSFT_TaskDailyTrigger") {
            $startTime = $trigger.StartBoundary.Split('T')[1].Substring(0,5)
            Write-Log "   - 每日 $startTime" "Gray"
        }
    }
} catch {
    Write-Log "任务验证失败: $_" "Red"
}

# 测试模式
if ($Test) {
    Write-Log "测试模式：手动运行任务..." "Yellow"
    try {
        # 设置环境变量以标识这是测试运行
        [Environment]::SetEnvironmentVariable("TRIGGER_SOURCE", "PowerShell测试", "Process")
        
        Start-ScheduledTask -TaskName $TaskName
        Write-Log "测试任务已启动，请检查日志文件查看执行结果" "Green"
        Write-Log "BAT脚本日志: $PSScriptRoot\update_disable_log.txt" "Cyan"
        
        # 等待几秒钟，然后检查任务状态
        Start-Sleep -Seconds 3
        $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        Write-Log "测试后任务状态 - 上次运行: $($TaskInfo.LastRunTime), 结果: $($TaskInfo.LastTaskResult)" "Cyan"
        
    } catch {
        Write-Log "测试运行失败: $_" "Red"
    }
}

# 显示配置信息
Write-Host ""
Write-Log "==================== 任务配置信息 ====================" "Cyan"
Write-Log "任务名称: $TaskName" "Yellow"
Write-Log "目标脚本: $ActualScriptPath" "Yellow"
Write-Log "创建日志: $LogFile" "Yellow"
Write-Host ""
Write-Log "执行逻辑: " "Yellow"
Write-Log "  1. 系统启动时自动执行一次" "Cyan"
Write-Log "  2. 每天多个时间点检查（0:00, 3:00, 6:00, 12:00, 18:00, 21:00）" "Cyan"
Write-Log "  3. BAT文件内置重复检测，每天只执行一次" "Cyan"
Write-Log "  4. 以SYSTEM权限运行，无窗口显示" "Cyan"
Write-Log "  5. 会唤醒计算机执行任务" "Cyan"
Write-Log "  6. 任务隐藏，不在任务栏显示" "Cyan"
Write-Host ""
Write-Log "触发时间: 开机启动 + 0:00, 3:00, 6:00, 12:00, 18:00, 21:00" "Gray"
Write-Log "可在任务计划程序(taskschd.msc)中查看和管理此任务" "Yellow"
Write-Log "======================================================" "Cyan"

Write-Host ""
Write-Log "脚本执行完成！现在你可以：" "Green"
Write-Log "1. 在任务计划程序中查看创建的任务" "White"
Write-Log "2. 运行 '.\0.create_scheduled_task.ps1 -Test' 进行测试" "White"
Write-Log "3. 运行 '.\0.create_scheduled_task.ps1 -Uninstall' 卸载任务" "White"
Write-Log "4. 查看日志文件了解执行情况" "White"
Write-Log "   - 任务创建日志: $LogFile" "Gray"
Write-Log "   - BAT执行日志: $PSScriptRoot\update_disable_log.txt" "Gray"
Write-Log "   - 重复执行记录: $env:TEMP\DisableUpdate_LastRun.txt" "Gray"
# 在日志文件结尾添加分隔符（不显示时间）
"==========================================================================" | Out-File -FilePath $LogFile -Append -Encoding UTF8

pause