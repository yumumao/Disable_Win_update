@echo off
setlocal enabledelayedexpansion

set "LogFile=%~dp0update_reset_log.txt"

:: ����Ƿ��Թ���Ա�������
if not "%1"=="admin" (
    echo ��Ҫ����ԱȨ�����ָ�Windows���·���
    powershell start -verb runas '%0' admin
    exit /b
)

:: ��־��ʼ
echo ================================================ >> "%LogFile%"
echo [%date% %time%] ��ʼ�ָ�Windows���·��� >> "%LogFile%"

echo ���ڻָ�Windows���·������Ժ�...

:: �ָ�WaaSMedicSvc.dll�ļ����������������
echo [%date% %time%] ���WaaSMedicSvc.dll�ļ�״̬ >> "%LogFile%"
if exist "C:\Windows\System32\WaaSMedicSvc_BAK.dll" (
    if not exist "C:\Windows\System32\WaaSMedicSvc.dll" (
        echo [%date% %time%] ���ֱ���������WaaSMedicSvc_BAK.dll�����Իָ�... >> "%LogFile%"
        
        :: ��ȡ�ļ�����Ȩ���ָ�
        takeown /f "C:\Windows\System32\WaaSMedicSvc_BAK.dll" >nul 2>&1
        icacls "C:\Windows\System32\WaaSMedicSvc_BAK.dll" /grant *S-1-1-0:F >nul 2>&1
        rename "C:\Windows\System32\WaaSMedicSvc_BAK.dll" "WaaSMedicSvc.dll" >nul 2>&1
        
        if exist "C:\Windows\System32\WaaSMedicSvc.dll" (
            echo [%date% %time%] WaaSMedicSvc.dll�ָ��ɹ� >> "%LogFile%"
            echo WaaSMedicSvc.dll�ļ��ѻָ�
            
            :: �ָ��ļ�Ȩ��
            icacls "C:\Windows\System32\WaaSMedicSvc.dll" /setowner "NT SERVICE\TrustedInstaller" >nul 2>&1
            icacls "C:\Windows\System32\WaaSMedicSvc.dll" /remove *S-1-1-0 >nul 2>&1
        ) else (
            echo [%date% %time%] WaaSMedicSvc.dll�ָ�ʧ�� >> "%LogFile%"
            echo WaaSMedicSvc.dll�ļ��ָ�ʧ��
        )
    ) else (
        echo [%date% %time%] WaaSMedicSvc.dll�ļ��Ѵ��ڣ�ɾ�������ļ� >> "%LogFile%"
        del "C:\Windows\System32\WaaSMedicSvc_BAK.dll" >nul 2>&1
        echo �������ظ��ı����ļ�
    )
) else (
    echo [%date% %time%] δ����WaaSMedicSvc_BAK.dll�����ļ� >> "%LogFile%"
    echo δ������Ҫ�ָ���DLL�ļ�
)

:: ���ú���������
echo [%date% %time%] ��ʼ���ò�����Windows������ط��� >> "%LogFile%"

for %%i in (wuauserv, UsoSvc, WaaSMedicSvc) do (
    echo [%date% %time%] �ָ�����: %%i >> "%LogFile%"
    echo ���ڻָ�����: %%i
    
    :: ���÷���
    sc config %%i start= auto >nul 2>&1
    set "config_error=!errorlevel!"
    if !config_error! equ 0 (
        echo [%date% %time%] %%i �������óɹ� >> "%LogFile%"
    ) else if !config_error! equ 1060 (
        echo [%date% %time%] %%i ���񲻴��ڣ��������: !config_error! >> "%LogFile%"
    ) else (
        echo [%date% %time%] %%i ��������ʧ�ܣ��������: !config_error! >> "%LogFile%"
    )
    
    :: ��������
    net start %%i >nul 2>&1
    set "start_error=!errorlevel!"
    if !start_error! equ 0 (
        echo [%date% %time%] %%i ���������ɹ� >> "%LogFile%"
    ) else if !start_error! equ 2 (
        echo [%date% %time%] %%i ��������ʧ�ܣ����񲻴��ڣ����������: !start_error! >> "%LogFile%"
    ) else (
        echo [%date% %time%] %%i ��������ʧ�ܣ��������: !start_error! >> "%LogFile%"
    )
    
    :: �ָ�ʧ�ܲ�������ΪĬ��
    sc failure %%i reset= 86400 actions= restart/60000/restart/60000/restart/60000 >nul 2>&1
)

