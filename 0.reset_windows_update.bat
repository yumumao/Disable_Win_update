@echo off
setlocal enabledelayedexpansion

set "LogFile=%~dp0update_reset_log.txt"

:: 检查是否以管理员身份运行
if not "%1"=="admin" (
    echo 需要管理员权限来恢复Windows更新服务
    powershell start -verb runas '%0' admin
    exit /b
)

:: 日志开始
echo ================================================ >> "%LogFile%"
echo [%date% %time%] 开始恢复Windows更新服务 >> "%LogFile%"

echo 正在恢复Windows更新服务，请稍候...

:: 恢复WaaSMedicSvc.dll文件（如果被重命名）
echo [%date% %time%] 检查WaaSMedicSvc.dll文件状态 >> "%LogFile%"
if exist "C:\Windows\System32\WaaSMedicSvc_BAK.dll" (
    if not exist "C:\Windows\System32\WaaSMedicSvc.dll" (
        echo [%date% %time%] 发现被重命名的WaaSMedicSvc_BAK.dll，尝试恢复... >> "%LogFile%"
        
        :: 获取文件所有权并恢复
        takeown /f "C:\Windows\System32\WaaSMedicSvc_BAK.dll" >nul 2>&1
        icacls "C:\Windows\System32\WaaSMedicSvc_BAK.dll" /grant *S-1-1-0:F >nul 2>&1
        rename "C:\Windows\System32\WaaSMedicSvc_BAK.dll" "WaaSMedicSvc.dll" >nul 2>&1
        
        if exist "C:\Windows\System32\WaaSMedicSvc.dll" (
            echo [%date% %time%] WaaSMedicSvc.dll恢复成功 >> "%LogFile%"
            echo WaaSMedicSvc.dll文件已恢复
            
            :: 恢复文件权限
            icacls "C:\Windows\System32\WaaSMedicSvc.dll" /setowner "NT SERVICE\TrustedInstaller" >nul 2>&1
            icacls "C:\Windows\System32\WaaSMedicSvc.dll" /remove *S-1-1-0 >nul 2>&1
        ) else (
            echo [%date% %time%] WaaSMedicSvc.dll恢复失败 >> "%LogFile%"
            echo WaaSMedicSvc.dll文件恢复失败
        )
    ) else (
        echo [%date% %time%] WaaSMedicSvc.dll文件已存在，删除备份文件 >> "%LogFile%"
        del "C:\Windows\System32\WaaSMedicSvc_BAK.dll" >nul 2>&1
        echo 清理了重复的备份文件
    )
) else (
    echo [%date% %time%] 未发现WaaSMedicSvc_BAK.dll备份文件 >> "%LogFile%"
    echo 未发现需要恢复的DLL文件
)

:: 启用和启动服务
echo [%date% %time%] 开始启用并启动Windows更新相关服务 >> "%LogFile%"

for %%i in (wuauserv, UsoSvc, WaaSMedicSvc) do (
    echo [%date% %time%] 恢复服务: %%i >> "%LogFile%"
    echo 正在恢复服务: %%i
    
    :: 启用服务
    sc config %%i start= auto >nul 2>&1
    set "config_error=!errorlevel!"
    if !config_error! equ 0 (
        echo [%date% %time%] %%i 服务启用成功 >> "%LogFile%"
    ) else if !config_error! equ 1060 (
        echo [%date% %time%] %%i 服务不存在，错误代码: !config_error! >> "%LogFile%"
    ) else (
        echo [%date% %time%] %%i 服务启用失败，错误代码: !config_error! >> "%LogFile%"
    )
    
    :: 启动服务
    net start %%i >nul 2>&1
    set "start_error=!errorlevel!"
    if !start_error! equ 0 (
        echo [%date% %time%] %%i 服务启动成功 >> "%LogFile%"
    ) else if !start_error! equ 2 (
        echo [%date% %time%] %%i 服务启动失败（服务不存在），错误代码: !start_error! >> "%LogFile%"
    ) else (
        echo [%date% %time%] %%i 服务启动失败，错误代码: !start_error! >> "%LogFile%"
    )
    
    :: 恢复失败操作设置为默认
    sc failure %%i reset= 86400 actions= restart/60000/restart/60000/restart/60000 >nul 2>&1
)

