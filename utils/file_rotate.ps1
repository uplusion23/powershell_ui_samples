# setting the mockup environment

$statedir = $env:TEMP

$last_run_report = 'last_run_report.yaml'
$filename_mask = ('{0}.*' -f $last_run_report)
pushd $statedir
write-host ('Mocking {0} {1}' -f $last_run_report, "${root_path}\${last_run_report}")
write-output '' | out-file -FilePath "${statedir}\${last_run_report}"
popd


# actual code


if (test-path -path $statedir) {

  pushd $statedir
  
  
  if (test-path -path $last_run_report) {
      
    $file_count = @( Get-ChildItem -Name "$last_run_report.*" -ErrorAction 'Stop' ).count
    
    if ($file_count -gt 0) {
      $file_count..1  | foreach-object { 
        $cnt = $_
        [Console]::Error.WriteLine(("Move ${last_run_report}.{0} ${last_run_report}.{1}" -f $cnt, ($cnt + 1)))
        move-item  "${last_run_report}.${cnt}" -Destination "${last_run_report}.$(($cnt + 1))" -force
      }
    }
    [Console]::Error.WriteLine(('Move ' + $last_run_report + ' ' + "${last_run_report}.1"))
    move-item $last_run_report -Destination "${last_run_report}.1" -force
  }
  popd
}
