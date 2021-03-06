' origin: https://www.tenforums.com/tutorials/94146-enable-disable-legacy-console-mode-all-consoles-windows-10-a.html#option2
' see also: https://stackoverflow.com/questions/8539821/how-to-get-reg-strvalue-from-hkcu-using-vbscript
Option Explicit

Const bDebug = false

Const HKEY_CURRENT_USER = &H80000001

Dim strComputer: strComputer = "."

Dim myRegExp: Set myRegExp = New RegExp
myRegExp.IgnoreCase = True
myRegExp.Global = True
myRegExp.Pattern = "^10\..*"
	
Dim objWMIService: Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

Dim objOperatingSystems: Set objOperatingSystems = objWMIService.ExecQuery ("select * from Win32_OperatingSystem")
Dim objOperatingSystem
For Each objOperatingSystem in objOperatingSystems
  if bDebug then
    Wscript.echo objOperatingSystem.Caption & " " & objOperatingSystem.Version, 0 + 32,"Window Version"
  end if
  if myRegExp.Test(objOperatingSystem.Version) then
    ' Enable Use Legacy Console in Windows 10
    if bDebug then
      Wscript.echo "Will need to Enable Use Legacy Console"
    end if

    Dim objStdRegProv: Set objStdRegProv = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\default:StdRegProv")

    Dim strKeyPath: strKeyPath = "Console"
    Dim strValueName: strValueName = "ForceV2"
    Dim strValue
    objStdRegProv.GetDwordValue HKEY_CURRENT_USER,strKeyPath,strValueName,strValue
    if strValue <> 0 then
      objStdRegProv.SetDwordValue HKEY_CURRENT_USER,strKeyPath,strValueName,0
	  if bDebug then
        Wscript.echo "Enabled Use Legacy Console in Windows 10"
      end if
    else
	  if bDebug then
        Wscript.echo "Use Legacy Console  is already Enabled"
      end If
    end if
  end if
Next

