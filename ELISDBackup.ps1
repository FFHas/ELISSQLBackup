$error.clear()

######## IMPORTANT NOTICE ########
# 1) Work only with integrated Security (Windows logon)
# 2) The service user from the SQL Server must have permissions to the Backup Directory
# 3) User who run this script must have permissions to Backup the SQL Databases

###### EDIT THESE VARIABLES ######

#SQL SERVER NAME
$SQLSERVER = "LOCALHOST"

#ELIS System Database Name
$SYSDB = "ELISSystem"

#ELIS Alarmplan Database Name
$APDB = "ELISAlarmplan"

#ELIS Objekt Database Name
$OBDB = "ELISObjekt"

#Backup Directory
$BACKUPDIR = "D:\ELISBackup\"  # with ending \

#retention time in days
$RET= 14

##################################

$databases = $SYSDB, $APDB, $OBDB
$date = Get-Date -Format "yyyyMMdd-HHmmss"
$RET = $RET * -1

#check if Eventlog exists
if ([system.diagnostics.eventlog]::SourceExists("ELIS SQL-Backup Script") -eq $False) {
	New-EventLog -LogName "Application" -Source "ELIS SQL-Backup Script"
}
if ([system.diagnostics.eventlog]::SourceExists("ELIS SQL-Backup") -eq $False) {
	New-EventLog -LogName "ELIS" -Source "ELIS SQL-Backup"
}

#check if Backup Directory exists
if (-not(Test-Path -Path $BACKUPDIR)) {
    Write-EventLog -LogName "Application" -Source "ELIS SQL-Backup Script" -EventID "1010" -EntryType "Error" -Message "Couldn't find Backup Directory. Backup aborted." -Category 0
    Write-EventLog -LogName "ELIS" -Source "ELIS SQL-Backup" -EventID "1010" -EntryType "Error" -Message "Couldn't find Backup Directory. Backup aborted." -Category 0
    break
}

foreach ($database in $databases){
    # connect to SQL Server and Database and check, if a connection can be established
    try {
        Invoke-Sqlcmd -ServerInstance $SQLSERVER -DataBase $database -Query "SELECT GETDATE() AS TimeOfQuery" -QueryTimeout 5 -ErrorAction 'Stop'
    } catch {
        $message = "Couldn't connect to SQL Server " + $SQLSERVER + " to database " + $database + ". "+ $error
        Write-EventLog -LogName "Application" -Source "ELIS SQL-Backup Script" -EventID "1011" -EntryType "Error" -Message $message -Category 0
        Write-EventLog -LogName "ELIS" -Source "ELIS SQL-Backup" -EventID "1011" -EntryType "Error" -Message $message -Category 0        
        break
    }

    # Backup the Databases
    try {
        $file = $BACKUPDIR+$database+"_"+$date+".bak"
        $query = "BACKUP DATABASE "+ $database + " TO DISK ='"+$file+"'"
        Invoke-Sqlcmd -ServerInstance $SQLSERVER -Query $query -QueryTimeout 300 -ErrorAction 'Stop'
    } catch {
        $message = "Couldn't finish Backup from database " + $database + ". "+ $error
        Write-EventLog -LogName "Application" -Source "ELIS SQL-Backup Script" -EventID "1012" -EntryType "Error" -Message $message -Category 0
        Write-EventLog -LogName "ELIS" -Source "ELIS SQL-Backup" -EventID "1012" -EntryType "Error" -Message $message -Category 0
        break
    }

    if (Test-Path -Path $file -PathType Leaf) {
        $message = "Backup from database " + $database + " finished."
        Write-EventLog -LogName "ELIS" -Source "ELIS SQL-Backup" -EventID "1000" -EntryType "Information" -Message $message -Category 0
    }

}

#delete backups that are older than X days
try {
    Get-Childitem $BACKUPDIR* -include *.bak | where {$_.lastwritetime -lt (get-date).adddays($RET) -and -not $_.psiscontainer} |% {remove-item $_.fullname -force}
} catch {
    $message = "Couldn't delete old Backups from Backup Directory. "+ $error
    Write-EventLog -LogName "Application" -Source "ELIS SQL-Backup Script" -EventID "1013" -EntryType "Error" -Message $message -Category 0
    Write-EventLog -LogName "ELIS" -Source "ELIS SQL-Backup" -EventID "1013" -EntryType "Error" -Message $message -Category 0
}
