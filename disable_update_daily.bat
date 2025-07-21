@echo off
setlocal enabledelayedexpansion

set "LogFile=%~dp0update_disable_log.txt"

:: 检查是否以管理员身份运行
if not "%1"=="admin" (powershell start -verb runas '"%0"' admin & exit /b)

:: 记录今天的执行标记到临时文件（避免清空主日志）
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set "Today=%%a/%%b/%%c"
echo %Today% > "%TEMP%\DisableUpdate_LastRun.txt"

:: 检测触发器类型
set "TriggerInfo=手动"
if defined TRIGGER_SOURCE (
    set "TriggerInfo=%TRIGGER_SOURCE%"
    goto :TriggerIdentified
)

:: 检查系统启动时间
for /f %%i in ('powershell -command "(Get-Date) - (Get-WmiObject Win32_OperatingSystem).ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime) | Select-Object -ExpandProperty TotalMinutes"') do (
    if %%i LSS 10 (
        set "TriggerInfo=触发器系统启动"
        goto :TriggerIdentified
    )
)

:: 根据时间判断触发器类型
for /f "tokens=1-2 delims=: " %%a in ('time /t') do (
    set "CurrentHour=%%a"
)
set "CurrentHour=%CurrentHour: =%"
if "%CurrentHour:~0,1%"=="0" set "CurrentHour=%CurrentHour:~1%"

if "%CurrentHour%"=="0" set "TriggerInfo=触发器00"
if "%CurrentHour%"=="3" set "TriggerInfo=触发器03"
if "%CurrentHour%"=="6" set "TriggerInfo=触发器06"
if "%CurrentHour%"=="12" set "TriggerInfo=触发器12"
if "%CurrentHour%"=="18" set "TriggerInfo=触发器18"
if "%CurrentHour%"=="21" set "TriggerInfo=触发器21"

:TriggerIdentified

:: 日志开始
echo ================================================ >> "%LogFile%"
echo [%date% %time%] %TriggerInfo%-开始执行禁用Windows更新脚本 >> "%LogFile%"

:: 应用注册表设置
echo [%date% %time%] 开始应用注册表设置 >> "%LogFile%"
regedit /s "%~dp0disable_windows_update.reg"
if !errorlevel! equ 0 (
    echo [%date% %time%]  └─注册表设置应用成功 >> "%LogFile%"
) else (
    echo [%date% %time%]  └─注册表设置应用失败，错误代码: !errorlevel! >> "%LogFile%"
)
    
:: 停止和禁用服务
echo [%date% %time%] 停止和禁用Windows更新相关服务 >> "%LogFile%"

for %%i in (wuauserv, UsoSvc, WaaSMedicSvc) do (
    set "ServiceResult="
    
    :: 停止服务
    net stop %%i >nul 2>&1
    set "stop_error=!errorlevel!"
    if !stop_error! equ 0 (
        set "ServiceResult=服务停止成功"
    ) else if !stop_error! equ 2 (
        set "ServiceResult=服务不存在或已停止"
    ) else (
        set "ServiceResult=服务停止失败，错误代码: !stop_error!"
    )
    
    :: 禁用服务
    sc config %%i start= disabled >nul 2>&1
    set "config_error=!errorlevel!"
    if !config_error! equ 0 (
        set "ServiceResult=!ServiceResult!→服务禁用成功"
    ) else if !config_error! equ 5 (
        set "ServiceResult=!ServiceResult!→服务禁用失败（访问被拒绝）错误代码: !config_error!"
    ) else if !config_error! equ 1060 (
        set "ServiceResult=!ServiceResult!→服务不存在，错误代码: !config_error!"
    ) else (
        set "ServiceResult=!ServiceResult!→服务禁用失败，错误代码: !config_error!"
    )
    
    :: 写入单行日志
    echo [%date% %time%]  ├─处理%%i !ServiceResult! >> "%LogFile%"
    
    :: 清除失败操作设置
    sc failure %%i reset= 0 actions= "" >nul 2>&1
)

:: 通过注册表强制禁用WaaSMedicSvc
echo [%date% %time%]  ├─通过注册表强制禁用WaaSMedicSvc >> "%LogFile%"
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
if !errorlevel! equ 0 (
    echo [%date% %time%]  └─WaaSMedicSvc注册表禁用成功 >> "%LogFile%"
) else (
    echo [%date% %time%]  └─WaaSMedicSvc注册表禁用失败, 错误代码: !errorlevel! >> "%LogFile%"
)

