# ���õ�ǰ���̵�ִ�в���
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# ����Ƿ��Թ���Ա������У�����������Զ�����Ȩ��
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "��⵽��Ҫ����ԱȨ�ޣ�������������Ȩ��..." -ForegroundColor Yellow
    
    try {
        # �Զ��Թ���Ա������������ű�
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
        Start-Process PowerShell -Argument $arguments -Verb RunAs -Wait
        exit
    } catch {
        Write-Host "�޷���ȡ����ԱȨ�ޣ����ֶ��Թ���Ա������д˽ű�" -ForegroundColor Red
        Write-Host "�����Ҽ����PowerShellѡ��'�Թ���Ա�������'" -ForegroundColor Red
        pause
        exit
    }
}

Write-Host "�ѻ�ù���ԱȨ�ޣ���ʼ�����ƻ�����..." -ForegroundColor Green

$TaskName = "DisableWindowsUpdateDaily"
$WrapperScriptPath = Join-Path $PSScriptRoot "wrapper_script.ps1"
$ActualScriptPath = Join-Path $PSScriptRoot "disable_update_daily.bat"

# ��� disable_update_daily.bat �Ƿ����
if (-not (Test-Path $ActualScriptPath)) {
    Write-Host "����: �Ҳ��� disable_update_daily.bat �ļ�" -ForegroundColor Red
    Write-Host "��ȷ�����ļ���˽ű���ͬһĿ¼��" -ForegroundColor Red
    pause
    exit
}

# ������װ�ű�
$WrapperScript = @"
# ����ִ�в���
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# �������Ƿ��Ѿ�ִ�й�
`$LogFile = "`$env:TEMP\DisableUpdate_LastRun.txt"
`$Today = Get-Date -Format "M/d/yyyy"

if (Test-Path `$LogFile) {
    `$LastRun = Get-Content `$LogFile -ErrorAction SilentlyContinue
    if (`$LastRun -eq `$Today) {
        # �����Ѿ�ִ�й����˳�
        exit 0
    }
}

# ��鵱ǰʱ��
`$CurrentTime = Get-Date
`$CurrentHour = `$CurrentTime.Hour

# ������賿0�㸽����0:00-0:05����ֱ��ִ��
if (`$CurrentHour -eq 0 -and `$CurrentTime.Minute -le 5) {
    try {
        # ֱ��ִ��bat�ļ�
        `$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ```"$ActualScriptPath```"" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory "$PSScriptRoot"
        exit `$process.ExitCode
    } catch {
        exit 1
    }
}

# ����ʱ�������״̬
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
        # ���г���3���ӣ�ִ������
        try {
            `$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ```"$ActualScriptPath```"" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory "$PSScriptRoot"
            exit `$process.ExitCode
        } catch {
            exit 1
        }
    }
} catch {
    # ������м��ʧ�ܣ�ֱ��ִ�У�����������
    try {
        `$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ```"$ActualScriptPath```"" -Wait -WindowStyle Hidden -PassThru -WorkingDirectory "$PSScriptRoot"
        exit `$process.ExitCode
    } catch {
        exit 1
    }
}

# ���û������ִ�������������˳�
exit 0
"@

# �����װ�ű�
$WrapperScript | Out-File -FilePath $WrapperScriptPath -Encoding UTF8

# ɾ���Ѵ��ڵ���������У�
try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "������ɵļƻ�����������ڣ�" -ForegroundColor Gray
} catch {
    Write-Host "���������ʱ�������⣨���ܲ����ھ�����" -ForegroundColor Gray
}

# ������������ʹ�ð�װ�ű���
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File `"$WrapperScriptPath`""

# ���������� - �����賿3���ҹ��21��
$Trigger1 = New-ScheduledTaskTrigger -Daily -At "00:00"  # �賿0�㣨ǿ��ִ�У�
$Trigger2 = New-ScheduledTaskTrigger -Daily -At "03:00"  # �賿3��
$Trigger3 = New-ScheduledTaskTrigger -Daily -At "06:00"  # ����6��
$Trigger4 = New-ScheduledTaskTrigger -Daily -At "12:00"  # ����12��
$Trigger5 = New-ScheduledTaskTrigger -Daily -At "18:00"  # ����6��
$Trigger6 = New-ScheduledTaskTrigger -Daily -At "21:00"  # ҹ��9��
$Triggers = @($Trigger1, $Trigger2, $Trigger3, $Trigger4, $Trigger5, $Trigger6)

# ������������
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -WakeToRun `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

# �����������壨��SYSTEM������У�
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# ע��ƻ�����
try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal -Description "ÿ�ս���Windows���·��� - ����ִ�У���ʱ����飩" -ErrorAction Stop
    Write-Host "? �ƻ����񴴽��ɹ���" -ForegroundColor Green
} catch {
    Write-Host "? �����ƻ�����ʱ���ִ���: $_" -ForegroundColor Red
    pause
    exit
}

Write-Host ""
Write-Host "==================== ����������Ϣ ====================" -ForegroundColor Cyan
Write-Host "��������: $TaskName" -ForegroundColor Yellow
Write-Host "Ŀ��ű�: $ActualScriptPath" -ForegroundColor Yellow
Write-Host "��װ�ű�: $WrapperScriptPath" -ForegroundColor Yellow
Write-Host "" -ForegroundColor White
Write-Host "ִ���߼�: " -ForegroundColor Yellow
Write-Host "  1. ÿ���賿0:00ǿ��ִ�� disable_update_daily.bat" -ForegroundColor Cyan
Write-Host "  2. ���ʱ����飨3:00, 6:00, 12:00, 18:00, 21:00��" -ForegroundColor Cyan
Write-Host "  3. ���賿ʱ����Ҫ����3���Ӳ�ִ��" -ForegroundColor Cyan
Write-Host "  4. ÿ��ֻ��ִ��һ�Σ�ͨ����־�ļ����ƣ�" -ForegroundColor Cyan
Write-Host "  5. �ỽ�Ѽ����ִ������" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White
Write-Host "ִ��ʱ���: 0:00��ǿ�ƣ�, 3:00, 6:00, 12:00, 18:00, 21:00" -ForegroundColor Gray
Write-Host "��������ƻ������в鿴�͹��������" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "�ű�ִ����ɣ���������ԣ�" -ForegroundColor Green
Write-Host "1. ������ƻ������в鿴����������" -ForegroundColor White
Write-Host "2. �ֶ�����������в���" -ForegroundColor White
Write-Host "3. �鿴��־�ļ��˽�ִ�����" -ForegroundColor White

pause