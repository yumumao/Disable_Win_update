[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Test
)

# ���õ�ǰ���̵�ִ�в���
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# ��־��¼����
$LogFile = Join-Path $PSScriptRoot "task_creation_log.txt"
function Write-Log {
    param($Message, $Color = "White")
    $TimeStamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $Message -ForegroundColor $Color
}

# �������ƺ�·��
$TaskName = "DisableWindowsUpdateDaily"
$ActualScriptPath = Join-Path $PSScriptRoot "disable_update_daily.bat"

# ж��ģʽ
if ($Uninstall) {
    Write-Log "��ʼж�ؼƻ�����..." "Yellow"
    
    try {
        # ɾ���ƻ�����
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($ExistingTask) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Log "�ƻ�������ɾ��" "Green"
        } else {
            Write-Log "δ�ҵ�Ҫɾ���ļƻ�����" "Yellow"
        }
        
        # ɾ����ʱִ�м�¼
        $TempLogFile = "$env:TEMP\DisableUpdate_LastRun.txt"
        if (Test-Path $TempLogFile) {
            Remove-Item $TempLogFile -Force
            Write-Log "��ʱִ�м�¼�����" "Green"
        }
        
        Write-Log "ж����ɣ�" "Green"
        
    } catch {
        Write-Log "ж�ع����г��ִ���: $_" "Red"
    }
    
    pause
    exit
}

# ����Ƿ��Թ���Ա������У�����������Զ�����Ȩ��
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "��⵽��Ҫ����ԱȨ�ޣ�������������Ȩ��..." "Yellow"
    
    try {
        # ����ԭ�в���
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
        if ($Test) { $arguments += " -Test" }
        if ($Uninstall) { $arguments += " -Uninstall" }
        
        Start-Process PowerShell -Argument $arguments -Verb RunAs -Wait
        exit
    } catch {
        Write-Log "�޷���ȡ����ԱȨ�ޣ����ֶ��Թ���Ա������д˽ű�" "Red"
        Write-Log "�����Ҽ����PowerShellѡ��'�Թ���Ա�������'" "Red"
        pause
        exit
    }
}

# ��ʾ�ָ���������¼����־��
Write-Host "==========================================================================" -ForegroundColor Gray

# ����־�ļ���ͷ��ӷָ���������ʾʱ�䣩
"==========================================================================" | Out-File -FilePath $LogFile -Append -Encoding UTF8

Write-Log "�ѻ�ù���ԱȨ�ޣ���ʼ�����ƻ�����..." "Green"

# ��� disable_update_daily.bat �Ƿ����
if (-not (Test-Path $ActualScriptPath)) {
    Write-Log "����: �Ҳ��� disable_update_daily.bat �ļ�" "Red"
    Write-Log "��ȷ�����ļ���˽ű���ͬһĿ¼��" "Red"
    Write-Log "��ǰĿ¼: $PSScriptRoot" "Gray"
    pause
    exit
}

Write-Log "�ҵ�Ŀ��BAT�ļ�: $ActualScriptPath" "Green"

# ɾ���Ѵ��ڵ���������У�
try {
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ExistingTask) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Log "������ɵļƻ�����" "Gray"
    }
} catch {
    Write-Log "���������ʱ�������⣨���ܲ����ھ�����" "Gray"
}

