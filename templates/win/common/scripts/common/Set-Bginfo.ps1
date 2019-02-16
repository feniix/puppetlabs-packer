# User Script to display useful VMData in on the desktop using BGInfo

$PoolerApiURL = "http://vmpooler.delivery.puppetlabs.net/api/v1/vm/"
$VMHostname = hostname

# Query the pooler to pick up attributes on this session.
# Using PS2 compatible code here (Invoke-Restmethod ins't available until PS3) 
$WebRequest = [System.Net.WebRequest]::Create("$PoolerApiURL/$VMHostname")
$WebRequest.Method = "GET"
$WebRequest.ContentType = "application/json"
$Response = $WebRequest.GetResponse()
$ResponseStream = $Response.GetResponseStream()
$ReadStream = New-Object System.IO.StreamReader $ResponseStream

[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$PoolerData = $ser.DeserializeObject($ReadStream.ReadToEnd())

$Lifetime = $PoolerData.$VMHostname.lifetime
$ENV:VMPOOLER_Lifetime = "$Lifetime hours"

# Get Remaining time in seconds - display short format same as bginfo time
$RemainingTime = [Math]::Floor([decimal](($Lifetime - $PoolerData.$VMHostname.running)*3600))
$ENV:VMPOOLER_Expiry_Time = Get-Date (Get-Date).AddSeconds($RemainingTime) -format "yyyy-MM-dd HH:mm zzz"

# Work out expiry in hours by subtracting runing time.
$ENV:VMPOOLER_Template_Name = $PoolerData.$VMHostname.template

# Get last boot time (also in ISO Format)
$ENV:VMPOOLER_LastBootTime = Get-Date ((Get-WmiObject win32_operatingsystem -ComputerName $VMHostname| select @{LABEL="LastBootUpTime";EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}).LastBootUpTime) -format "yyyy-MM-dd HH:mm zzz"

# Cygwin version
$CygWinShell = "$ENV:CYGWINDIR\bin\sh.exe"
$ENV:VMPOOLER_Cygwin_Version = & $CygWinShell --login -c "uname -r"

# These variables are set in the permanent environment during build time.
#VMPOOLER_Build_Date=Build-Date
#VMPOOLER_Packer_SHA=124214215215215235
#VMPOOLER_Packer_Template=Packer_Template_Name

#
# Run BGInfo to display data using bginfo file in C:\Packer\Config

bginfo.exe C:\Packer\Config\VMPooler.bgi /timer:0 /nolicprompt /silent

# So long farewell, Auf Wiedersehn, Goodbye