:: 通过注册表恢复WaaSMedicSvc
echo [%date% %time%] 通过注册表恢复WaaSMedicSvc自动启动 >> "%LogFile%"
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
if !errorlevel! equ 0 (
    echo [%date% %time%] WaaSMedicSvc注册表恢复成功 >> "%LogFile%"
) else (
    echo [%date% %time%] WaaSMedicSvc注册表恢复失败，错误代码: !errorlevel! >> "%LogFile%"
)

:: 删除禁用更新的注册表设置
echo [%date% %time%] 删除禁用更新的注册表设置 >> "%LogFile%"
echo 正在清理注册表禁用设置...

:: 删除Windows Update相关的禁用设置
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v CachedAUOptions /f >nul 2>&1

:: 删除Windows Store自动更新禁用
reg delete "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /f >nul 2>&1

:: 删除驱动程序自动更新禁用
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" /v SearchOrderConfig /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v DontSearchWindowsUpdate /f >nul 2>&1

echo [%date% %time%] 注册表清理完成 >> "%LogFile%"

:: 重建Windows Update组件
echo [%date% %time%] 重新注册Windows Update组件 >> "%LogFile%"
echo 正在重新注册Windows Update组件...

:: 重新注册关键DLL
regsvr32 /s wuapi.dll
regsvr32 /s wuaueng.dll
regsvr32 /s wuaueng1.dll
regsvr32 /s wucltui.dll
regsvr32 /s wups.dll
regsvr32 /s wups2.dll
regsvr32 /s wuweb.dll

echo [%date% %time%] Windows Update组件重新注册完成 >> "%LogFile%"

:: 重建SoftwareDistribution文件夹
echo [%date% %time%] 重建SoftwareDistribution文件夹 >> "%LogFile%"
if not exist "C:\Windows\SoftwareDistribution" (
    echo 正在重建SoftwareDistribution文件夹...
    mkdir "C:\Windows\SoftwareDistribution" >nul 2>&1
    if exist "C:\Windows\SoftwareDistribution" (
        echo [%date% %time%] SoftwareDistribution文件夹重建成功 >> "%LogFile%"
    ) else (
        echo [%date% %time%] SoftwareDistribution文件夹重建失败 >> "%LogFile%"
    )
)

:: 删除执行标记文件
if exist "%TEMP%\DisableUpdate_LastRun.txt" (
    del "%TEMP%\DisableUpdate_LastRun.txt" >nul 2>&1
    echo [%date% %time%] 删除禁用更新执行标记 >> "%LogFile%"
)

:: 强制检查更新
echo [%date% %time%] 触发Windows Update检查 >> "%LogFile%"
echo 正在触发更新检查...
powershell -Command "try { (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow() } catch { Write-Host 'Update check trigger failed' }" >nul 2>&1

:: 完成提示
echo [%date% %time%] Windows更新服务恢复完成 >> "%LogFile%"
echo.
echo ================================
echo Windows更新服务恢复完成！
echo.
echo 已完成的操作：
echo - 恢复了WaaSMedicSvc.dll文件（如有重命名）
echo - 启用了所有Windows更新相关服务
echo - 清理了禁用更新的注册表设置  
echo - 重新注册了Windows Update组件
echo - 重建了SoftwareDistribution文件夹
echo - 触发了Windows Update检查
echo.
echo 建议重启计算机以确保所有更改生效
echo ================================

:: 询问是否重启
echo [%date% %time%] 询问用户是否重启 >> "%LogFile%"
set /p restart="是否现在重启计算机？(Y/N): "
if /i "%restart%"=="Y" (
    echo [%date% %time%] 用户选择重启计算机 >> "%LogFile%"
    echo 计算机将在10秒后重启...
    shutdown /r /t 10 /c "Windows更新服务恢复完成，重启生效"
) else (
    echo [%date% %time%] 用户选择稍后重启 >> "%LogFile%"
    echo 请稍后手动重启计算机以完成恢复过程
)

echo ================================================ >> "%LogFile%"

:: 显示日志文件位置
echo.
echo 详细日志已保存到: %LogFile%
pause

exit /b 0