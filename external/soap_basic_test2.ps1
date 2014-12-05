# http://www.leeholmes.com/blog/2007/02/28/calling-a-webservice-from-powershell/
# http://stackoverflow.com/questions/27271744/using-new-webserviceproxy-under-powershell
param(
  [string]$wsdlLocation = $(throw 'Please specify a WSDL location'),
  [string]$namespace,
  [switch]$requiresAuthentication,
  [switch]$use_proxy,
  [switch]$offline,
  [switch]$no_cache
)

# http://stackoverflow.com/questions/8343767/how-to-get-the-current-directory-of-the-cmdlet-being-executed
function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  if ($Invocation.PSScriptRoot) {
    $Invocation.PSScriptRoot
  }
  elseif ($Invocation.MyCommand.Path) {
    Split-Path $Invocation.MyCommand.Path
  } else {
    $Invocation.InvocationName.Substring(0,$Invocation.InvocationName.LastIndexOf(""))
  }
}


function page_content {
  param(
    [string]$username = $env:USERNAME,
    [string]$url = '',
    [string]$password = '',
    [string]$use_proxy
  )

  if ($url -eq $null -or $url -eq '') {
    #  $url =  ('https://github.com/{0}' -f $username)
    $url = 'https://api.github.com/user'
  }


  $sleep_interval = 10
  $max_retries = 5

  if ($PSBoundParameters['use_proxy']) {

    # Use current user NTLM credentials do deal with corporate firewall
    $proxy_address = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyServer

    if ($proxy_address -eq $null) {
      $proxy_address = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').AutoConfigURL
    }

    if ($proxy_address -eq $null) {
      # write a hard coded proxy address here 
      $proxy_address = 'http://proxy.carnival.com:8080/array.dll?Get.Routing.Script'
    }

    $proxy = New-Object System.Net.WebProxy
    $proxy.Address = $proxy_address
    Write-Debug ("Probing {0}" -f $proxy.Address)
    $proxy.useDefaultCredentials = $true

  }

  <#
request.Credentials = new NetworkCredential(xxx,xxx);
CookieContainer myContainer = new CookieContainer();
request.CookieContainer = myContainer;
request.PreAuthenticate = true;

#>

  [system.Net.WebRequest]$request = [system.Net.WebRequest]::Create($url)
  try {
    [string]$encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::GetEncoding('ASCII').GetBytes(($username + ':' + $password)))
    Write-Debug $encoded
    $request.Headers.Add('Authorization','Basic ' + $encoded)
  } catch [argumentexception]{
    # NOP 
  }

  if ($PSBoundParameters['use_proxy']) {
    Write-Host ('Use Proxy: "{0}"' -f $proxy.Address)
    $request.proxy = $proxy
    $request.useDefaultCredentials = $true
  }
  # Note github returns a json result saying that it requires authentication 
  # standard server response is a "classic" 401 html page

  Write-Host ('Open {0}' -f $url)
  $expected_status = 200
  for ($i = 0; $i -ne $max_retries; $i++) {

    Write-Host ('Try {0}' -f $i)


    try {
      $response = $request.GetResponse()
    } catch [System.Net.WebException]{
      $response = $_.Exception.Response
    }

    $int_status = [int]$response.StatusCode
    $time_stamp = (Get-Date -Format 'yyyy/MM/dd hh:mm')
    $status = $response.StatusCode # not casting

    Write-Host "$time_stamp`t$url`t$int_status`t$status"
    if ($int_status -ne $expected_status) {
      Write-Host ('Unexpected http status detected [{0}]. Sleep and retry.' -f $int_status)

      Start-Sleep -Seconds $sleep_interval

      # sleep and retry
    } else {
      break
    }
  }

  $time_stamp = $null
  if ($int_status -ne $expected_status) {
    # write error status to a log file and exit
    # 
    Write-Host ('Unexpected http status detected. Error reported. {0}, {1} ' -f $int_status)
    log_message 'STEP_STATUS=ERROR' $build_status
  }

  $respstream = $response.GetResponseStream()
  $stream_reader = New-Object System.IO.StreamReader $respstream
  $result_page = $stream_reader.ReadToEnd()
  <#
       if ($result_page -match $confirm_page_text) {
         $found_expected_status =  $true
         if ($result_page.size -lt 100 )
         {
           $result_page_fragment= $result_page
         }
           write-host "Page Contents:`n${result_page_fragment}"
       } else {
         $found_expected_status =  $false
         $result_page = ''
       }
       #>


  Write-Debug $result_page

  return $result_page

}



