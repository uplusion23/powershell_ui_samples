@echo OFF

REM The script wrapper and the inner script have to have a matching value of the ExecutionPolicy they 'require'
REM instead of writing a TARGET_EXECUTIONPOLICY parameter into the inline script 
REM is pass it to the script as a parameter


set TARGET_EXECUTIONPOLICY=ByPass
set TARGET_EXECUTIONPOLICY=Restricted
set TARGET_EXECUTIONPOLICY=AllSigned
set TARGET_EXECUTIONPOLICY=RemoteSigned
set TARGET_EXECUTIONPOLICY=Unrestricted

echo Changing Powershell Script execution Policy 
call C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy %TARGET_EXECUTIONPOLICY% "&{Param([string] $targetExecutionPolicy) Set-ExecutionPolicy $TargetExecutionPolicy; write-output (get-ExecutionPolicy -list )}" -targetExecutionPolicy %TARGET_EXECUTIONPOLICY%
echo Enabling Powershell Remoting 
call C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy %TARGET_EXECUTIONPOLICY% "&{Enable-PSRemoting -Force } "


goto :EOF 
REM 
REM Set-WSManQuickConfig : 
REM <f:WSManFault xmlns:f="http://schemas.microsoft.com/wbem/wsman/1/wsmanfault" Code="2150859113" Machine="localhost">
REM <f:Message>
REM <f:ProviderFault Code="2150859113" Machine="sergueik42">
REM <f:Message>
REM WinRM firewall exception will not work since 
REM one of the network connection types on this machine is set to Public. 
REM Change the network connection type to either Domain or Private and try again.
REM </f:Message></f:WSManFault></f:ProviderFault></f:Message></f:WSManFault>
REM http://www.minasi.com/newsletters/nws1304.htm