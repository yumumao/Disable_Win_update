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

:: ���ʹ�õ�ע����ļ��汾
echo [%date% %time%] ���ע��������ļ��汾 >> "%LogFile%"
set "RegFileVersion=δ֪"
set "RegFileFeatures="

if exist "%~dp0disable_windows_update.reg" (
    :: ����ļ������������жϰ汾
    findstr /i "GameDVR" "%~dp0disable_windows_update.reg" >nul 2>&1
    if !errorlevel! equ 0 (
        findstr /i "MicrosoftPCManager" "%~dp0disable_windows_update.reg" >nul 2>&1
        if !errorlevel! equ 0 (
            set "RegFileVersion=������"
            set "RegFileFeatures=Windows����+���Թܼ�+��Ϸ����"
        ) else (
            set "RegFileVersion=�޵��ԹܼҰ�"
            set "RegFileFeatures=Windows����+��Ϸ����"
        )
    ) else (
        findstr /i "MicrosoftPCManager" "%~dp0disable_windows_update.reg" >nul 2>&1
        if !errorlevel! equ 0 (
            set "RegFileVersion=����Ϸ��"
            set "RegFileFeatures=Windows����+���Թܼ�"
        ) else (
            :: ����Ƿ����������Windows��������
            findstr /i "wuauserv" "%~dp0disable_windows_update.reg" >nul 2>&1
            if !errorlevel! equ 0 (
                set "RegFileVersion=�����"
                set "RegFileFeatures=��Windows����"
            ) else (
                set "RegFileVersion=�Զ����"
                set "RegFileFeatures=�û��Զ�������"
            )
        )
    )
    echo [%date% %time%]  ������⵽ע����ļ���!RegFileVersion!��!RegFileFeatures!�� >> "%LogFile%"
) else (
    set "RegFileVersion=�ļ�ȱʧ"
    set "RegFileFeatures=�������ļ�"
    echo [%date% %time%]  ��������δ�ҵ�disable_windows_update.reg�ļ� >> "%LogFile%"
)

:: ֹͣ�ͽ���Windows������ط���
echo [%date% %time%] ֹͣ�ͽ���Windows������ط��� >> "%LogFile%"

:: �ȳ���ֹͣ�ؼ�����
net stop WaaSMedicSvc >nul 2>&1
net stop DoSvc >nul 2>&1
net stop WpnService >nul 2>&1