# ������������ֱ�ӵ���BAT�ļ���
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$ActualScriptPath`" admin" -WorkingDirectory $PSScriptRoot

# ���������� - ���ӿ�������
$TriggerBoot = New-ScheduledTaskTrigger -AtStartup  # ��������
$Trigger1 = New-ScheduledTaskTrigger -Daily -At "00:00"  # �賿0��
$Trigger2 = New-ScheduledTaskTrigger -Daily -At "03:00"  # �賿3��
$Trigger3 = New-ScheduledTaskTrigger -Daily -At "06:00"  # ����6��
$Trigger4 = New-ScheduledTaskTrigger -Daily -At "12:00"  # ����12��
$Trigger5 = New-ScheduledTaskTrigger -Daily -At "18:00"  # ����6��
$Trigger6 = New-ScheduledTaskTrigger -Daily -At "21:00"  # ҹ��9��
$Triggers = @($TriggerBoot, $Trigger1, $Trigger2, $Trigger3, $Trigger4, $Trigger5, $Trigger6)

Write-Log "������ $($Triggers.Count) ������������������������" "Green"

# ������������
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

# �����������壨��SYSTEM������У�
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# ע��ƻ�����
try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal -Description "ÿ�ս���Windows���·��� - ��ʱ���ִ�У��������� + ��ʱ��飩" -ErrorAction Stop
    Write-Log "�ƻ����񴴽��ɹ���" "Green"
} catch {
    Write-Log "�����ƻ�����ʱ���ִ���: $_" "Red"
    pause
    exit
}

# ��֤���񴴽�
Start-Sleep -Seconds 2
try {
    $CreatedTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Write-Log "������֤�ɹ� - ״̬: $($CreatedTask.State)" "Green"
    
    # ��ȡ������ϸ��Ϣ
    $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($TaskInfo) {
        Write-Log "������Ϣ - �ϴ�����: $($TaskInfo.LastRunTime), �´�����: $($TaskInfo.NextRunTime)" "Cyan"
    }
    
    # ��ʾ��������Ϣ
    $TaskTriggers = (Get-ScheduledTask -TaskName $TaskName).Triggers
    Write-Log "����������:" "Cyan"
    foreach ($trigger in $TaskTriggers) {
        if ($trigger.CimClass.CimClassName -eq "MSFT_TaskBootTrigger") {
            Write-Log "   - ϵͳ����ʱ" "Gray"
        } elseif ($trigger.CimClass.CimClassName -eq "MSFT_TaskDailyTrigger") {
            $startTime = $trigger.StartBoundary.Split('T')[1].Substring(0,5)
            Write-Log "   - ÿ�� $startTime" "Gray"
        }
    }
} catch {
    Write-Log "������֤ʧ��: $_" "Red"
}

# ����ģʽ
if ($Test) {
    Write-Log "����ģʽ���ֶ���������..." "Yellow"
    try {
        # ���û��������Ա�ʶ���ǲ�������
        [Environment]::SetEnvironmentVariable("TRIGGER_SOURCE", "PowerShell����", "Process")
        
        Start-ScheduledTask -TaskName $TaskName
        Write-Log "����������������������־�ļ��鿴ִ�н��" "Green"
        Write-Log "BAT�ű���־: $PSScriptRoot\update_disable_log.txt" "Cyan"
        
        # �ȴ������ӣ�Ȼ��������״̬
        Start-Sleep -Seconds 3
        $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        Write-Log "���Ժ�����״̬ - �ϴ�����: $($TaskInfo.LastRunTime), ���: $($TaskInfo.LastTaskResult)" "Cyan"
        
    } catch {
        Write-Log "��������ʧ��: $_" "Red"
    }
}

# ��ʾ������Ϣ
Write-Host ""
Write-Log "==================== ����������Ϣ ====================" "Cyan"
Write-Log "��������: $TaskName" "Yellow"
Write-Log "Ŀ��ű�: $ActualScriptPath" "Yellow"
Write-Log "������־: $LogFile" "Yellow"
Write-Host ""
Write-Log "ִ���߼�: " "Yellow"
Write-Log "  1. ϵͳ����ʱ�Զ�ִ��һ��" "Cyan"
Write-Log "  2. ÿ����ʱ����飨0:00, 3:00, 6:00, 12:00, 18:00, 21:00��" "Cyan"
Write-Log "  3. BAT�ļ������ظ���⣬ÿ��ִֻ��һ��" "Cyan"
Write-Log "  4. ��SYSTEMȨ�����У��޴�����ʾ" "Cyan"
Write-Log "  5. �ỽ�Ѽ����ִ������" "Cyan"
Write-Log "  6. �������أ�������������ʾ" "Cyan"
Write-Host ""
Write-Log "����ʱ��: �������� + 0:00, 3:00, 6:00, 12:00, 18:00, 21:00" "Gray"
Write-Log "��������ƻ�����(taskschd.msc)�в鿴�͹��������" "Yellow"
Write-Log "======================================================" "Cyan"

Write-Host ""
Write-Log "�ű�ִ����ɣ���������ԣ�" "Green"
Write-Log "1. ������ƻ������в鿴����������" "White"
Write-Log "2. ���� '.\0.create_scheduled_task.ps1 -Test' ���в���" "White"
Write-Log "3. ���� '.\0.create_scheduled_task.ps1 -Uninstall' ж������" "White"
Write-Log "4. �鿴��־�ļ��˽�ִ�����" "White"
Write-Log "   - ���񴴽���־: $LogFile" "Gray"
Write-Log "   - BATִ����־: $PSScriptRoot\update_disable_log.txt" "Gray"
Write-Log "   - �ظ�ִ�м�¼: $env:TEMP\DisableUpdate_LastRun.txt" "Gray"
# ����־�ļ���β��ӷָ���������ʾʱ�䣩
"==========================================================================" | Out-File -FilePath $LogFile -Append -Encoding UTF8

pause