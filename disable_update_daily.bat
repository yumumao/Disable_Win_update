@echo off
setlocal enabledelayedexpansion

set "LogFile=%~dp0update_disable_log.txt"

:: ����Ƿ��Թ���Ա�������
if not "%1"=="admin" (powershell start -verb runas '"%0"' admin & exit /b)

:: ��¼�����ִ�б�ǵ���ʱ�ļ��������������־��
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set "Today=%%a/%%b/%%c"
echo %Today% > "%TEMP%\DisableUpdate_LastRun.txt"

:: ��ⴥ��������
set "TriggerInfo=�ֶ�"
if defined TRIGGER_SOURCE (
    set "TriggerInfo=%TRIGGER_SOURCE%"
    goto :TriggerIdentified
)

:: ���ϵͳ����ʱ��
for /f %%i in ('powershell -command "(Get-Date) - (Get-WmiObject Win32_OperatingSystem).ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime) | Select-Object -ExpandProperty TotalMinutes"') do (
    if %%i LSS 10 (
        set "TriggerInfo=������ϵͳ����"
        goto :TriggerIdentified
    )
)

:: ����ʱ���жϴ���������
for /f "tokens=1-2 delims=: " %%a in ('time /t') do (
    set "CurrentHour=%%a"
)
set "CurrentHour=%CurrentHour: =%"
if "%CurrentHour:~0,1%"=="0" set "CurrentHour=%CurrentHour:~1%"

if "%CurrentHour%"=="0" set "TriggerInfo=������00"
if "%CurrentHour%"=="3" set "TriggerInfo=������03"
if "%CurrentHour%"=="6" set "TriggerInfo=������06"
if "%CurrentHour%"=="12" set "TriggerInfo=������12"
if "%CurrentHour%"=="18" set "TriggerInfo=������18"
if "%CurrentHour%"=="21" set "TriggerInfo=������21"

:TriggerIdentified

:: ��־��ʼ
echo ================================================ >> "%LogFile%"
echo [%date% %time%] %TriggerInfo%-��ʼִ�н���Windows���½ű� >> "%LogFile%"

:: Ӧ��ע�������
echo [%date% %time%] ��ʼӦ��ע������� >> "%LogFile%"
regedit /s "%~dp0disable_windows_update.reg"
if !errorlevel! equ 0 (
    echo [%date% %time%]  ����ע�������Ӧ�óɹ� >> "%LogFile%"
) else (
    echo [%date% %time%]  ����ע�������Ӧ��ʧ�ܣ��������: !errorlevel! >> "%LogFile%"
)
    
:: ֹͣ�ͽ��÷���
echo [%date% %time%] ֹͣ�ͽ���Windows������ط��� >> "%LogFile%"

for %%i in (wuauserv, UsoSvc, WaaSMedicSvc) do (
    set "ServiceResult="
    
    :: ֹͣ����
    net stop %%i >nul 2>&1
    set "stop_error=!errorlevel!"
    if !stop_error! equ 0 (
        set "ServiceResult=����ֹͣ�ɹ�"
    ) else if !stop_error! equ 2 (
        set "ServiceResult=���񲻴��ڻ���ֹͣ"
    ) else (
        set "ServiceResult=����ֹͣʧ�ܣ��������: !stop_error!"
    )
    
    :: ���÷���
    sc config %%i start= disabled >nul 2>&1
    set "config_error=!errorlevel!"
    if !config_error! equ 0 (
        set "ServiceResult=!ServiceResult!��������óɹ�"
    ) else if !config_error! equ 5 (
        set "ServiceResult=!ServiceResult!���������ʧ�ܣ����ʱ��ܾ����������: !config_error!"
    ) else if !config_error! equ 1060 (
        set "ServiceResult=!ServiceResult!�����񲻴��ڣ��������: !config_error!"
    ) else (
        set "ServiceResult=!ServiceResult!���������ʧ�ܣ��������: !config_error!"
    )
    
    :: д�뵥����־
    echo [%date% %time%]  ��������%%i !ServiceResult! >> "%LogFile%"
    
    :: ���ʧ�ܲ�������
    sc failure %%i reset= 0 actions= "" >nul 2>&1
)

:: ͨ��ע���ǿ�ƽ���WaaSMedicSvc
echo [%date% %time%]  ����ͨ��ע���ǿ�ƽ���WaaSMedicSvc >> "%LogFile%"
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
if !errorlevel! equ 0 (
    echo [%date% %time%]  ����WaaSMedicSvcע�����óɹ� >> "%LogFile%"
) else (
    echo [%date% %time%]  ����WaaSMedicSvcע������ʧ��, �������: !errorlevel! >> "%LogFile%"
)

