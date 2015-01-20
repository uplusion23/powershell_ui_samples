param ([String] $hostname, [String] $host_ip)    



param(
  [string]$host_ip = '',
  [int]$host_index = 0,
  [string]$hostname = ''

)



function redirect_workaround {

  param(
    [string]$web_host = '',
    [string]$app_url = '',
    [string]$app_virtual_path = ''


  )

  if ($web_host -eq $null -or $web_host -eq '') {
    throw 'Web host cannot be null'

  }

  if (($app_virtual_path -ne '') -and ($app_virtual_path -ne '')) {
    $app_url = "http://${web_host}/${app_virtual_path}"
  }


  if ($app_url -eq $null -or $app_url -eq '') {
    throw 'Url cannot be null'
  }

  # workaround for 
  # The underlying connection was closed: Could not establish
  # trust relationship for the SSL/TLS secure channel.
  # error 
  # explained in 
  # http://stackoverflow.com/questions/11696944/powershell-v3-invoke-webrequest-https-error
  Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
  [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

  $result = $null

  try {
    $result = (Invoke-WebRequest -MaximumRedirection 0 -Uri $app_url -ErrorAction 'SilentlyContinue')
    if ($result.StatusCode -eq '302' -or $result.StatusCode -eq '301') {
      $location = $result.headers.Location
      if ($location -match '^http') {
        # TODO capture the host
        $location = $location -replace 'secure.carnival.com',$web_host
      } else {
        $location = $location -replace '^/',''
        $location = ('http://{0}/{1}' -f $web_host,$location)
      }
      Write-Host ('Following {0} ' -f $location)

      $result = (Invoke-WebRequest -Uri $location -ErrorAction 'Stop')
    }
  } catch [exception]{}


  $result.Content.length

}


$target_host = ''
if ($host_ip -ne $null -and $host_ip -ne '') {
  $target_host = $host_ip
}


if ($host_index -ne 0) {
  $target_host = "web${host_index}"
  return
}

if ($target_host -eq $null -or $target_host -eq '') {
  return
}


#Primed URLs    


$webpagelist = (
        "http://$host_ip", 
        "http://$host_ip/#q=selenium,&spell=1", 
        "http://$host_ip/#q=Selenium+-+Google+Code",
        "http://$host_ip/#q=Selenium+-+wikipedia"
        )

# introduced one short and one long response delay 
# if ($debug -eq $true){
  $mockup_delays  = @{"web30" = 100; "web23" = 30 }
#}


Write-Host ('Testing {0}' -f $hostname)
$WebpageList | ForEach-Object {
  $app_url = $_
  Write-Output ('Trying {0}' -f $app_url)
  $warmup_response_time = [System.Math]::Round((Measure-Command {
        try {
          redirect_workaround -web_host $target_host -app_url $app_url
          # (New-Object net.webclient).DownloadString($_)
        } catch [exception]{
          Write-Output ("Exception `n{0}" -f (($_.Exception.Message) -split "`n")[0])
        }
      }
    ).totalmilliseconds)


  <#
  if ( $url -like 'specials') {
    if ($mockup_delays.containskey($hostname) ) {
      $delay = $mockup_delays[$hostname]
      write-output ("Sleeping {0} seconds" -f $delay)
      start-sleep -seconds $delay;
    }
  }
  Write-output ("Opening page: {0}" -f $url)
  $warmup_response_time = [System.Math]::Round((Measure-Command {(new-object net.webclient).DownloadString( $url  )}).totalmilliseconds)
  Write-output ("Opening page: {0} took {1} ms" -f $url, $warmup_response_time )
#>

  Write-Output ("Opening page: {0} took {1} ms" -f $app_url,$warmup_response_time)

};


};