function page_content_offline () {


  $wsdlStream_contents = @"
<?xml version="1.0" encoding="utf-8"?>
<wsdl:definitions xmlns:s="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://schemas.xmlsoap.org/wsdl/soap12/" xmlns:mime="http://schemas.xmlsoap.org/wsdl/mime/" xmlns:tns="http://msrmaps.com/" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:tm="http://microsoft.com/wsdl/mime/textMatching/" xmlns:http="http://schemas.xmlsoap.org/wsdl/http/" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" targetNamespace="http://msrmaps.com/">
  <wsdl:documentation xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/">MSR Maps Web Service</wsdl:documentation>
  <wsdl:types>
    <s:schema elementFormDefault="qualified" targetNamespace="http://msrmaps.com/">
      <s:element name="ConvertLonLatPtToNearestPlace">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="point" type="tns:LonLatPt"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:complexType name="LonLatPt">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="Lon" type="s:double"/>
          <s:element minOccurs="1" maxOccurs="1" name="Lat" type="s:double"/>
        </s:sequence>
      </s:complexType>
      <s:element name="ConvertLonLatPtToNearestPlaceResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="0" maxOccurs="1" name="ConvertLonLatPtToNearestPlaceResult" type="s:string"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="ConvertLonLatPtToUtmPt">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="point" type="tns:LonLatPt"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="ConvertLonLatPtToUtmPtResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="ConvertLonLatPtToUtmPtResult" type="tns:UtmPt"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:complexType name="UtmPt">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="Zone" type="s:int"/>
          <s:element minOccurs="1" maxOccurs="1" name="X" type="s:double"/>
          <s:element minOccurs="1" maxOccurs="1" name="Y" type="s:double"/>
        </s:sequence>
      </s:complexType>
      <s:element name="ConvertUtmPtToLonLatPt">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="utm" type="tns:UtmPt"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="ConvertUtmPtToLonLatPtResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="ConvertUtmPtToLonLatPtResult" type="tns:LonLatPt"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="ConvertPlaceToLonLatPt">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="place" type="tns:Place"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:complexType name="Place">
        <s:sequence>
          <s:element minOccurs="0" maxOccurs="1" name="City" type="s:string"/>
          <s:element minOccurs="0" maxOccurs="1" name="State" type="s:string"/>
          <s:element minOccurs="0" maxOccurs="1" name="Country" type="s:string"/>
        </s:sequence>
      </s:complexType>
      <s:element name="ConvertPlaceToLonLatPtResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="ConvertPlaceToLonLatPtResult" type="tns:LonLatPt"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="CountPlacesInRect">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="upperleft" type="tns:LonLatPt"/>
            <s:element minOccurs="1" maxOccurs="1" name="lowerright" type="tns:LonLatPt"/>
            <s:element minOccurs="1" maxOccurs="1" name="ptype" type="tns:PlaceType"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:simpleType name="PlaceType">
        <s:restriction base="s:string">
          <s:enumeration value="UnknownPlaceType"/>
          <s:enumeration value="AirRailStation"/>
          <s:enumeration value="BayGulf"/>
          <s:enumeration value="CapePeninsula"/>
          <s:enumeration value="CityTown"/>
          <s:enumeration value="HillMountain"/>
          <s:enumeration value="Island"/>
          <s:enumeration value="Lake"/>
          <s:enumeration value="OtherLandFeature"/>
          <s:enumeration value="OtherWaterFeature"/>
          <s:enumeration value="ParkBeach"/>
          <s:enumeration value="PointOfInterest"/>
          <s:enumeration value="River"/>
        </s:restriction>
      </s:simpleType>
      <s:element name="CountPlacesInRectResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="CountPlacesInRectResult" type="s:int"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetAreaFromPt">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="center" type="tns:LonLatPt"/>
            <s:element minOccurs="1" maxOccurs="1" name="theme" type="s:int"/>
            <s:element minOccurs="1" maxOccurs="1" name="scale" type="tns:Scale"/>
            <s:element minOccurs="1" maxOccurs="1" name="displayPixWidth" type="s:int"/>
            <s:element minOccurs="1" maxOccurs="1" name="displayPixHeight" type="s:int"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:simpleType name="Scale">
        <s:restriction base="s:string">
          <s:enumeration value="Scale1mm"/>
          <s:enumeration value="Scale2mm"/>
          <s:enumeration value="Scale4mm"/>
          <s:enumeration value="Scale8mm"/>
          <s:enumeration value="Scale16mm"/>
          <s:enumeration value="Scale32mm"/>
          <s:enumeration value="Scale63mm"/>
          <s:enumeration value="Scale125mm"/>
          <s:enumeration value="Scale250mm"/>
          <s:enumeration value="Scale500mm"/>
          <s:enumeration value="Scale1m"/>
          <s:enumeration value="Scale2m"/>
          <s:enumeration value="Scale4m"/>
          <s:enumeration value="Scale8m"/>
          <s:enumeration value="Scale16m"/>
          <s:enumeration value="Scale32m"/>
          <s:enumeration value="Scale64m"/>
          <s:enumeration value="Scale128m"/>
          <s:enumeration value="Scale256m"/>
          <s:enumeration value="Scale512m"/>
          <s:enumeration value="Scale1km"/>
          <s:enumeration value="Scale2km"/>
          <s:enumeration value="Scale4km"/>
          <s:enumeration value="Scale8km"/>
          <s:enumeration value="Scale16km"/>
          <s:enumeration value="Scale32km"/>
          <s:enumeration value="Scale64km"/>
          <s:enumeration value="Scale128km"/>
          <s:enumeration value="Scale256km"/>
          <s:enumeration value="Scale512km"/>
          <s:enumeration value="Scale1024km"/>
          <s:enumeration value="Scale2048km"/>
        </s:restriction>
      </s:simpleType>
      <s:element name="GetAreaFromPtResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="GetAreaFromPtResult" type="tns:AreaBoundingBox"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:complexType name="AreaBoundingBox">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="NorthWest" type="tns:AreaCoordinate"/>
          <s:element minOccurs="1" maxOccurs="1" name="NorthEast" type="tns:AreaCoordinate"/>
          <s:element minOccurs="1" maxOccurs="1" name="SouthWest" type="tns:AreaCoordinate"/>
          <s:element minOccurs="1" maxOccurs="1" name="SouthEast" type="tns:AreaCoordinate"/>
          <s:element minOccurs="1" maxOccurs="1" name="Center" type="tns:AreaCoordinate"/>
          <s:element minOccurs="0" maxOccurs="1" name="NearestPlace" type="s:string"/>
          <s:element minOccurs="0" maxOccurs="1" name="OverlappingThemeInfos" type="tns:ArrayOfOverlappingThemeInfo"/>
        </s:sequence>
      </s:complexType>
      <s:complexType name="AreaCoordinate">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="TileMeta" type="tns:TileMeta"/>
          <s:element minOccurs="1" maxOccurs="1" name="Offset" type="tns:LonLatPtOffset"/>
        </s:sequence>
      </s:complexType>
      <s:complexType name="TileMeta">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="Id" type="tns:TileId"/>
          <s:element minOccurs="1" maxOccurs="1" name="TileExists" type="s:boolean"/>
          <s:element minOccurs="1" maxOccurs="1" name="NorthWest" type="tns:LonLatPt"/>
          <s:element minOccurs="1" maxOccurs="1" name="NorthEast" type="tns:LonLatPt"/>
          <s:element minOccurs="1" maxOccurs="1" name="SouthWest" type="tns:LonLatPt"/>
          <s:element minOccurs="1" maxOccurs="1" name="SouthEast" type="tns:LonLatPt"/>
          <s:element minOccurs="1" maxOccurs="1" name="Center" type="tns:LonLatPt"/>
          <s:element minOccurs="1" maxOccurs="1" name="Capture" type="s:dateTime"/>
        </s:sequence>
      </s:complexType>
      <s:complexType name="TileId">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="Theme" type="s:int"/>
          <s:element minOccurs="1" maxOccurs="1" name="Scale" type="tns:Scale"/>
          <s:element minOccurs="1" maxOccurs="1" name="Scene" type="s:int"/>
          <s:element minOccurs="1" maxOccurs="1" name="X" type="s:int"/>
          <s:element minOccurs="1" maxOccurs="1" name="Y" type="s:int"/>
        </s:sequence>
      </s:complexType>
      <s:complexType name="LonLatPtOffset">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="Point" type="tns:LonLatPt"/>
          <s:element minOccurs="1" maxOccurs="1" name="XOffset" type="s:int"/>
          <s:element minOccurs="1" maxOccurs="1" name="YOffset" type="s:int"/>
        </s:sequence>
      </s:complexType>
      <s:complexType name="ArrayOfOverlappingThemeInfo">
        <s:sequence>
          <s:element minOccurs="0" maxOccurs="unbounded" name="OverlappingThemeInfo" type="tns:OverlappingThemeInfo"/>
        </s:sequence>
      </s:complexType>
      <s:complexType name="OverlappingThemeInfo">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="LocalTheme" type="s:boolean"/>
          <s:element minOccurs="1" maxOccurs="1" name="Theme" type="s:int"/>
          <s:element minOccurs="1" maxOccurs="1" name="Point" type="tns:LonLatPt"/>
          <s:element minOccurs="0" maxOccurs="1" name="ThemeName" type="s:string"/>
          <s:element minOccurs="1" maxOccurs="1" name="Capture" type="s:dateTime"/>
          <s:element minOccurs="1" maxOccurs="1" name="ProjectionId" type="tns:ProjectionType"/>
          <s:element minOccurs="1" maxOccurs="1" name="LoScale" type="tns:Scale"/>
          <s:element minOccurs="1" maxOccurs="1" name="HiScale" type="tns:Scale"/>
          <s:element minOccurs="0" maxOccurs="1" name="Url" type="s:string"/>
        </s:sequence>
      </s:complexType>
      <s:simpleType name="ProjectionType">
        <s:restriction base="s:string">
          <s:enumeration value="Geographic"/>
          <s:enumeration value="UtmNad27"/>
          <s:enumeration value="UtmNad83"/>
        </s:restriction>
      </s:simpleType>
      <s:element name="GetAreaFromRect">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="upperLeft" type="tns:LonLatPt"/>
            <s:element minOccurs="1" maxOccurs="1" name="lowerRight" type="tns:LonLatPt"/>
            <s:element minOccurs="1" maxOccurs="1" name="theme" type="s:int"/>
            <s:element minOccurs="1" maxOccurs="1" name="scale" type="tns:Scale"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetAreaFromRectResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="GetAreaFromRectResult" type="tns:AreaBoundingBox"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetAreaFromTileId">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="id" type="tns:TileId"/>
            <s:element minOccurs="1" maxOccurs="1" name="displayPixWidth" type="s:int"/>
            <s:element minOccurs="1" maxOccurs="1" name="displayPixHeight" type="s:int"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetAreaFromTileIdResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="GetAreaFromTileIdResult" type="tns:AreaBoundingBox"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetLatLonMetrics">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="point" type="tns:LonLatPt"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetLatLonMetricsResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="0" maxOccurs="1" name="GetLatLonMetricsResult" type="tns:ArrayOfThemeBoundingBox"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:complexType name="ArrayOfThemeBoundingBox">
        <s:sequence>
          <s:element minOccurs="0" maxOccurs="unbounded" name="ThemeBoundingBox" type="tns:ThemeBoundingBox"/>
        </s:sequence>
      </s:complexType>
      <s:complexType name="ThemeBoundingBox">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="Theme" type="s:int"/>
          <s:element minOccurs="0" maxOccurs="1" name="ThemeName" type="s:string"/>
          <s:element minOccurs="1" maxOccurs="1" name="Sparseness" type="s:int"/>
          <s:element minOccurs="1" maxOccurs="1" name="LoScale" type="tns:Scale"/>
          <s:element minOccurs="1" maxOccurs="1" name="HiScale" type="tns:Scale"/>
          <s:element minOccurs="1" maxOccurs="1" name="ProjectionId" type="tns:ProjectionType"/>
          <s:element minOccurs="0" maxOccurs="1" name="ProjectionName" type="s:string"/>
          <s:element minOccurs="1" maxOccurs="1" name="WestLongitude" type="s:double"/>
          <s:element minOccurs="1" maxOccurs="1" name="NorthLatitude" type="s:double"/>
          <s:element minOccurs="1" maxOccurs="1" name="EastLongitude" type="s:double"/>
          <s:element minOccurs="1" maxOccurs="1" name="SouthLatitude" type="s:double"/>
        </s:sequence>
      </s:complexType>
      <s:element name="GetPlaceFacts">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="place" type="tns:Place"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetPlaceFactsResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="GetPlaceFactsResult" type="tns:PlaceFacts"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:complexType name="PlaceFacts">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="Place" type="tns:Place"/>
          <s:element minOccurs="1" maxOccurs="1" name="Center" type="tns:LonLatPt"/>
          <s:element minOccurs="1" maxOccurs="1" name="AvailableThemeMask" type="s:int"/>
          <s:element minOccurs="1" maxOccurs="1" name="PlaceTypeId" type="tns:PlaceType"/>
          <s:element minOccurs="1" maxOccurs="1" name="Population" type="s:int"/>
        </s:sequence>
      </s:complexType>
      <s:element name="GetPlaceList">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="0" maxOccurs="1" name="placeName" type="s:string"/>
            <s:element minOccurs="1" maxOccurs="1" name="MaxItems" type="s:int"/>
            <s:element minOccurs="1" maxOccurs="1" name="imagePresence" type="s:boolean"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetPlaceListResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="0" maxOccurs="1" name="GetPlaceListResult" type="tns:ArrayOfPlaceFacts"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:complexType name="ArrayOfPlaceFacts">
        <s:sequence>
          <s:element minOccurs="0" maxOccurs="unbounded" name="PlaceFacts" type="tns:PlaceFacts"/>
        </s:sequence>
      </s:complexType>
      <s:element name="GetPlaceListInRect">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="upperleft" type="tns:LonLatPt"/>
            <s:element minOccurs="1" maxOccurs="1" name="lowerright" type="tns:LonLatPt"/>
            <s:element minOccurs="1" maxOccurs="1" name="ptype" type="tns:PlaceType"/>
            <s:element minOccurs="1" maxOccurs="1" name="MaxItems" type="s:int"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetPlaceListInRectResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="0" maxOccurs="1" name="GetPlaceListInRectResult" type="tns:ArrayOfPlaceFacts"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetTheme">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="theme" type="s:int"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetThemeResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="GetThemeResult" type="tns:ThemeInfo"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:complexType name="ThemeInfo">
        <s:sequence>
          <s:element minOccurs="1" maxOccurs="1" name="Theme" type="s:int"/>
          <s:element minOccurs="0" maxOccurs="1" name="Name" type="s:string"/>
          <s:element minOccurs="0" maxOccurs="1" name="Description" type="s:string"/>
          <s:element minOccurs="0" maxOccurs="1" name="Supplier" type="s:string"/>
          <s:element minOccurs="1" maxOccurs="1" name="LoScale" type="tns:Scale"/>
          <s:element minOccurs="1" maxOccurs="1" name="HiScale" type="tns:Scale"/>
          <s:element minOccurs="1" maxOccurs="1" name="ProjectionId" type="tns:ProjectionType"/>
          <s:element minOccurs="0" maxOccurs="1" name="ProjectionName" type="s:string"/>
          <s:element minOccurs="0" maxOccurs="1" name="CopyrightNotice" type="s:string"/>
        </s:sequence>
      </s:complexType>
      <s:element name="GetTileMetaFromLonLatPt">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="point" type="tns:LonLatPt"/>
            <s:element minOccurs="1" maxOccurs="1" name="theme" type="s:int"/>
            <s:element minOccurs="1" maxOccurs="1" name="scale" type="tns:Scale"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetTileMetaFromLonLatPtResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="GetTileMetaFromLonLatPtResult" type="tns:TileMeta"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetTileMetaFromTileId">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="id" type="tns:TileId"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetTileMetaFromTileIdResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="GetTileMetaFromTileIdResult" type="tns:TileMeta"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetTile">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="1" maxOccurs="1" name="id" type="tns:TileId"/>
          </s:sequence>
        </s:complexType>
      </s:element>
      <s:element name="GetTileResponse">
        <s:complexType>
          <s:sequence>
            <s:element minOccurs="0" maxOccurs="1" name="GetTileResult" type="s:base64Binary"/>
          </s:sequence>
        </s:complexType>
      </s:element>
    </s:schema>
  </wsdl:types>
  <wsdl:message name="ConvertLonLatPtToNearestPlaceSoapIn">
    <wsdl:part name="parameters" element="tns:ConvertLonLatPtToNearestPlace"/>
  </wsdl:message>
  <wsdl:message name="ConvertLonLatPtToNearestPlaceSoapOut">
    <wsdl:part name="parameters" element="tns:ConvertLonLatPtToNearestPlaceResponse"/>
  </wsdl:message>
  <wsdl:message name="ConvertLonLatPtToUtmPtSoapIn">
    <wsdl:part name="parameters" element="tns:ConvertLonLatPtToUtmPt"/>
  </wsdl:message>
  <wsdl:message name="ConvertLonLatPtToUtmPtSoapOut">
    <wsdl:part name="parameters" element="tns:ConvertLonLatPtToUtmPtResponse"/>
  </wsdl:message>
  <wsdl:message name="ConvertUtmPtToLonLatPtSoapIn">
    <wsdl:part name="parameters" element="tns:ConvertUtmPtToLonLatPt"/>
  </wsdl:message>
  <wsdl:message name="ConvertUtmPtToLonLatPtSoapOut">
    <wsdl:part name="parameters" element="tns:ConvertUtmPtToLonLatPtResponse"/>
  </wsdl:message>
  <wsdl:message name="ConvertPlaceToLonLatPtSoapIn">
    <wsdl:part name="parameters" element="tns:ConvertPlaceToLonLatPt"/>
  </wsdl:message>
  <wsdl:message name="ConvertPlaceToLonLatPtSoapOut">
    <wsdl:part name="parameters" element="tns:ConvertPlaceToLonLatPtResponse"/>
  </wsdl:message>
  <wsdl:message name="CountPlacesInRectSoapIn">
    <wsdl:part name="parameters" element="tns:CountPlacesInRect"/>
  </wsdl:message>
  <wsdl:message name="CountPlacesInRectSoapOut">
    <wsdl:part name="parameters" element="tns:CountPlacesInRectResponse"/>
  </wsdl:message>
  <wsdl:message name="GetAreaFromPtSoapIn">
    <wsdl:part name="parameters" element="tns:GetAreaFromPt"/>
  </wsdl:message>
  <wsdl:message name="GetAreaFromPtSoapOut">
    <wsdl:part name="parameters" element="tns:GetAreaFromPtResponse"/>
  </wsdl:message>
  <wsdl:message name="GetAreaFromRectSoapIn">
    <wsdl:part name="parameters" element="tns:GetAreaFromRect"/>
  </wsdl:message>
  <wsdl:message name="GetAreaFromRectSoapOut">
    <wsdl:part name="parameters" element="tns:GetAreaFromRectResponse"/>
  </wsdl:message>
  <wsdl:message name="GetAreaFromTileIdSoapIn">
    <wsdl:part name="parameters" element="tns:GetAreaFromTileId"/>
  </wsdl:message>
  <wsdl:message name="GetAreaFromTileIdSoapOut">
    <wsdl:part name="parameters" element="tns:GetAreaFromTileIdResponse"/>
  </wsdl:message>
  <wsdl:message name="GetLatLonMetricsSoapIn">
    <wsdl:part name="parameters" element="tns:GetLatLonMetrics"/>
  </wsdl:message>
  <wsdl:message name="GetLatLonMetricsSoapOut">
    <wsdl:part name="parameters" element="tns:GetLatLonMetricsResponse"/>
  </wsdl:message>
  <wsdl:message name="GetPlaceFactsSoapIn">
    <wsdl:part name="parameters" element="tns:GetPlaceFacts"/>
  </wsdl:message>
  <wsdl:message name="GetPlaceFactsSoapOut">
    <wsdl:part name="parameters" element="tns:GetPlaceFactsResponse"/>
  </wsdl:message>
  <wsdl:message name="GetPlaceListSoapIn">
    <wsdl:part name="parameters" element="tns:GetPlaceList"/>
  </wsdl:message>
  <wsdl:message name="GetPlaceListSoapOut">
    <wsdl:part name="parameters" element="tns:GetPlaceListResponse"/>
  </wsdl:message>
  <wsdl:message name="GetPlaceListInRectSoapIn">
    <wsdl:part name="parameters" element="tns:GetPlaceListInRect"/>
  </wsdl:message>
  <wsdl:message name="GetPlaceListInRectSoapOut">
    <wsdl:part name="parameters" element="tns:GetPlaceListInRectResponse"/>
  </wsdl:message>
  <wsdl:message name="GetThemeSoapIn">
    <wsdl:part name="parameters" element="tns:GetTheme"/>
  </wsdl:message>
  <wsdl:message name="GetThemeSoapOut">
    <wsdl:part name="parameters" element="tns:GetThemeResponse"/>
  </wsdl:message>
  <wsdl:message name="GetTileMetaFromLonLatPtSoapIn">
    <wsdl:part name="parameters" element="tns:GetTileMetaFromLonLatPt"/>
  </wsdl:message>
  <wsdl:message name="GetTileMetaFromLonLatPtSoapOut">
    <wsdl:part name="parameters" element="tns:GetTileMetaFromLonLatPtResponse"/>
  </wsdl:message>
  <wsdl:message name="GetTileMetaFromTileIdSoapIn">
    <wsdl:part name="parameters" element="tns:GetTileMetaFromTileId"/>
  </wsdl:message>
  <wsdl:message name="GetTileMetaFromTileIdSoapOut">
    <wsdl:part name="parameters" element="tns:GetTileMetaFromTileIdResponse"/>
  </wsdl:message>
  <wsdl:message name="GetTileSoapIn">
    <wsdl:part name="parameters" element="tns:GetTile"/>
  </wsdl:message>
  <wsdl:message name="GetTileSoapOut">
    <wsdl:part name="parameters" element="tns:GetTileResponse"/>
  </wsdl:message>
  <wsdl:portType name="TerraServiceSoap">
    <wsdl:operation name="ConvertLonLatPtToNearestPlace">
      <wsdl:input message="tns:ConvertLonLatPtToNearestPlaceSoapIn"/>
      <wsdl:output message="tns:ConvertLonLatPtToNearestPlaceSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="ConvertLonLatPtToUtmPt">
      <wsdl:input message="tns:ConvertLonLatPtToUtmPtSoapIn"/>
      <wsdl:output message="tns:ConvertLonLatPtToUtmPtSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="ConvertUtmPtToLonLatPt">
      <wsdl:input message="tns:ConvertUtmPtToLonLatPtSoapIn"/>
      <wsdl:output message="tns:ConvertUtmPtToLonLatPtSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="ConvertPlaceToLonLatPt">
      <wsdl:input message="tns:ConvertPlaceToLonLatPtSoapIn"/>
      <wsdl:output message="tns:ConvertPlaceToLonLatPtSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="CountPlacesInRect">
      <wsdl:input message="tns:CountPlacesInRectSoapIn"/>
      <wsdl:output message="tns:CountPlacesInRectSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetAreaFromPt">
      <wsdl:input message="tns:GetAreaFromPtSoapIn"/>
      <wsdl:output message="tns:GetAreaFromPtSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetAreaFromRect">
      <wsdl:input message="tns:GetAreaFromRectSoapIn"/>
      <wsdl:output message="tns:GetAreaFromRectSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetAreaFromTileId">
      <wsdl:input message="tns:GetAreaFromTileIdSoapIn"/>
      <wsdl:output message="tns:GetAreaFromTileIdSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetLatLonMetrics">
      <wsdl:input message="tns:GetLatLonMetricsSoapIn"/>
      <wsdl:output message="tns:GetLatLonMetricsSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetPlaceFacts">
      <wsdl:input message="tns:GetPlaceFactsSoapIn"/>
      <wsdl:output message="tns:GetPlaceFactsSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetPlaceList">
      <wsdl:input message="tns:GetPlaceListSoapIn"/>
      <wsdl:output message="tns:GetPlaceListSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetPlaceListInRect">
      <wsdl:input message="tns:GetPlaceListInRectSoapIn"/>
      <wsdl:output message="tns:GetPlaceListInRectSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetTheme">
      <wsdl:input message="tns:GetThemeSoapIn"/>
      <wsdl:output message="tns:GetThemeSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetTileMetaFromLonLatPt">
      <wsdl:input message="tns:GetTileMetaFromLonLatPtSoapIn"/>
      <wsdl:output message="tns:GetTileMetaFromLonLatPtSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetTileMetaFromTileId">
      <wsdl:input message="tns:GetTileMetaFromTileIdSoapIn"/>
      <wsdl:output message="tns:GetTileMetaFromTileIdSoapOut"/>
    </wsdl:operation>
    <wsdl:operation name="GetTile">
      <wsdl:input message="tns:GetTileSoapIn"/>
      <wsdl:output message="tns:GetTileSoapOut"/>
    </wsdl:operation>
  </wsdl:portType>
  <wsdl:binding name="TerraServiceSoap" type="tns:TerraServiceSoap">
    <soap:binding transport="http://schemas.xmlsoap.org/soap/http"/>
    <wsdl:operation name="ConvertLonLatPtToNearestPlace">
      <soap:operation soapAction="http://msrmaps.com/ConvertLonLatPtToNearestPlace" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="ConvertLonLatPtToUtmPt">
      <soap:operation soapAction="http://msrmaps.com/ConvertLonLatPtToUtmPt" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="ConvertUtmPtToLonLatPt">
      <soap:operation soapAction="http://msrmaps.com/ConvertUtmPtToLonLatPt" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="ConvertPlaceToLonLatPt">
      <soap:operation soapAction="http://msrmaps.com/ConvertPlaceToLonLatPt" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="CountPlacesInRect">
      <soap:operation soapAction="http://msrmaps.com/CountPlacesInRect" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetAreaFromPt">
      <soap:operation soapAction="http://msrmaps.com/GetAreaFromPt" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetAreaFromRect">
      <soap:operation soapAction="http://msrmaps.com/GetAreaFromRect" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetAreaFromTileId">
      <soap:operation soapAction="http://msrmaps.com/GetAreaFromTileId" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetLatLonMetrics">
      <soap:operation soapAction="http://msrmaps.com/GetLatLonMetrics" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetPlaceFacts">
      <soap:operation soapAction="http://msrmaps.com/GetPlaceFacts" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetPlaceList">
      <soap:operation soapAction="http://msrmaps.com/GetPlaceList" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetPlaceListInRect">
      <soap:operation soapAction="http://msrmaps.com/GetPlaceListInRect" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetTheme">
      <soap:operation soapAction="http://msrmaps.com/GetTheme" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetTileMetaFromLonLatPt">
      <soap:operation soapAction="http://msrmaps.com/GetTileMetaFromLonLatPt" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetTileMetaFromTileId">
      <soap:operation soapAction="http://msrmaps.com/GetTileMetaFromTileId" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetTile">
      <soap:operation soapAction="http://msrmaps.com/GetTile" style="document"/>
      <wsdl:input>
        <soap:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
  </wsdl:binding>
  <wsdl:binding name="TerraServiceSoap12" type="tns:TerraServiceSoap">
    <soap12:binding transport="http://schemas.xmlsoap.org/soap/http"/>
    <wsdl:operation name="ConvertLonLatPtToNearestPlace">
      <soap12:operation soapAction="http://msrmaps.com/ConvertLonLatPtToNearestPlace" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="ConvertLonLatPtToUtmPt">
      <soap12:operation soapAction="http://msrmaps.com/ConvertLonLatPtToUtmPt" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="ConvertUtmPtToLonLatPt">
      <soap12:operation soapAction="http://msrmaps.com/ConvertUtmPtToLonLatPt" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="ConvertPlaceToLonLatPt">
      <soap12:operation soapAction="http://msrmaps.com/ConvertPlaceToLonLatPt" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="CountPlacesInRect">
      <soap12:operation soapAction="http://msrmaps.com/CountPlacesInRect" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetAreaFromPt">
      <soap12:operation soapAction="http://msrmaps.com/GetAreaFromPt" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetAreaFromRect">
      <soap12:operation soapAction="http://msrmaps.com/GetAreaFromRect" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetAreaFromTileId">
      <soap12:operation soapAction="http://msrmaps.com/GetAreaFromTileId" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetLatLonMetrics">
      <soap12:operation soapAction="http://msrmaps.com/GetLatLonMetrics" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetPlaceFacts">
      <soap12:operation soapAction="http://msrmaps.com/GetPlaceFacts" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetPlaceList">
      <soap12:operation soapAction="http://msrmaps.com/GetPlaceList" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetPlaceListInRect">
      <soap12:operation soapAction="http://msrmaps.com/GetPlaceListInRect" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetTheme">
      <soap12:operation soapAction="http://msrmaps.com/GetTheme" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetTileMetaFromLonLatPt">
      <soap12:operation soapAction="http://msrmaps.com/GetTileMetaFromLonLatPt" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetTileMetaFromTileId">
      <soap12:operation soapAction="http://msrmaps.com/GetTileMetaFromTileId" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
    <wsdl:operation name="GetTile">
      <soap12:operation soapAction="http://msrmaps.com/GetTile" style="document"/>
      <wsdl:input>
        <soap12:body use="literal"/>
      </wsdl:input>
      <wsdl:output>
        <soap12:body use="literal"/>
      </wsdl:output>
    </wsdl:operation>
  </wsdl:binding>
  <wsdl:service name="TerraService">
    <wsdl:documentation xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/">MSR Maps Web Service</wsdl:documentation>
    <wsdl:port name="TerraServiceSoap" binding="tns:TerraServiceSoap">
      <soap:address location="http://terraserver-usa.com/TerraService2.asmx"/>
    </wsdl:port>
    <wsdl:port name="TerraServiceSoap12" binding="tns:TerraServiceSoap12">
      <soap12:address location="http://terraserver-usa.com/TerraService2.asmx"/>
    </wsdl:port>
  </wsdl:service>
</wsdl:definitions>
"@ ##  end of inline data


  return $wsdlStream_contents

} ## 