:: ����ʧ�ܲ���Ϊ��
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v FailureActions /t REG_BINARY /d 000000000000000000000000030000001400000000000000c0d4010000000000e09304000000000000000000 /f >nul 2>&1

:: ɾ�������ļ���
if exist "C:\$WINDOWS.~BT" (
    echo [%date% %time%] ���������ļ��� C:\$WINDOWS.~BT������ɾ��... >> "%LogFile%"
    rd /s /q "C:\$WINDOWS.~BT" >nul 2>&1
    if not exist "C:\$WINDOWS.~BT" (
        echo [%date% %time%]  ���������ļ���$WINDOWS.~BTɾ���ɹ� >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ���������ļ���$WINDOWS.~BTɾ��ʧ�� >> "%LogFile%"
    )
) else (
    echo [%date% %time%] δ���������ļ���$WINDOWS.~BT >> "%LogFile%"
)

:: ������������ļ�
echo [%date% %time%] ����Windows���������ļ� >> "%LogFile%"
if exist "C:\Windows\SoftwareDistribution" (
    erase /f /s /q C:\Windows\SoftwareDistribution\*.* >nul 2>&1
    rmdir /s /q C:\Windows\SoftwareDistribution >nul 2>&1
    if not exist "C:\Windows\SoftwareDistribution" (
        echo [%date% %time%]  ����SoftwareDistribution�ļ�������ɹ� >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ����SoftwareDistribution�ļ��������ֳɹ� >> "%LogFile%"
    )
) else (
    echo [%date% %time%]  ����SoftwareDistribution�ļ��в����� >> "%LogFile%"
)

:: ��ʾ�����Ϣ
:: set "UserLoggedIn="
:: for /f "tokens=*" %%i in ('query user 2^>nul ^| find "Active"') do (
::     set "UserLoggedIn=1"
::     goto :FoundUser
:: )
:: :FoundUser
:: 
:: if defined UserLoggedIn (
::     echo [%date% %time%] ���ֻ�û��Ự����ʾ�����ʾ >> "%LogFile%"
::     powershell -WindowStyle Hidden -Command "try { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('�ѽ�ֹWindows����`nִ��ʱ��: %date% %time%`n������ʽ: %TriggerInfo%', '�������', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) } catch { exit 0 }" >nul 2>&1
::     echo [%date% %time%] �����û���ʾ�����ʾ >> "%LogFile%"
:: ) else (
::     echo [%date% %time%] δ���ֻ�û��Ự������UI��ʾ >> "%LogFile%"
:: )

echo [%date% %time%] �ű�ִ����� >> "%LogFile%"

:: ��־������
call :ProcessLogFile

echo ================================================ >> "%LogFile%"

exit /b 0

:ProcessLogFile
:: ������־�ļ���������5����ʱ������һ�뱣������25000��
if exist "%LogFile%" (
    :: �������
    for /f %%i in ('find /c /v "" ^< "%LogFile%"') do set "LineCount=%%i"
    
    :: �������5���У�����һ��
    if !LineCount! gtr 50000 (
        echo [%date% %time%] ��־����5����(!LineCount!��)������һ�뱣������25000�� >> "%LogFile%"
        :: ʹ��ϵͳĬ�ϱ��루ANSI��������־
        powershell -Command "(Get-Content '%LogFile%' -Encoding Default | Select-Object -Last 25000) | Set-Content '%LogFile%_temp' -Encoding Default" >nul 2>&1
        if exist "%LogFile%_temp" (
            move "%LogFile%_temp" "%LogFile%" >nul 2>&1
            echo [%date% %time%] ��־������� >> "%LogFile%"
        ) else (
            echo [%date% %time%] ��־����ʧ�ܣ���ʱ�ļ�δ���� >> "%LogFile%"
        )
    )
)
goto :eof

:: ===============================
:: �����������˵����
:: 0 = �ɹ�
:: 1 = һ�����
:: 2 = ϵͳ�Ҳ���ָ�����ļ�/���񲻴���
:: 5 = ���ʱ��ܾ�
:: 1056 = ����ʵ���Ѵ���
:: 1060 = ָ���ķ���δ��װ  
:: 1062 = ����δ����
:: 1072 = �����ѱ����Ϊɾ��
:: 1073 = �����Ѵ���
:: ===============================