for %%i in (wuauserv, UsoSvc, WaaSMedicSvc, DoSvc, WpnService) do (
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

echo [%date% %time%]  ����������洦����ɡ���ͨ��ע���ȷ��������Ч >> "%LogFile%"

:: �ڵ���ע���ǰ�ȶ�ȡ��ǰֵ
echo [%date% %time%] ��ȡ����ǰע���״̬ >> "%LogFile%"

:: ��¼����ǰ�Ĺؼ�ע���ֵ
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

:: Ӧ��ע������ã�ͳһ����
echo [%date% %time%] Ӧ��ע������� >> "%LogFile%"
:: ����ע������Ѿ����������б�Ҫ�����ã�
if exist "%~dp0disable_windows_update.reg" (
    regedit /s "%~dp0disable_windows_update.reg" >nul 2>&1
    set "reg_import_error=!errorlevel!"
    
    :: ���regedit�ķ�����
    if !reg_import_error! equ 0 (
        echo [%date% %time%]  ����ע����ļ���������ִ�гɹ� >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ����ע����ļ���������ִ��ʧ�ܣ��������: !reg_import_error! >> "%LogFile%"
    )
) else (
    echo [%date% %time%]  ��������ע����ļ������ڣ�����ע������� >> "%LogFile%"
    set "reg_import_error=1"
)

:: ������ȡ��ǰֵ���뵼��ǰ�Ա�
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

:: ���wuauserv (Windows Update����)
set "AfterWuauserv="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterWuauserv=%%a"
if "!AfterWuauserv!"=="0x4" (
    set "Results[1]=����Windows Update(wuauserv)[OK]"
    if not "!BeforeWuauserv!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[1]=����Windows Update(wuauserv)[FAIL-ֵ:!AfterWuauserv!]"
    set /a FailedCount+=1
)

:: ���UsoSvc (���±���������)
set "AfterUsoSvc="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterUsoSvc=%%a"
if "!AfterUsoSvc!"=="0x4" (
    set "Results[2]=���ø��±�����(UsoSvc)[OK]"
    if not "!BeforeUsoSvc!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[2]=���ø��±�����(UsoSvc)[FAIL-ֵ:!AfterUsoSvc!]"
    set /a FailedCount+=1
)

:: ���WaaSMedicSvc (�����޸�����)
set "AfterWaaSMedicSvc="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterWaaSMedicSvc=%%a"
if "!AfterWaaSMedicSvc!"=="0x4" (
    set "Results[3]=���ø����޸�(WaaSMedicSvc)[OK]"
    if not "!BeforeWaaSMedicSvc!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[3]=���ø����޸�(WaaSMedicSvc)[FAIL-ֵ:!AfterWaaSMedicSvc!]"
    set /a FailedCount+=1
)

:: ���DoSvc (�����Ż�����)
set "AfterDoSvc="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\DoSvc" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterDoSvc=%%a"
if "!AfterDoSvc!"=="0x4" (
    set "Results[4]=���������Ż�(DoSvc)[OK]"
    if not "!BeforeDoSvc!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[4]=���������Ż�(DoSvc)[FAIL-ֵ:!AfterDoSvc!]"
    set /a FailedCount+=1
)

:: ���WpnService (����֪ͨ����)
set "AfterWpnService="
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\WpnService" /v Start 2^>nul ^| find "Start" 2^>nul') do set "AfterWpnService=%%a"
if "!AfterWpnService!"=="0x4" (
    set "Results[5]=��������֪ͨ(WpnService)[OK]"
    if not "!BeforeWpnService!"=="0x4" set /a ChangedCount+=1
) else (
    set "Results[5]=��������֪ͨ(WpnService)[FAIL-ֵ:!AfterWpnService!]"
    set /a FailedCount+=1
)

:: ����Զ����²���
set "AfterNoAutoUpdate="
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate 2^>nul ^| find "NoAutoUpdate" 2^>nul') do set "AfterNoAutoUpdate=%%a"
if "!AfterNoAutoUpdate!"=="0x1" (
    set "Results[6]=�����Զ�����(NoAutoUpdate)[OK]"
    if not "!BeforeNoAutoUpdate!"=="0x1" set /a ChangedCount+=1
) else (
    set "Results[6]=�����Զ�����(NoAutoUpdate)[FAIL-ֵ:!AfterNoAutoUpdate!]"
    set /a FailedCount+=1
)

:: ��鹦�ܸ����ӳ�
set "AfterDeferFeature="
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DeferFeatureUpdates 2^>nul ^| find "DeferFeatureUpdates" 2^>nul') do set "AfterDeferFeature=%%a"
if "!AfterDeferFeature!"=="0x1" (
    set "Results[7]=�ӳٹ��ܸ���(DeferFeature)[OK]"
    if not "!BeforeDeferFeature!"=="0x1" set /a ChangedCount+=1
) else (
    set "Results[7]=�ӳٹ��ܸ���(DeferFeature)[FAIL-ֵ:!AfterDeferFeature!]"
    set /a FailedCount+=1
)

:: �����������
set "AfterNoAutoReboot="
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers 2^>nul ^| find "NoAutoRebootWithLoggedOnUsers" 2^>nul') do set "AfterNoAutoReboot=%%a"
if "!AfterNoAutoReboot!"=="0x1" (
    set "Results[8]=��ֹǿ������(NoAutoReboot)[OK]"
    if not "!BeforeNoAutoReboot!"=="0x1" set /a ChangedCount+=1
) else (
    set "Results[8]=��ֹǿ������(NoAutoReboot)[FAIL-ֵ:!AfterNoAutoReboot!]"
    set /a FailedCount+=1
)

:: ���FailureActions����
reg query "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v FailureActions >nul 2>&1
set "failure_check_error=!errorlevel!"
if !failure_check_error! equ 0 (
    set "Results[9]=�����޸�����������(FailureActions)[OK]"
) else (
    :: ��������ڣ�������������
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v FailureActions /t REG_BINARY /d 000000000000000000000000030000001400000000000000c0d4010000000000e09304000000000000000000 /f >nul 2>&1
    set "failure_add_error=!errorlevel!"
    if !failure_add_error! equ 0 (
        set "Results[9]=�����޸�����������(FailureActions)[OK-��������]"
        set /a ChangedCount+=1
    ) else (
        set "Results[9]=�����޸�����������(FailureActions)[FAIL-����ʧ��]"
        set /a FailedCount+=1
    )
)

:: ���Game Bar�������ã�������������޵��ԹܼҰ�ʱ��飩
set "CheckGameFeatures=0"
if "!RegFileVersion!"=="������" set "CheckGameFeatures=1"
if "!RegFileVersion!"=="�޵��ԹܼҰ�" set "CheckGameFeatures=1"

if !CheckGameFeatures! equ 1 (
    :: ���Game Bar¼�ƹ���
    set "AfterGameDVR="
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR 2^>nul ^| find "AllowGameDVR" 2^>nul') do set "AfterGameDVR=%%a"
    if "!AfterGameDVR!"=="0x0" (
        set "Results[10]=����Game Bar¼��(GameDVR)[OK]"
        if not "!BeforeGameDVR!"=="0x0" set /a ChangedCount+=1
    ) else (
        set "Results[10]=����Game Bar¼��(GameDVR)[FAIL-ֵ:!AfterGameDVR!]"
        set /a FailedCount+=1
    )

    :: ���Game Bar����״̬
    set "AfterGameBarEnabled="
    for /f "tokens=3" %%a in ('reg query "HKCU\System\GameConfigStore" /v GameDVR_Enabled 2^>nul ^| find "GameDVR_Enabled" 2^>nul') do set "AfterGameBarEnabled=%%a"
    if "!AfterGameBarEnabled!"=="0x0" (
        set "Results[11]=����Game Bar����(GameBar)[OK]"
        if not "!BeforeGameBarEnabled!"=="0x0" set /a ChangedCount+=1
    ) else (
        set "Results[11]=����Game Bar����(GameBar)[FAIL-ֵ:!AfterGameBarEnabled!]"
        set /a FailedCount+=1
    )
) else (
    :: �������Ϸ����ʱ����Ϊ����
    set "Results[10]=����Game Bar¼�Ƽ��[SKIP-�汾������]"
    set "Results[11]=����Game Bar���ܼ��[SKIP-�汾������]"
)

:: ����ע����ļ��汾ȷ�������Ŀ��
set "TotalCheckItems=9"
if "!RegFileVersion!"=="������" set "TotalCheckItems=11"
if "!RegFileVersion!"=="�޵��ԹܼҰ�" set "TotalCheckItems=11"
if "!RegFileVersion!"=="����Ϸ��" set "TotalCheckItems=9"
if "!RegFileVersion!"=="�����" set "TotalCheckItems=8"
if "!RegFileVersion!"=="�ļ�ȱʧ" set "TotalCheckItems=9"

:: ����ɹ��� - �����м����ɺ�ͳһ����
set /a SuccessCount=!TotalCheckItems!-!FailedCount!

:: ȷ��ֻ���һ�н�� - ʹ����ȷ�ĵ�һ�ж�·��
if !FailedCount! equ 0 (
    :: ��ȫ�ɹ������
    if !ChangedCount! gtr 0 (
        echo [%date% %time%] Ӧ��ע������ã�ȫ���ɹ�(!TotalCheckItems!/!TotalCheckItems!��ɹ���!ChangedCount!��ʵ�ʱ���� >> "%LogFile%"
    ) else (
        echo [%date% %time%] Ӧ��ע������ã�ȫ���ɹ�(!TotalCheckItems!/!TotalCheckItems!��ɹ���0��ʵ�ʱ��-���������ã� >> "%LogFile%"
    )
) else (
    :: ���ֳɹ������
    if !ChangedCount! gtr 0 (
        echo [%date% %time%] Ӧ��ע������ã����ֳɹ�(!SuccessCount!/!TotalCheckItems!��ɹ���!ChangedCount!��ʵ�ʱ���� >> "%LogFile%"
    ) else (
        echo [%date% %time%] Ӧ��ע������ã����ֳɹ�(!SuccessCount!/!TotalCheckItems!��ɹ���0��ʵ�ʱ��-���������ã� >> "%LogFile%"
    )
)

:: �����ϸ��������ݰ汾���������ʽ��
echo [%date% %time%]  ����!Results[1]!��!Results[2]! >> "%LogFile%"
echo [%date% %time%]  ����!Results[3]!��!Results[4]! >> "%LogFile%"
echo [%date% %time%]  ����!Results[5]!��!Results[6]! >> "%LogFile%"
echo [%date% %time%]  ����!Results[7]!��!Results[8]! >> "%LogFile%"

if !TotalCheckItems! geq 10 (
    echo [%date% %time%]  ����!Results[9]!��!Results[10]! >> "%LogFile%"
    echo [%date% %time%]  ����!Results[11]! >> "%LogFile%"
) else (
    echo [%date% %time%]  ����!Results[9]! >> "%LogFile%"
)

:: ������ض���ʧ����Ŀ���������Ա���Ϣ
if !FailedCount! gtr 0 (
    echo [%date% %time%] ��ϸ����Աȣ� >> "%LogFile%"
    if not "!BeforeWaaSMedicSvc!"=="!AfterWaaSMedicSvc!" echo [%date% %time%]  ����WaaSMedicSvc: !BeforeWaaSMedicSvc! �� !AfterWaaSMedicSvc! >> "%LogFile%"
    if not "!BeforeDoSvc!"=="!AfterDoSvc!" echo [%date% %time%]  ����DoSvc: !BeforeDoSvc! �� !AfterDoSvc! >> "%LogFile%"
    if not "!BeforeWuauserv!"=="!AfterWuauserv!" echo [%date% %time%]  ����wuauserv: !BeforeWuauserv! �� !AfterWuauserv! >> "%LogFile%"
    if not "!BeforeUsoSvc!"=="!AfterUsoSvc!" echo [%date% %time%]  ����UsoSvc: !BeforeUsoSvc! �� !AfterUsoSvc! >> "%LogFile%"
    if not "!BeforeWpnService!"=="!AfterWpnService!" echo [%date% %time%]  ����WpnService: !BeforeWpnService! �� !AfterWpnService! >> "%LogFile%"
    if !CheckGameFeatures! equ 1 (
        if not "!BeforeGameDVR!"=="!AfterGameDVR!" echo [%date% %time%]  ����GameDVR: !BeforeGameDVR! �� !AfterGameDVR! >> "%LogFile%"
        if not "!BeforeGameBarEnabled!"=="!AfterGameBarEnabled!" echo [%date% %time%]  ����GameBar: !BeforeGameBarEnabled! �� !AfterGameBarEnabled! >> "%LogFile%"
    )
)

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

:: ��ֹ΢����ԹܼҰ�װ�����������������Ϸ��ʱִ�У�
set "CheckPCManager=0"
if "!RegFileVersion!"=="������" set "CheckPCManager=1"
if "!RegFileVersion!"=="����Ϸ��" set "CheckPCManager=1"

if !CheckPCManager! equ 1 (
    echo [%date% %time%] ��ֹ΢����Թܼ� >> "%LogFile%"

    :: ��鲢�����Ѱ�װ�ĵ��Թܼ�
    set "PCManagerFound=0"
    set "RemovalResult="

    for /f "tokens=*" %%i in ('powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq 'Microsoft.MicrosoftPCManager'} | Select-Object -ExpandProperty PackageFullName" 2^>nul') do (
        set /a PCManagerFound+=1
        echo [%date% %time%]  �������ֵ��ԹܼҰ���%%i >> "%LogFile%"
        
        :: ���Զ���ɾ������
        set "DeleteSuccess=0"
        
        :: ����1����׼ɾ��
        powershell -command "Remove-AppxPackage -Package '%%i'" >nul 2>&1
        if !errorlevel! equ 0 (
            set "DeleteSuccess=1"
            set "RemovalResult=��׼ɾ���ɹ�"
        ) else (
            echo [%date% %time%]  ������׼ɾ��ʧ�ܣ��������: !errorlevel!������ǿ��ɾ�� >> "%LogFile%"
            
            :: ����2��ǿ��ɾ����ǰ�û�
            powershell -command "Remove-AppxPackage -Package '%%i' -User $env:USERNAME" >nul 2>&1
            if !errorlevel! equ 0 (
                set "DeleteSuccess=1"
                set "RemovalResult=�û�ǿ��ɾ���ɹ�"
            ) else (
                :: ����3�������û�ǿ��ɾ��
                powershell -command "Remove-AppxPackage -Package '%%i' -AllUsers" >nul 2>&1
                if !errorlevel! equ 0 (
                    set "DeleteSuccess=1"
                    set "RemovalResult=ȫ��ǿ��ɾ���ɹ�"
                ) else (
                    :: ����4��ʹ��DISMɾ��
                    dism /online /remove-provisionedappxpackage /packagename:%%i >nul 2>&1
                    if !errorlevel! equ 0 (
                        set "DeleteSuccess=1"
                        set "RemovalResult=DISMɾ���ɹ�"
                    ) else (
                        set "RemovalResult=����ɾ��������ʧ��"
                    )
                )
            )
        )
        
        :: ��֤ɾ�����
        powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.PackageFullName -eq '%%i'}" >nul 2>&1
        if !errorlevel! neq 0 (
            echo [%date% %time%]  ����ɾ����֤�����Ѳ����ڣ�ɾ���ɹ� >> "%LogFile%"
            set "RemovalResult=!RemovalResult!����֤�ɹ���"
        ) else (
            echo [%date% %time%]  ����ɾ����֤������Ȼ���ڣ�ɾ��ʧ�� >> "%LogFile%"
            set "RemovalResult=!RemovalResult!����֤ʧ��-���Դ��ڣ�"
        )
    )

    :: ��¼�������ͬһ��
    if !PCManagerFound! equ 0 (
        echo [%date% %time%]  �������΢����ԹܼҰ�װ״̬��δ��װ >> "%LogFile%"
    ) else (
        echo [%date% %time%]  �������΢����ԹܼҰ�װ״̬���Ѱ�װ!PCManagerFound!������!RemovalResult! >> "%LogFile%"
    )

    :: ��鳣����װ·��
    set "FolderFound=0"
    set "FolderResult="

    for %%p in ("%ProgramFiles%\Microsoft PC Manager", "%ProgramFiles(x86)%\Microsoft PC Manager", "%LocalAppData%\Microsoft\PCManager") do (
        if exist "%%p" (
            set /a FolderFound+=1
            rd /s /q "%%p" >nul 2>&1
            if not exist "%%p" (
                if defined FolderResult (
                    set "FolderResult=!FolderResult!��%%pɾ���ɹ�"
                ) else (
                    set "FolderResult=���ֳ����ļ��У�%%p��ɾ���ɹ�"
                )
            ) else (
                if defined FolderResult (
                    set "FolderResult=!FolderResult!��%%pɾ��ʧ��"
                ) else (
                    set "FolderResult=���ֳ����ļ��У�%%p��ɾ��ʧ��"
                )
            )
        )
    )

    :: ����������ʩ
    set "ProvisionResult="
    set "RegistryResult="
    set "FolderNotFoundResult="

    :: ���û�з��ֳ����ļ��У����ý�����ںϲ����
    if !FolderFound! equ 0 (
        set "FolderNotFoundResult=δ���ֳ����ļ��а�װ"
    )

    :: ����Ԥ��װ��
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like '*MicrosoftPCManager*'} | Remove-AppxProvisionedPackage -Online" >nul 2>&1
    if !errorlevel! equ 0 (
        set "ProvisionResult=Ԥ��װ������ɹ�"
    ) else (
        set "ProvisionResult=Ԥ��װ�����������ʧ��"
    )

    :: ����ע������
    reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s 2>nul | find /i "PCManager" >nul 2>&1
    if !errorlevel! equ 0 (
        set "RegistryResult=���ֲ�����ע������"
        for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s 2^>nul ^| find /i "PCManager"') do (
            reg delete "%%k" /f >nul 2>&1
        )
    ) else (
        set "RegistryResult=δ����ע������"
    )

    :: �ϲ������һ��
    if !FolderFound! equ 0 (
        echo [%date% %time%]  ����ִ�ж��������ʩ��!FolderNotFoundResult!��!ProvisionResult!��!RegistryResult! >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ����!FolderResult! >> "%LogFile%"
        echo [%date% %time%]  ����ִ�ж��������ʩ��!ProvisionResult!��!RegistryResult! >> "%LogFile%"
    )

    :: ��ֹ�����߹��ܺ�Ӧ���̵��Զ���������
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d 1 /f >nul 2>&1
    set "reg_error1=!errorlevel!"
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" /v "AutoDownload" /t REG_DWORD /d 2 /f >nul 2>&1
    set "reg_error2=!errorlevel!"

    if !reg_error1! equ 0 if !reg_error2! equ 0 (
        echo [%date% %time%]  ����������ֹ�����߹��ܺ�Ӧ���̵��Զ����أ����óɹ� >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ����������ֹ�����߹��ܺ�Ӧ���̵��Զ����أ�����ʧ�ܣ��������: !reg_error1!/!reg_error2! >> "%LogFile%"
    )

    :: Ӧ���̵���ֹ��������
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.MicrosoftPCManager_8wekyb3d8bbwe" /f >nul 2>&1
    if !errorlevel! equ 0 (
        echo [%date% %time%]  ��������Ӧ���̵���ֹ���ԣ����óɹ� >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ��������Ӧ���̵���ֹ���ԣ�����ʧ�ܣ��������: !errorlevel! >> "%LogFile%"
    )

    :: EdgeUpdate��ֹ��������
    reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v "InstallDefault" /t REG_DWORD /d 0 /f >nul 2>&1
    if !errorlevel! equ 0 (
        echo [%date% %time%]  ��������EdgeUpdate��װ���ԣ����óɹ� >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ��������EdgeUpdate��װ���ԣ�����ʧ�ܣ��������: !errorlevel! >> "%LogFile%"
    )

    :: ��鲢������ط���
    set "ServiceFound=0"
    set "ServiceResult="

    for %%s in ("Microsoft PC Manager Service", "PCManager") do (
        sc query %%s >nul 2>&1
        if !errorlevel! equ 0 (
            set /a ServiceFound+=1
            sc config %%s start= disabled >nul 2>&1
            if !errorlevel! equ 0 (
                if defined ServiceResult (
                    set "ServiceResult=!ServiceResult!��%%s���óɹ�"
                ) else (
                    set "ServiceResult=%%s���óɹ�"
                )
            ) else (
                if defined ServiceResult (
                    set "ServiceResult=!ServiceResult!��%%s����ʧ�ܣ��������: !errorlevel!"
                ) else (
                    set "ServiceResult=%%s����ʧ�ܣ��������: !errorlevel!"
                )
            )
        )
    )

    :: ��¼����������ͬһ��
    if !ServiceFound! equ 0 (
        echo [%date% %time%]  ������鲢���õ��Թܼ���ط���δ������ط��� >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ������鲢���õ��Թܼ���ط���!ServiceResult! >> "%LogFile%"
    )
) else (
    echo [%date% %time%] ����΢����ԹܼҼ�飨��ǰ���ð汾��!RegFileVersion!�� >> "%LogFile%"
)

:: ��ֹ��Ϸ���ֺ���Ϸ���ܣ�������������޵��ԹܼҰ�ʱִ�У�
if !CheckGameFeatures! equ 1 (
    echo [%date% %time%] ��ֹ΢����Ϸ���ֺ���Ϸ���� >> "%LogFile%"

    :: ��鲢�����Ѱ�װ����Ϸ���Ӧ��
    set "GameAppFound=0"
    set "GameAppRemovalResult="

    :: ����΢����Ϸ���� (GamingServices)
    for /f "tokens=*" %%i in ('powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq 'Microsoft.GamingServices'} | Select-Object -ExpandProperty PackageFullName" 2^>nul') do (
        set /a GameAppFound+=1
        echo [%date% %time%]  ��������΢����Ϸ���֣�%%i >> "%LogFile%"
        
        :: ����ɾ��
        powershell -command "Remove-AppxPackage -Package '%%i'" >nul 2>&1
        if !errorlevel! equ 0 (
            set "GameAppRemovalResult=��Ϸ����ɾ���ɹ�"
        ) else (
            :: ǿ��ɾ��
            powershell -command "Remove-AppxPackage -Package '%%i' -AllUsers" >nul 2>&1
            if !errorlevel! equ 0 (
                set "GameAppRemovalResult=��Ϸ����ǿ��ɾ���ɹ�"
            ) else (
                set "GameAppRemovalResult=��Ϸ����ɾ��ʧ��"
            )
        )
    )

    :: ����Xbox Game Bar
    for /f "tokens=*" %%i in ('powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq 'Microsoft.XboxGamingOverlay'} | Select-Object -ExpandProperty PackageFullName" 2^>nul') do (
        set /a GameAppFound+=1
        echo [%date% %time%]  ��������Xbox Game Bar��%%i >> "%LogFile%"
        
        powershell -command "Remove-AppxPackage -Package '%%i'" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined GameAppRemovalResult (
                set "GameAppRemovalResult=!GameAppRemovalResult!��Xbox Game Barɾ���ɹ�"
            ) else (
                set "GameAppRemovalResult=Xbox Game Barɾ���ɹ�"
            )
        ) else (
            if defined GameAppRemovalResult (
                set "GameAppRemovalResult=!GameAppRemovalResult!��Xbox Game Barɾ��ʧ��"
            ) else (
                set "GameAppRemovalResult=Xbox Game Barɾ��ʧ��"
            )
        )
    )

    :: ����������Ϸ���Ӧ��
    for /f "tokens=*" %%i in ('powershell -command "Get-AppxPackage -AllUsers | Where-Object {$_.Name -like '*Gaming*' -and $_.Publisher -like '*Microsoft*' -and $_.Name -ne 'Microsoft.GamingServices' -and $_.Name -ne 'Microsoft.XboxGamingOverlay'} | Select-Object -ExpandProperty PackageFullName" 2^>nul') do (
        set /a GameAppFound+=1
        echo [%date% %time%]  ��������������ϷӦ�ã�%%i >> "%LogFile%"
        
        powershell -command "Remove-AppxPackage -Package '%%i'" >nul 2>&1
        if !errorlevel! equ 0 (
            if defined GameAppRemovalResult (
                set "GameAppRemovalResult=!GameAppRemovalResult!��������ϷӦ��ɾ���ɹ�"
            ) else (
                set "GameAppRemovalResult=������ϷӦ��ɾ���ɹ�"
            )
        ) else (
            if defined GameAppRemovalResult (
                set "GameAppRemovalResult=!GameAppRemovalResult!��������ϷӦ��ɾ��ʧ��"
            ) else (
                set "GameAppRemovalResult=������ϷӦ��ɾ��ʧ��"
            )
        )
    )

    :: ��¼�����
    if !GameAppFound! equ 0 (
        echo [%date% %time%]  ���������Ϸ���Ӧ�ð�װ״̬��δ��װ >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ���������Ϸ���Ӧ�ð�װ״̬���Ѱ�װ!GameAppFound!������!GameAppRemovalResult! >> "%LogFile%"
    )

    :: ��鲢ɾ����Ϸ����ļ����ļ���
    set "GameFolderFound=0"
    set "GameFolderResult="

    :: ��鳣����Ϸ�������·��
    for %%p in ("%LocalAppData%\Microsoft\GamingServices", "%ProgramData%\Microsoft\GamingServices") do (
        if exist "%%p" (
            set /a GameFolderFound+=1
            rd /s /q "%%p" >nul 2>&1
            if not exist "%%p" (
                if defined GameFolderResult (
                    set "GameFolderResult=!GameFolderResult!��%%pɾ���ɹ�"
                ) else (
                    set "GameFolderResult=������Ϸ�ļ��У�%%p��ɾ���ɹ�"
                )
            ) else (
                if defined GameFolderResult (
                    set "GameFolderResult=!GameFolderResult!��%%pɾ��ʧ��"
                ) else (
                    set "GameFolderResult=������Ϸ�ļ��У�%%p��ɾ��ʧ��"
                )
            )
        )
    )

    :: ����Ԥ��װ��
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like '*Gaming*' -or $_.DisplayName -like '*XboxGaming*'} | Remove-AppxProvisionedPackage -Online" >nul 2>&1
    set "GameProvisionResult="
    if !errorlevel! equ 0 (
        set "GameProvisionResult=��ϷԤ��װ������ɹ�"
    ) else (
        set "GameProvisionResult=��ϷԤ��װ����������"
    )

    :: �ϲ�������
    if !GameFolderFound! equ 0 (
        echo [%date% %time%]  ����δ������Ϸ���ֳ����ļ���!GameProvisionResult! >> "%LogFile%"
    ) else (
        echo [%date% %time%]  ����!GameFolderResult! >> "%LogFile%"
        echo [%date% %time%]  ����!GameProvisionResult! >> "%LogFile%"
    )

    echo [%date% %time%]  ������Ϸ���ֺ���Ϸ������ֹ������ɣ�ע���������ͳһӦ�ã� >> "%LogFile%"
) else (
    echo [%date% %time%] ������Ϸ���ܼ�飨��ǰ���ð汾��!RegFileVersion!�� >> "%LogFile%"
)

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