if (-not (Test-Path Variable:\Lee.Holmes.WebServiceCache)) {
  ${GLOBAL:Lee.Holmes.WebServiceCache} = @{}

}

if (-not ($PSBoundParameters['no_cache'])) {

  ## Create the web service cache, if it doesn’t already exist


  Write-Debug 'Check if there was an instance from a previous connection to this web service'

  $oldInstance = ${GLOBAL:Lee.Holmes.WebServiceCache}[$wsdlLocation]
  if ($oldInstance) {
    Write-Debug 'Return cached instance'
    $oldInstance
    return
  }
}

$wsdlStream_content = ''
if ($PSBoundParameters['offline']) {
  # TODO use 
  $wsdlStream_content = page_content_offline
} else {

  [string]$use_proxy_arg = $null
  # TODO pass switches correctly
  if ($PSBoundParameters['use_proxy']) {
    $use_proxy_arg = @( '-use_proxy',$true) -join ' '
  }
  Write-Debug "page_content -username $username -password $password -url $wsdlLocation $use_proxy_arg"
  $wsdlStream_content = page_content -UserName $username -password $password -url $wsdlLocation $use_proxy_arg

}
$filename = 'a'
$wsdlStream = [System.IO.Path]::Combine((Get-ScriptDirectory),('{0}.{1}' -f $filename,'wsdl'))
Set-Content -Path $wsdlStream -Value $wsdlStream_content
Write-Debug 'Loading the required Web Services DLL'