:: ͨ��ע���ָ�WaaSMedicSvc
echo [%date% %time%] ͨ��ע���ָ�WaaSMedicSvc�Զ����� >> "%LogFile%"
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
if !errorlevel! equ 0 (
    echo [%date% %time%] WaaSMedicSvcע���ָ��ɹ� >> "%LogFile%"
) else (
    echo [%date% %time%] WaaSMedicSvcע���ָ�ʧ�ܣ��������: !errorlevel! >> "%LogFile%"
)

:: ɾ�����ø��µ�ע�������
echo [%date% %time%] ɾ�����ø��µ�ע������� >> "%LogFile%"
echo ��������ע����������...

:: ɾ��Windows Update��صĽ�������
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v CachedAUOptions /f >nul 2>&1

:: ɾ��Windows Store�Զ����½���
reg delete "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /f >nul 2>&1

:: ɾ�����������Զ����½���
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" /v SearchOrderConfig /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v DontSearchWindowsUpdate /f >nul 2>&1

echo [%date% %time%] ע���������� >> "%LogFile%"

:: �ؽ�Windows Update���
echo [%date% %time%] ����ע��Windows Update��� >> "%LogFile%"
echo ��������ע��Windows Update���...

:: ����ע��ؼ�DLL
regsvr32 /s wuapi.dll
regsvr32 /s wuaueng.dll
regsvr32 /s wuaueng1.dll
regsvr32 /s wucltui.dll
regsvr32 /s wups.dll
regsvr32 /s wups2.dll
regsvr32 /s wuweb.dll

echo [%date% %time%] Windows Update�������ע����� >> "%LogFile%"

:: �ؽ�SoftwareDistribution�ļ���
echo [%date% %time%] �ؽ�SoftwareDistribution�ļ��� >> "%LogFile%"
if not exist "C:\Windows\SoftwareDistribution" (
    echo �����ؽ�SoftwareDistribution�ļ���...
    mkdir "C:\Windows\SoftwareDistribution" >nul 2>&1
    if exist "C:\Windows\SoftwareDistribution" (
        echo [%date% %time%] SoftwareDistribution�ļ����ؽ��ɹ� >> "%LogFile%"
    ) else (
        echo [%date% %time%] SoftwareDistribution�ļ����ؽ�ʧ�� >> "%LogFile%"
    )
)

:: ɾ��ִ�б���ļ�
if exist "%TEMP%\DisableUpdate_LastRun.txt" (
    del "%TEMP%\DisableUpdate_LastRun.txt" >nul 2>&1
    echo [%date% %time%] ɾ�����ø���ִ�б�� >> "%LogFile%"
)

:: ǿ�Ƽ�����
echo [%date% %time%] ����Windows Update��� >> "%LogFile%"
echo ���ڴ������¼��...
powershell -Command "try { (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow() } catch { Write-Host 'Update check trigger failed' }" >nul 2>&1

:: �����ʾ
echo [%date% %time%] Windows���·���ָ���� >> "%LogFile%"
echo.
echo ================================
echo Windows���·���ָ���ɣ�
echo.
echo ����ɵĲ�����
echo - �ָ���WaaSMedicSvc.dll�ļ���������������
echo - ����������Windows������ط���
echo - �����˽��ø��µ�ע�������  
echo - ����ע����Windows Update���
echo - �ؽ���SoftwareDistribution�ļ���
echo - ������Windows Update���
echo.
echo ���������������ȷ�����и�����Ч
echo ================================

:: ѯ���Ƿ�����
echo [%date% %time%] ѯ���û��Ƿ����� >> "%LogFile%"
set /p restart="�Ƿ����������������(Y/N): "
if /i "%restart%"=="Y" (
    echo [%date% %time%] �û�ѡ����������� >> "%LogFile%"
    echo ���������10�������...
    shutdown /r /t 10 /c "Windows���·���ָ���ɣ�������Ч"
) else (
    echo [%date% %time%] �û�ѡ���Ժ����� >> "%LogFile%"
    echo ���Ժ��ֶ��������������ɻָ�����
)

echo ================================================ >> "%LogFile%"

:: ��ʾ��־�ļ�λ��
echo.
echo ��ϸ��־�ѱ��浽: %LogFile%
pause

exit /b 0