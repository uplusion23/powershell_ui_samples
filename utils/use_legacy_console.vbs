' origin: https://www.tenforums.com/tutorials/94146-enable-disable-legacy-console-mode-all-consoles-windows-10-a.html#option2
' see also: https://stackoverflow.com/questions/8539821/how-to-get-reg-strvalue-from-hkcu-using-vbscript
Const HKEY_CURRENT_USER = &H80000001

strComputer = "."

Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _ 
    strComputer & "\root\default:StdRegProv")

strKeyPath = "Console"
strValueName = "ForceV2"
oReg.GetDwordValue HKEY_CURRENT_USER,strKeyPath,strValueName,strValue
Wscript.echo "ForceV2 = " & strValue

Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\default:StdRegProv")
oReg.SetDwordValue HKEY_CURRENT_USER,strKeyPath,strValueName,0