[void][Reflection.Assembly]::LoadWithPartialName("System.Web.Services")
## Download the WSDL for the service, and create a service description from
## it.
## Ensure that we were able to fetch the WSDL
if (-not (Test-Path Variable:\wsdlStream)) {
  throw ('Unable to fetch the WSDL from the {0}' - $wsdlLocation)
  # return
}
Write-Debug 'Reading Service Description'
$serviceDescription = [Web.Services.Description.ServiceDescription]::Read($wsdlStream)
try {
  Write-Debug 'Closing Service provider stream'
  $wsdlStream.Close()
} catch {
  # due to refactoring and introduction of 'offline'
  # Method invocation failed because [System.String] does not contain a method
  # named 'Close'.
  # slurp it
}
## Ensure that we were able to read the WSDL into a service description
if (-not (Test-Path Variable:\serviceDescription)) {
  Write-Debug 'No service Description'
  return
}

Write-Debug 'Import the web service into a CodeDom namespace'
$serviceNamespace = New-Object System.CodeDom.CodeNamespace
if ($namespace) {
  $serviceNamespace.Name = $namespace
}


$codeCompileUnit = New-Object System.CodeDom.CodeCompileUnit
$serviceDescriptionImporter = New-Object Web.Services.Description.ServiceDescriptionImporter
$serviceDescriptionImporter.AddServiceDescription($serviceDescription,$null,$null)
[void]$codeCompileUnit.Namespaces.Add($serviceNamespace)
[void]$serviceDescriptionImporter.Import($serviceNamespace,$codeCompileUnit)

