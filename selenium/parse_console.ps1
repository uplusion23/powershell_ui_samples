param(
  [string]$debug = ''
)

# http://stackoverflow.com/questions/8343767/how-to-get-the-current-directory-of-the-cmdlet-being-executed
function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value;
  if ($Invocation.PSScriptRoot)
  {
    $Invocation.PSScriptRoot;
  }
  elseif ($Invocation.MyCommand.Path)
  {
    Split-Path $Invocation.MyCommand.Path
  }
  else
  {
    $Invocation.InvocationName.Substring(0,$Invocation.InvocationName.LastIndexOf("\"));
  }
}


$shared_assemblies = @(
  "HtmlAgilityPack.dll",
  "nunit.framework.dll"
)

$env:SHARED_ASSEMBLIES_PATH = "c:\developer\sergueik\csharp\SharedAssemblies"
$shared_assemblies_path = $env:SHARED_ASSEMBLIES_PATH
pushd $shared_assemblies_path
$shared_assemblies | ForEach-Object { Unblock-File -Path $_; Add-Type -Path $_; Write-Debug ("Loaded {0} " -f $_) }
popd


$url = 'http://localhost:4444/grid/console#'

$sleep_interval = 30
$max_retries = 1
$build_log = 'test.properties'
$expected_http_status = 200

$proxyAddr = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyServer
if ($proxyAddr -eq $null) {
  $proxyAddr = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').AutoConfigURL
}

if ($proxyAddr -eq $null) {
  $proxyAddr = 'http://proxy.carnival.com:8080/array.dll?Get.Routing.Script'
}

$proxy = New-Object System.Net.WebProxy
$proxy.Address = $proxyAddr
Write-Debug ('Probing {0}' -f $proxy.Address)
$proxy.useDefaultCredentials = $true

$req = [system.Net.WebRequest]::Create($url)
$req.proxy = $proxy
$req.useDefaultCredentials = $true

$req.PreAuthenticate = $true
$req.Headers.Add('UserAgent','Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/22.0.1229.94 Safari/535.2')

$req.Credentials = New-Object system.net.networkcredential ($build_user,$build_password)
# $response = $webrequest.GetResponse()
[Io.StreamReader]$sr = $null
[int]$int = 0
for ($i = 0; $i -ne $max_retries; $i++) {


  try {
    $res = $req.GetResponse()
    $sr = [Io.StreamReader]($res.GetResponseStream())
    # may fail!
    # [xml]$xmlout = $sr.ReadToEnd()

  } catch [System.Net.WebException]{
    $res = $_.Exception.Response
  }
  $int = [int]$res.StatusCode
  $time_stamp = (Get-Date -Format 'yyyy/MM/dd hh:mm')
  $status = $res.StatusCode
  Write-Output "$time_stamp`t$url`t$int`t$status"
  if (($int -ne $expected_http_status) -or ($sr -eq $null)) {
    Start-Sleep -Seconds $sleep_interval
  }
}
$time_stamp = $null
if ($int -ne $expected_http_status) {
  # write error status to a log file and exit
  # 
  Write-Output 'Unexpected http status detected. Error reported.'
  log_message 'STEP_STATUS=ERROR' $build_status
  exit 1

}
[string]$source = $sr.ReadToEnd()
try {
  # will fail to load. 
  [xml]$xmlout = $source

}
catch [exception]{
  Write-Output 'ignoring the exception'
  # write-output $_.Exception.Message
  <# Cannot convert value "<html><... </a></div></body></html>" to type "System.Xml.XmlDocument". 
Error: "The 'p' start tag on line 1 position 749 does not match the end tag of 'div'. Line 4, position 833." 
#>
}

[System.Net.WebUtility]::HtmlDecode($source)


# http://www.codeproject.com/Tips/804660/How-to-Parse-Html-using-csharp
# http://htmlagilitypack.codeplex.com/downloads/get/437941
[HtmlAgilityPack.HtmlNodeCollection]$nodes = $resultat.DocumentNode.SelectNodes("//p[@class='proxyid']")
foreach ($node in $nodes)
{
  Write-Output $node.InnerText

  try {
    [HtmlAgilityPack.HtmlNodeNavigator]$navigator = $node.CreateNavigator()
    [void]$navigator.MoveToNext()
    [void]$navigator.MoveToNext()
    $navigator.SelectNodes("//div[@type='browsers']//img")
    <# TODO - switch back to node collection
Method invocation failed because ...#>
    Write-Output 'in navigator'
    $navigator = $null
  } catch [exception]{
    # write-output $_.Exception.Message
    # NOOP 
  }
  $browsers_div = $node.NextSibling.NextSibling
  # write-output $browsers_div
  [HtmlAgilityPack.HtmlNodeCollection]$browsers = $browsers_div.SelectNodes("div[@type='browsers']//img")


  # [HtmlAgilityPack.HtmlNode] $node = $null
  foreach ($image in $browsers)
  {

    Write-Output $image.Attributes["title"].Value
    Write-Output $image.Attributes["class"].Value

  }

}

[HtmlAgilityPack.HtmlWeb]$web = New-Object HtmlAgilityPack.HtmlWeb
[System.Xml.XmlTextWriter]$wr = New-Object XML.XmlTextWriter ('{0}\{1}' -f (Get-ScriptDirectory),'test12.xml'),([Text.Encoding]::Unicode)
[void]$web.LoadHtmlAsXml($url,$wr)

$wr.Close()

return