:: 设置失败操作为空
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v FailureActions /t REG_BINARY /d 000000000000000000000000030000001400000000000000c0d4010000000000e09304000000000000000000 /f >nul 2>&1

:: 删除升级文件夹
if exist "C:\$WINDOWS.~BT" (
    echo [%date% %time%] 发现升级文件夹 C:\$WINDOWS.~BT，正在删除... >> "%LogFile%"
    rd /s /q "C:\$WINDOWS.~BT" >nul 2>&1
    if not exist "C:\$WINDOWS.~BT" (
        echo [%date% %time%]  └─升级文件夹$WINDOWS.~BT删除成功 >> "%LogFile%"
    ) else (
        echo [%date% %time%]  └─升级文件夹$WINDOWS.~BT删除失败 >> "%LogFile%"
    )
) else (
    echo [%date% %time%] 未发现升级文件夹$WINDOWS.~BT >> "%LogFile%"
)

:: 清理更新下载文件
echo [%date% %time%] 清理Windows更新下载文件 >> "%LogFile%"
if exist "C:\Windows\SoftwareDistribution" (
    erase /f /s /q C:\Windows\SoftwareDistribution\*.* >nul 2>&1
    rmdir /s /q C:\Windows\SoftwareDistribution >nul 2>&1
    if not exist "C:\Windows\SoftwareDistribution" (
        echo [%date% %time%]  └─SoftwareDistribution文件夹清理成功 >> "%LogFile%"
    ) else (
        echo [%date% %time%]  └─SoftwareDistribution文件夹清理部分成功 >> "%LogFile%"
    )
) else (
    echo [%date% %time%]  └─SoftwareDistribution文件夹不存在 >> "%LogFile%"
)

:: 显示完成消息
:: set "UserLoggedIn="
:: for /f "tokens=*" %%i in ('query user 2^>nul ^| find "Active"') do (
::     set "UserLoggedIn=1"
::     goto :FoundUser
:: )
:: :FoundUser
:: 
:: if defined UserLoggedIn (
::     echo [%date% %time%] 发现活动用户会话，显示完成提示 >> "%LogFile%"
::     powershell -WindowStyle Hidden -Command "try { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('已禁止Windows更新`n执行时间: %date% %time%`n启动方式: %TriggerInfo%', '任务完成', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) } catch { exit 0 }" >nul 2>&1
::     echo [%date% %time%] 已向用户显示完成提示 >> "%LogFile%"
:: ) else (
::     echo [%date% %time%] 未发现活动用户会话，跳过UI提示 >> "%LogFile%"
:: )

echo [%date% %time%] 脚本执行完成 >> "%LogFile%"

:: 日志清理处理
call :ProcessLogFile

echo ================================================ >> "%LogFile%"

exit /b 0

:ProcessLogFile
:: 处理日志文件：当超过5万行时，清理一半保留最新25000行
if exist "%LogFile%" (
    :: 检查行数
    for /f %%i in ('find /c /v "" ^< "%LogFile%"') do set "LineCount=%%i"
    
    :: 如果超过5万行，清理一半
    if !LineCount! gtr 50000 (
        echo [%date% %time%] 日志超过5万行(!LineCount!行)，清理一半保留最新25000行 >> "%LogFile%"
        :: 使用系统默认编码（ANSI）处理日志
        powershell -Command "(Get-Content '%LogFile%' -Encoding Default | Select-Object -Last 25000) | Set-Content '%LogFile%_temp' -Encoding Default" >nul 2>&1
        if exist "%LogFile%_temp" (
            move "%LogFile%_temp" "%LogFile%" >nul 2>&1
            echo [%date% %time%] 日志清理完成 >> "%LogFile%"
        ) else (
            echo [%date% %time%] 日志清理失败，临时文件未创建 >> "%LogFile%"
        )
    )
)
goto :eof

:: ===============================
:: 常见错误代码说明：
:: 0 = 成功
:: 1 = 一般错误
:: 2 = 系统找不到指定的文件/服务不存在
:: 5 = 访问被拒绝
:: 1056 = 服务实例已存在
:: 1060 = 指定的服务未安装  
:: 1062 = 服务未启动
:: 1072 = 服务已被标记为删除
:: 1073 = 服务已存在
:: ===============================