Write-Debug 'Generate the code from that CodeDom into a string'

$generatedCode = New-Object Text.StringBuilder
$stringWriter = New-Object IO.StringWriter $generatedCode
$provider = New-Object Microsoft.CSharp.CSharpCodeProvider
$provider.GenerateCodeFromCompileUnit($codeCompileUnit,$stringWriter,$null)

Write-Debug 'Compile the source code'

$references = @( 'System.dll','System.Web.Services.dll','System.Xml.dll')
$compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters
$compilerParameters.ReferencedAssemblies.AddRange($references)
$compilerParameters.GenerateInMemory = $true
$compilerResults = $provider.CompileAssemblyFromSource($compilerParameters,$generatedCode)

if ($compilerResults.Errors.Count -gt 0) {
  Write-Debug 'There were errors, stay tuned'
  $errorLines = ''
  foreach ($error in $compilerResults.Errors) {
    $errorLines += "`n`t" + $error.Line + ":`t" + $error.ErrorText
  }
  Write-Debug $errorLines
  return
}
else
{
  Write-Debug 'Create the webservice object and return it'

  ## Get the assembly that we just compiled
  $assembly = $compilerResults.CompiledAssembly
  ## Find the type that had the WebServiceBindingAttribute.
  ## There may be other "helper types" in this file, but they will
  ## not have this attribute
  $type = $assembly.GetTypes() |
  Where-Object { $_.GetCustomAttributes(
      [System.Web.Services.WebServiceBindingAttribute],$false) }

  if (-not $type) {
    Write-Debug 'Could not generate web service proxy.'
    return
  }
  ## Create an instance of the type, store it in the cache,
  ## and return it to the user.
  ## cannot create instance if the assembly type already present 
  ## TODO: http://www.codeproject.com/Tips/836907/Loading-Assembly-in-Separate-AppDomain-to-Have-Fil
  $instance = $assembly.CreateInstance($type)
  if   ($instance -ne $null) {  
  Write-Debug ('Created {0}' -f $instance.GetType())
  ${GLOBAL:Lee.Holmes.WebServiceCache}[$wsdlLocation] = $instance
  }

  $instance.AccountList()

<#
$instance | get-member

  $cmwClient = new-object $instance.CoreWebServiceClient.CoreWebServiceClient("WSHttpBinding_ICoreWebService")
#   $cmwClient = $instance
$cmwClient.ClientCredentials |  get-member
  $cmwClient.ClientCredentials.UserName = "Administrator";
$cmwClient.ClientCredentials |  get-member
  $cmwClient.ClientCredentials.Password = "e15HlFmH";

$taskData = @{"title" = "Hello, world";
            "description" = "Ws task";}
            $cmwClient.TaskCreate($null, $taskData)


  return $instance
#>


<#
  $place = New-Object Place
  $place.City = "Miami"
  $place.State = "FL"
  $place.Country = "USA"
  $facts = $instance.GetPlaceFacts($place)
  $facts.Center | Format-List
  return $instance
#>
}

