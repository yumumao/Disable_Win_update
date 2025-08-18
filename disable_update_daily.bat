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

:: 检测使用的注册表文件版本
echo [%date% %time%] 检测注册表配置文件版本 >> "%LogFile%"
set "RegFileVersion=未知"
set "RegFileFeatures="

if exist "%~dp0disable_windows_update.reg" (
    :: 检测文件内容特征来判断版本
    findstr /i "GameDVR" "%~dp0disable_windows_update.reg" >nul 2>&1
    if !errorlevel! equ 0 (
        findstr /i "MicrosoftPCManager" "%~dp0disable_windows_update.reg" >nul 2>&1
        if !errorlevel! equ 0 (
            set "RegFileVersion=完整版"
            set "RegFileFeatures=Windows更新+电脑管家+游戏功能"
        ) else (
            set "RegFileVersion=无电脑管家版"
            set "RegFileFeatures=Windows更新+游戏功能"
        )
    ) else (
        findstr /i "MicrosoftPCManager" "%~dp0disable_windows_update.reg" >nul 2>&1
        if !errorlevel! equ 0 (
            set "RegFileVersion=无游戏版"
            set "RegFileFeatures=Windows更新+电脑管家"
        ) else (
            :: 检查是否包含基本的Windows更新设置
            findstr /i "wuauserv" "%~dp0disable_windows_update.reg" >nul 2>&1
            if !errorlevel! equ 0 (
                set "RegFileVersion=精简版"
                set "RegFileFeatures=仅Windows更新"
            ) else (
                set "RegFileVersion=自定义版"
                set "RegFileFeatures=用户自定义配置"
            )
        )
    )
    echo [%date% %time%]  └─检测到注册表文件：!RegFileVersion!（!RegFileFeatures!） >> "%LogFile%"
) else (
    set "RegFileVersion=文件缺失"
    set "RegFileFeatures=无配置文件"
    echo [%date% %time%]  └─错误：未找到disable_windows_update.reg文件 >> "%LogFile%"
)

:: 停止和禁用Windows更新相关服务
echo [%date% %time%] 停止和禁用Windows更新相关服务 >> "%LogFile%"

:: 先尝试停止关键服务
net stop WaaSMedicSvc >nul 2>&1
net stop DoSvc >nul 2>&1
net stop WpnService >nul 2>&1

