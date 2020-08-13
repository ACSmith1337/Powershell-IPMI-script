#Powershell script for R430 auto fan control.
 
 #change these
$dracIP = "192.168.1.##"
$dracUser = "root"
$dracPass = "PASSWORD"
$ipmiToolDir = "C:\Program Files\Dell\SysMgt\iDRACTools\IPMI"

#This is celcius based off CPU_0 Temp.
$lowerTempLimit = [int]21
$upperTempLimit = [int]50
$dangerTemp = [int]51 #server goes back to auto if this temp is reached
$lowerRpmLimit = [int]1
$upperRpmLimit = [int]10
#1 is around ~2800rpm, 20 is ~3400rpm, 25 max sound for idle, 50 is ~9000rpm, 100 is ~18000rpm
#stop changing here

$setManual = [String]("0x30 0x30 0x01 0x00")
$setAuto = [String]("0x30 0x30 0x01 0x01")
$setSpeed = [String]('0x30 0x30 0x02 0xff 0x')#last bit of hex code is cut off, letting our program add it later dynamically 

$start = './ipmitool.exe -I lanplus -H '+$dracIP+ ' -U '+ $dracUser +' -P '+$dracPass +' raw' #this is the template we will use to generate our commands


function do-Setup(){
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
cd $ipmiToolDir
($start +" "+ $setManual) | Invoke-Expression
}
function get-Temp()
{#Polls CPU_0 Temp
$command = './ipmitool.exe -I lanplus -H ' +$dracIP+ ' -U ' +$dracUser+ ' -P ' +$dracPass+ ' sensor reading "Temp"'
$stringtemp = Invoke-Expression -Command $command
$stringtemp = [String]$stringtemp
return [int]$stringtemp.Substring($stringtemp.IndexOf("|")+2)
}

function get-FanRpm()
{#Polls Front Fan in Row 3 RPM speed
$command = './ipmitool.exe -I lanplus -H ' +$dracIP+' -U '+$dracUser+' -P '+$dracPass+' sensor reading "Fan3A"'
$stringtemp = Invoke-Expression -Command $command
return [int]$stringtemp.Substring($stringtemp.IndexOf("|")+1)
}

function map([int]$in, [int]$in_min, [int]$in_max, [int]$out_min, [int]$out_max) #modified arduino's map function. Yay open source (https://www.arduino.cc/reference/en/language/functions/math/map/)
{
  return ($in - $in_min) * ($out_max - $out_min) / ($in_max - $in_min) + $out_min
}

do-Setup

#begin loop
Do{
[int]$temp = get-Temp
[int]$rpm = get-FanRpm
Write-Host "The CPU temp is" $temp"c"
Write-Host "Current fan rpm is" $rpm

if ($temp -ge $dangerTemp){
    ($start +" "+ $setAuto) | Invoke-Expression
    Write-Host "Temps are too high, switching back to auto mode for 5 minutes"
    Start-Sleep -s 300
    ($start +" "+ $setManual) | Invoke-Expression
}

$autoMap = [int](map $temp $lowerTempLimit $upperTempLimit $lowerRpmLimit $upperRpmLimit) #convert our temp into a fan rpm value based on our set params
$hex = [System.String]::Format('{0:X}', $autoMap) #map returns a int, so convert to hex value to pass to the raw command

if($autoMap -le 15){
($start +" "+ ($setSpeed+"0"+$hex)) | Invoke-Expression
}else{
($start +" "+ ($setSpeed+$hex)) | Invoke-Expression
}

Start-Sleep -s 10

} While(1)