for %%i in (wuauserv, UsoSvc, WaaSMedicSvc, DoSvc, WpnService) do (
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

echo [%date% %time%]  └─服务层面处理完成→将通过注册表确保设置生效 >> "%LogFile%"

:: 在导入注册表前先读取当前值
echo [%date% %time%] 读取导入前注册表状态 >> "%LogFile%"

:: 记录导入前的关键注册表值
set "BeforeWuauserv="
set "BeforeUsoSvc="
set "BeforeWaaSMedicSvc="
set "BeforeDoSvc="
set "BeforeWpnService="
set "BeforeNoAutoUpdate="
set "BeforeDeferFeature="
set "BeforeNoAutoReboot="
set "BeforeGameDVR="
set "BeforeGameBarEnabled="

for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start 2^>nul ^| find "Start" 2^>nul') do set "BeforeWuauserv=%%a"
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start 2^>nul ^| find "Start" 2^>nul') do set "BeforeUsoSvc=%%a"
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start 2^>nul ^| find "Start" 2^>nul') do set "BeforeWaaSMedicSvc=%%a"
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\DoSvc" /v Start 2^>nul ^| find "Start" 2^>nul') do set "BeforeDoSvc=%%a"
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\WpnService" /v Start 2^>nul ^| find "Start" 2^>nul') do set "BeforeWpnService=%%a"
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate 2^>nul ^| find "NoAutoUpdate" 2^>nul') do set "BeforeNoAutoUpdate=%%a"
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DeferFeatureUpdates 2^>nul ^| find "DeferFeatureUpdates" 2^>nul') do set "BeforeDeferFeature=%%a"
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers 2^>nul ^| find "NoAutoRebootWithLoggedOnUsers" 2^>nul') do set "BeforeNoAutoReboot=%%a"
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR 2^>nul ^| find "AllowGameDVR" 2^>nul') do set "BeforeGameDVR=%%a"
for /f "tokens=3" %%a in ('reg query "HKCU\System\GameConfigStore" /v GameDVR_Enabled 2^>nul ^| find "GameDVR_Enabled" 2^>nul') do set "BeforeGameBarEnabled=%%a"

:: 应用注册表设置（统一处理）
echo [%date% %time%] 应用注册表设置 >> "%LogFile%"
:: 导入注册表（这已经包含了所有必要的设置）
if exist "%~dp0disable_windows_update.reg" (
    regedit /s "%~dp0disable_windows_update.reg" >nul 2>&1
    set "reg_import_error=!errorlevel!"
    
    :: 检查regedit的返回码
    if !reg_import_error! equ 0 (
        echo [%date% %time%]  ├─注册表文件导入命令执行成功 >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ├─注册表文件导入命令执行失败，错误代码: !reg_import_error! >> "%LogFile%"
    )
) else (
    echo [%date% %time%]  ├─错误：注册表文件不存在，跳过注册表设置 >> "%LogFile%"
    set "reg_import_error=1"
)

:: 导入后读取当前值并与导入前对比
set "FailedCount=0"
set "ChangedCount=0"
set "Results[1]="
set "Results[2]="
set "Results[3]="
set "Results[4]="
set "Results[5]="
set "Results[6]="
set "Results[7]="
set "Results[8]="
set "Results[9]="
set "Results[10]="
set "Results[11]="

:: 检查wuauserv (Windows Update服务)
set "AfterWuauserv="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterWuauserv=%%a"
if "!AfterWuauserv!"=="0x4" (
    set "Results[1]=禁用Windows Update(wuauserv)[OK]"
    if not "!BeforeWuauserv!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[1]=禁用Windows Update(wuauserv)[FAIL-值:!AfterWuauserv!]"
    set /a FailedCount+=1
)

:: 检查UsoSvc (更新编排器服务)
set "AfterUsoSvc="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterUsoSvc=%%a"
if "!AfterUsoSvc!"=="0x4" (
    set "Results[2]=禁用更新编排器(UsoSvc)[OK]"
    if not "!BeforeUsoSvc!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[2]=禁用更新编排器(UsoSvc)[FAIL-值:!AfterUsoSvc!]"
    set /a FailedCount+=1
)

:: 检查WaaSMedicSvc (更新修复服务)
set "AfterWaaSMedicSvc="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterWaaSMedicSvc=%%a"
if "!AfterWaaSMedicSvc!"=="0x4" (
    set "Results[3]=禁用更新修复(WaaSMedicSvc)[OK]"
    if not "!BeforeWaaSMedicSvc!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[3]=禁用更新修复(WaaSMedicSvc)[FAIL-值:!AfterWaaSMedicSvc!]"
    set /a FailedCount+=1
)

:: 检查DoSvc (配送优化服务)
set "AfterDoSvc="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\DoSvc" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterDoSvc=%%a"
if "!AfterDoSvc!"=="0x4" (
    set "Results[4]=禁用配送优化(DoSvc)[OK]"
    if not "!BeforeDoSvc!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[4]=禁用配送优化(DoSvc)[FAIL-值:!AfterDoSvc!]"
    set /a FailedCount+=1
)

:: 检查WpnService (推送通知服务)
set "AfterWpnService="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\WpnService" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterWpnService=%%a"
if "!AfterWpnService!"=="0x4" (
    set "Results[5]=禁用推送通知(WpnService)[OK]"
    if not "!BeforeWpnService!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[5]=禁用推送通知(WpnService)[FAIL-值:!AfterWpnService!]"
    set /a FailedCount+=1
)

:: 检查自动更新策略
set "AfterNoAutoUpdate="
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate 2^>nul ^| find "NoAutoUpdate" 2^>nul') do set "AfterNoAutoUpdate=%%a"
if "!AfterNoAutoUpdate!"=="0x1" (
    set "Results[6]=禁用自动更新(NoAutoUpdate)[OK]"
    if not "!BeforeNoAutoUpdate!"=="0x1" set /a ChangedCount+=1
) else (
    set "Results[6]=禁用自动更新(NoAutoUpdate)[FAIL-值:!AfterNoAutoUpdate!]"
    set /a FailedCount+=1
)

:: 检查功能更新延迟
set "AfterDeferFeature="
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DeferFeatureUpdates 2^>nul ^| find "DeferFeatureUpdates" 2^>nul') do set "AfterDeferFeature=%%a"
if "!AfterDeferFeature!"=="0x1" (
    set "Results[7]=延迟功能更新(DeferFeature)[OK]"
    if not "!BeforeDeferFeature!"=="0x1" set /a ChangedCount+=1
) else (
    set "Results[7]=延迟功能更新(DeferFeature)[FAIL-值:!AfterDeferFeature!]"
    set /a FailedCount+=1
)

:: 检查重启策略
set "AfterNoAutoReboot="
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers 2^>nul ^| find "NoAutoRebootWithLoggedOnUsers" 2^>nul') do set "AfterNoAutoReboot=%%a"
if "!AfterNoAutoReboot!"=="0x1" (
    set "Results[8]=禁止强制重启(NoAutoReboot)[OK]"
    if not "!BeforeNoAutoReboot!"=="0x1" set /a ChangedCount+=1
) else (
    set "Results[8]=禁止强制重启(NoAutoReboot)[FAIL-值:!AfterNoAutoReboot!]"
    set /a FailedCount+=1
)

:: 检查FailureActions设置
reg query "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v FailureActions >nul 2>&1
set "failure_check_error=!errorlevel!"
if !failure_check_error! equ 0 (
    set "Results[9]=禁用修复服务自启动(FailureActions)[OK]"
) else (
    :: 如果不存在，尝试重新设置
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v FailureActions /t REG_BINARY /d 000000000000000000000000030000001400000000000000c0d4010000000000e09304000000000000000000 /f >nul 2>&1
    set "failure_add_error=!errorlevel!"
    if !failure_add_error! equ 0 (
        set "Results[9]=禁用修复服务自启动(FailureActions)[OK-重新设置]"
        set /a ChangedCount+=1
    ) else (
        set "Results[9]=禁用修复服务自启动(FailureActions)[FAIL-设置失败]"
        set /a FailedCount+=1
    )
)

:: 检查Game Bar禁用设置（仅在完整版或无电脑管家版时检查）
set "CheckGameFeatures=0"
if "!RegFileVersion!"=="完整版" set "CheckGameFeatures=1"
if "!RegFileVersion!"=="无电脑管家版" set "CheckGameFeatures=1"

if !CheckGameFeatures! equ 1 (
    :: 检查Game Bar录制功能
    set "AfterGameDVR="
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR 2^>nul ^| find "AllowGameDVR" 2^>nul') do set "AfterGameDVR=%%a"
    if "!AfterGameDVR!"=="0x0" (
        set "Results[10]=禁用Game Bar录制(GameDVR)[OK]"
        if not "!BeforeGameDVR!"=="0x0" set /a ChangedCount+=1
    ) else (
        set "Results[10]=禁用Game Bar录制(GameDVR)[FAIL-值:!AfterGameDVR!]"
        set /a FailedCount+=1
    )

    :: 检查Game Bar启用状态
    set "AfterGameBarEnabled="
    for /f "tokens=3" %%a in ('reg query "HKCU\System\GameConfigStore" /v GameDVR_Enabled 2^>nul ^| find "GameDVR_Enabled" 2^>nul') do set "AfterGameBarEnabled=%%a"
    if "!AfterGameBarEnabled!"=="0x0" (
        set "Results[11]=禁用Game Bar功能(GameBar)[OK]"
        if not "!BeforeGameBarEnabled!"=="0x0" set /a ChangedCount+=1
    ) else (
        set "Results[11]=禁用Game Bar功能(GameBar)[FAIL-值:!AfterGameBarEnabled!]"
        set /a FailedCount+=1
    )
) else (
    :: 不检查游戏功能时设置为跳过
    set "Results[10]=跳过Game Bar录制检查[SKIP-版本不包含]"
    set "Results[11]=跳过Game Bar功能检查[SKIP-版本不包含]"
)

:: 根据注册表文件版本确定检查项目数
set "TotalCheckItems=9"
if "!RegFileVersion!"=="完整版" set "TotalCheckItems=11"
if "!RegFileVersion!"=="无电脑管家版" set "TotalCheckItems=11"
if "!RegFileVersion!"=="无游戏版" set "TotalCheckItems=9"
if "!RegFileVersion!"=="精简版" set "TotalCheckItems=8"
if "!RegFileVersion!"=="文件缺失" set "TotalCheckItems=9"

:: 计算成功数 - 在所有检查完成后统一计算
set /a SuccessCount=!TotalCheckItems!-!FailedCount!

:: 确保只输出一行结果 - 使用明确的单一判断路径
if !FailedCount! equ 0 (
    :: 完全成功的情况
    if !ChangedCount! gtr 0 (
        echo [%date% %time%] 应用注册表设置：全部成功(!TotalCheckItems!/!TotalCheckItems!项成功，!ChangedCount!项实际变更） >> "%LogFile%"
    ) else (
        echo [%date% %time%] 应用注册表设置：全部成功(!TotalCheckItems!/!TotalCheckItems!项成功，0项实际变更-可能已设置） >> "%LogFile%"
    )
) else (
    :: 部分成功的情况
    if !ChangedCount! gtr 0 (
        echo [%date% %time%] 应用注册表设置：部分成功(!SuccessCount!/!TotalCheckItems!项成功，!ChangedCount!项实际变更） >> "%LogFile%"
    ) else (
        echo [%date% %time%] 应用注册表设置：部分成功(!SuccessCount!/!TotalCheckItems!项成功，0项实际变更-可能已设置） >> "%LogFile%"
    )
)

:: 输出详细结果（根据版本调整输出格式）
echo [%date% %time%]  ├─!Results[1]!；!Results[2]! >> "%LogFile%"
echo [%date% %time%]  ├─!Results[3]!；!Results[4]! >> "%LogFile%"
echo [%date% %time%]  ├─!Results[5]!；!Results[6]! >> "%LogFile%"
echo [%date% %time%]  ├─!Results[7]!；!Results[8]! >> "%LogFile%"

if !TotalCheckItems! geq 10 (
    echo [%date% %time%]  ├─!Results[9]!；!Results[10]! >> "%LogFile%"
    echo [%date% %time%]  └─!Results[11]! >> "%LogFile%"
) else (
    echo [%date% %time%]  └─!Results[9]! >> "%LogFile%"
)

:: 如果有特定的失败项目，输出变更对比信息
if !FailedCount! gtr 0 (
    echo [%date% %time%] 详细变更对比： >> "%LogFile%"
    if not "!BeforeWaaSMedicSvc!"=="!AfterWaaSMedicSvc!" echo [%date% %time%]  ├─WaaSMedicSvc: !BeforeWaaSMedicSvc! → !AfterWaaSMedicSvc! >> "%LogFile%"
    if not "!BeforeDoSvc!"=="!AfterDoSvc!" echo [%date% %time%]  ├─DoSvc: !BeforeDoSvc! → !AfterDoSvc! >> "%LogFile%"
    if not "!BeforeWuauserv!"=="!AfterWuauserv!" echo [%date% %time%]  ├─wuauserv: !BeforeWuauserv! → !AfterWuauserv! >> "%LogFile%"
    if not "!BeforeUsoSvc!"=="!AfterUsoSvc!" echo [%date% %time%]  ├─UsoSvc: !BeforeUsoSvc! → !AfterUsoSvc! >> "%LogFile%"
    if not "!BeforeWpnService!"=="!AfterWpnService!" echo [%date% %time%]  ├─WpnService: !BeforeWpnService! → !AfterWpnService! >> "%LogFile%"
    if !CheckGameFeatures! equ 1 (
        if not "!BeforeGameDVR!"=="!AfterGameDVR!" echo [%date% %time%]  ├─GameDVR: !BeforeGameDVR! → !AfterGameDVR! >> "%LogFile%"
        if not "!BeforeGameBarEnabled!"=="!AfterGameBarEnabled!" echo [%date% %time%]  └─GameBar: !BeforeGameBarEnabled! → !AfterGameBarEnabled! >> "%LogFile%"
    )
)

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

:: 阻止微软电脑管家安装（仅在完整版或无游戏版时执行）
set "CheckPCManager=0"
if "!RegFileVersion!"=="完整版" set "CheckPCManager=1"
if "!RegFileVersion!"=="无游戏版" set "CheckPCManager=1"

if !CheckPCManager! equ 1 (
    echo [%date% %time%] 阻止微软电脑管家 >> "%LogFile%"

    :: 检查并处理已安装的电脑管家
    set "PCManagerFound=0"
    set "RemovalResult="

    for /f "tokens=*" %%i in ('powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq 'Microsoft.MicrosoftPCManager'} | Select-Object -ExpandProperty PackageFullName" 2^>nul') do (
        set /a PCManagerFound+=1
        echo [%date% %time%]  ├─发现电脑管家包：%%i >> "%LogFile%"
        
        :: 尝试多种删除方法
        set "DeleteSuccess=0"
        
        :: 方法1：标准删除
        powershell -command "Remove-AppxPackage -Package '%%i'" >nul 2>&1
        if !errorlevel! equ 0 (
            set "DeleteSuccess=1"
            set "RemovalResult=标准删除成功"
        ) else (
            echo [%date% %time%]  ├─标准删除失败，错误代码: !errorlevel!，尝试强制删除 >> "%LogFile%"
            
            :: 方法2：强制删除当前用户
            powershell -command "Remove-AppxPackage -Package '%%i' -User $env:USERNAME" >nul 2>&1
            if !errorlevel! equ 0 (
                set "DeleteSuccess=1"
                set "RemovalResult=用户强制删除成功"
            ) else (
                :: 方法3：所有用户强制删除
                powershell -command "Remove-AppxPackage -Package '%%i' -AllUsers" >nul 2>&1
                if !errorlevel! equ 0 (
                    set "DeleteSuccess=1"
                    set "RemovalResult=全局强制删除成功"
                ) else (
                    :: 方法4：使用DISM删除
                    dism /online /remove-provisionedappxpackage /packagename:%%i >nul 2>&1
                    if !errorlevel! equ 0 (
                        set "DeleteSuccess=1"
                        set "RemovalResult=DISM删除成功"
                    ) else (
                        set "RemovalResult=所有删除方法均失败"
                    )
                )
            )
        )
        
        :: 验证删除结果
        powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.PackageFullName -eq '%%i'}" >nul 2>&1
        if !errorlevel! neq 0 (
            echo [%date% %time%]  ├─删除验证：包已不存在，删除成功 >> "%LogFile%"
            set "RemovalResult=!RemovalResult!（验证成功）"
        ) else (
            echo [%date% %time%]  ├─删除验证：包仍然存在，删除失败 >> "%LogFile%"
            set "RemovalResult=!RemovalResult!（验证失败-包仍存在）"
        )
    )

    :: 记录检查结果到同一行
    if !PCManagerFound! equ 0 (
        echo [%date% %time%]  ├─检查微软电脑管家安装状态：未安装 >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ├─检查微软电脑管家安装状态：已安装!PCManagerFound!个包→!RemovalResult! >> "%LogFile%"
    )

    :: 检查常见安装路径
    set "FolderFound=0"
    set "FolderResult="

    for %%p in ("%ProgramFiles%\Microsoft PC Manager", "%ProgramFiles(x86)%\Microsoft PC Manager", "%LocalAppData%\Microsoft\PCManager") do (
        if exist "%%p" (
            set /a FolderFound+=1
            rd /s /q "%%p" >nul 2>&1
            if not exist "%%p" (
                if defined FolderResult (
                    set "FolderResult=!FolderResult!；%%p删除成功"
                ) else (
                    set "FolderResult=发现程序文件夹：%%p→删除成功"
                )
            ) else (
                if defined FolderResult (
                    set "FolderResult=!FolderResult!；%%p删除失败"
                ) else (
                    set "FolderResult=发现程序文件夹：%%p→删除失败"
                )
            )
        )
    )

    :: 额外的清理措施
    set "ProvisionResult="
    set "RegistryResult="
    set "FolderNotFoundResult="

    :: 如果没有发现程序文件夹，设置结果用于合并输出
    if !FolderFound! equ 0 (
        set "FolderNotFoundResult=未发现程序文件夹安装"
    )

    :: 清理预安装包
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like '*MicrosoftPCManager*'} | Remove-AppxProvisionedPackage -Online" >nul 2>&1
    if !errorlevel! equ 0 (
        set "ProvisionResult=预安装包清理成功"
    ) else (
        set "ProvisionResult=预安装包无需清理或失败"
    )

    :: 清理注册表残留
    reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s 2>nul | find /i "PCManager" >nul 2>&1
    if !errorlevel! equ 0 (
        set "RegistryResult=发现并清理注册表残留"
        for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s 2^>nul ^| find /i "PCManager"') do (
            reg delete "%%k" /f >nul 2>&1
        )
    ) else (
        set "RegistryResult=未发现注册表残留"
    )

    :: 合并输出到一行
    if !FolderFound! equ 0 (
        echo [%date% %time%]  ├─执行额外清理措施：!FolderNotFoundResult!；!ProvisionResult!；!RegistryResult! >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ├─!FolderResult! >> "%LogFile%"
        echo [%date% %time%]  ├─执行额外清理措施：!ProvisionResult!；!RegistryResult! >> "%LogFile%"
    )

    :: 阻止消费者功能和应用商店自动下载配置
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d 1 /f >nul 2>&1
    set "reg_error1=!errorlevel!"
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" /v "AutoDownload" /t REG_DWORD /d 2 /f >nul 2>&1
    set "reg_error2=!errorlevel!"

    if !reg_error1! equ 0 if !reg_error2! equ 0 (
        echo [%date% %time%]  ├─配置阻止消费者功能和应用商店自动下载：配置成功 >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ├─配置阻止消费者功能和应用商店自动下载：配置失败，错误代码: !reg_error1!/!reg_error2! >> "%LogFile%"
    )

    :: 应用商店阻止策略配置
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.MicrosoftPCManager_8wekyb3d8bbwe" /f >nul 2>&1
    if !errorlevel! equ 0 (
        echo [%date% %time%]  ├─配置应用商店阻止策略：配置成功 >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ├─配置应用商店阻止策略：配置失败，错误代码: !errorlevel! >> "%LogFile%"
    )

    :: EdgeUpdate阻止策略配置
    reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v "InstallDefault" /t REG_DWORD /d 0 /f >nul 2>&1
    if !errorlevel! equ 0 (
        echo [%date% %time%]  ├─配置EdgeUpdate安装策略：配置成功 >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ├─配置EdgeUpdate安装策略：配置失败，错误代码: !errorlevel! >> "%LogFile%"
    )

    :: 检查并禁用相关服务
    set "ServiceFound=0"
    set "ServiceResult="

    for %%s in ("Microsoft PC Manager Service", "PCManager") do (
        sc query %%s >nul 2>&1
        if !errorlevel! equ 0 (
            set /a ServiceFound+=1
            sc config %%s start= disabled >nul 2>&1
            if !errorlevel! equ 0 (
                if defined ServiceResult (
                    set "ServiceResult=!ServiceResult!；%%s禁用成功"
                ) else (
                    set "ServiceResult=%%s禁用成功"
                )
            ) else (
                if defined ServiceResult (
                    set "ServiceResult=!ServiceResult!；%%s禁用失败，错误代码: !errorlevel!"
                ) else (
                    set "ServiceResult=%%s禁用失败，错误代码: !errorlevel!"
                )
            )
        )
    )

    :: 记录服务检查结果到同一行
    if !ServiceFound! equ 0 (
        echo [%date% %time%]  └─检查并禁用电脑管家相关服务：未发现相关服务 >> "%LogFile%"
    ) else (
        echo [%date% %time%]  └─检查并禁用电脑管家相关服务：!ServiceResult! >> "%LogFile%"
    )
) else (
    echo [%date% %time%] 跳过微软电脑管家检查（当前配置版本：!RegFileVersion!） >> "%LogFile%"
)

:: 阻止游戏助手和游戏功能（仅在完整版或无电脑管家版时执行）
if !CheckGameFeatures! equ 1 (
    echo [%date% %time%] 阻止微软游戏助手和游戏功能 >> "%LogFile%"

    :: 检查并处理已安装的游戏相关应用
    set "GameAppFound=0"
    set "GameAppRemovalResult="

    :: 搜索微软游戏助手 (GamingServices)
    for /f "tokens=*" %%i in ('powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq 'Microsoft.GamingServices'} | Select-Object -ExpandProperty PackageFullName" 2^>nul') do (
        set /a GameAppFound+=1
        echo [%date% %time%]  ├─发现微软游戏助手：%%i >> "%LogFile%"
        
        :: 尝试删除
        powershell -command "Remove-AppxPackage -Package '%%i'" >nul 2>&1
        if !errorlevel! equ 0 (
            set "GameAppRemovalResult=游戏助手删除成功"
        ) else (
            :: 强制删除
            powershell -command "Remove-AppxPackage -Package '%%i' -AllUsers" >nul 2>&1
            if !errorlevel! equ 0 (
                set "GameAppRemovalResult=游戏助手强制删除成功"
            ) else (
                set "GameAppRemovalResult=游戏助手删除失败"
            )
        )
    )

    :: 搜索Xbox Game Bar
    for /f "tokens=*" %%i in ('powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq 'Microsoft.XboxGamingOverlay'} | Select-Object -ExpandProperty PackageFullName" 2^>nul') do (
        set /a GameAppFound+=1
        echo [%date% %time%]  ├─发现Xbox Game Bar：%%i >> "%LogFile%"
        
        powershell -command "Remove-AppxPackage -Package '%%i'" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined GameAppRemovalResult (
                set "GameAppRemovalResult=!GameAppRemovalResult!；Xbox Game Bar删除成功"
            ) else (
                set "GameAppRemovalResult=Xbox Game Bar删除成功"
            )
        ) else (
            if defined GameAppRemovalResult (
                set "GameAppRemovalResult=!GameAppRemovalResult!；Xbox Game Bar删除失败"
            ) else (
                set "GameAppRemovalResult=Xbox Game Bar删除失败"
            )
        )
    )

    :: 搜索其他游戏相关应用
    for /f "tokens=*" %%i in ('powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.Name -like '*Gaming*' -and $_.Publisher -like '*Microsoft*' -and $_.Name -ne 'Microsoft.GamingServices' -and $_.Name -ne 'Microsoft.XboxGamingOverlay'} | Select-Object -ExpandProperty PackageFullName" 2^>nul') do (
        set /a GameAppFound+=1
        echo [%date% %time%]  ├─发现其他游戏应用：%%i >> "%LogFile%"
        
        powershell -command "Remove-AppxPackage -Package '%%i'" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined GameAppRemovalResult (
                set "GameAppRemovalResult=!GameAppRemovalResult!；其他游戏应用删除成功"
            ) else (
                set "GameAppRemovalResult=其他游戏应用删除成功"
            )
        ) else (
            if defined GameAppRemovalResult (
                set "GameAppRemovalResult=!GameAppRemovalResult!；其他游戏应用删除失败"
            ) else (
                set "GameAppRemovalResult=其他游戏应用删除失败"
            )
        )
    )

    :: 记录检查结果
    if !GameAppFound! equ 0 (
        echo [%date% %time%]  ├─检查游戏相关应用安装状态：未安装 >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ├─检查游戏相关应用安装状态：已安装!GameAppFound!个包→!GameAppRemovalResult! >> "%LogFile%"
    )

    :: 检查并删除游戏相关文件和文件夹
    set "GameFolderFound=0"
    set "GameFolderResult="

    :: 检查常见游戏助手相关路径
    for %%p in ("%LocalAppData%\Microsoft\GamingServices", "%ProgramData%\Microsoft\GamingServices") do (
        if exist "%%p" (
            set /a GameFolderFound+=1
            rd /s /q "%%p" >nul 2>&1
            if not exist "%%p" (
                if defined GameFolderResult (
                    set "GameFolderResult=!GameFolderResult!；%%p删除成功"
                ) else (
                    set "GameFolderResult=发现游戏文件夹：%%p→删除成功"
                )
            ) else (
                if defined GameFolderResult (
                    set "GameFolderResult=!GameFolderResult!；%%p删除失败"
                ) else (
                    set "GameFolderResult=发现游戏文件夹：%%p→删除失败"
                )
            )
        )
    )

    :: 清理预安装包
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like '*Gaming*' -or $_.DisplayName -like '*XboxGaming*'} | Remove-AppxProvisionedPackage -Online" >nul 2>&1
    set "GameProvisionResult="
    if !errorlevel! equ 0 (
        set "GameProvisionResult=游戏预安装包清理成功"
    ) else (
        set "GameProvisionResult=游戏预安装包无需清理"
    )

    :: 合并输出结果
    if !GameFolderFound! equ 0 (
        echo [%date% %time%]  ├─未发现游戏助手程序文件；!GameProvisionResult! >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ├─!GameFolderResult! >> "%LogFile%"
        echo [%date% %time%]  ├─!GameProvisionResult! >> "%LogFile%"
    )

    echo [%date% %time%]  └─游戏助手和游戏功能阻止配置完成（注册表设置已统一应用） >> "%LogFile%"
) else (
    echo [%date% %time%] 跳过游戏功能检查（当前配置版本：!RegFileVersion!） >> "%LogFile%"
)

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