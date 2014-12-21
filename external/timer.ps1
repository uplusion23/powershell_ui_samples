

# http://poshcode.org/1192
function GenerateForm {

  @( 'System.Drawing','System.Windows.Forms') | ForEach-Object { [void][System.Reflection.Assembly]::LoadWithPartialName($_) }

  $f = New-Object System.Windows.Forms.Form
  $r = New-Object System.Windows.Forms.Button
  $l = New-Object System.Windows.Forms.Label
  $s = New-Object System.Windows.Forms.Button
  $t = New-Object System.Windows.Forms.Timer

  $p = New-Object System.Windows.Forms.ProgressBar
  $p.DataBindings.DefaultDataSourceUpdateMode = 0
  $p.Maximum = 60
  $p.Size = New-Object System.Drawing.Size (526,87)
  $p.Step = 1
  $p.TabIndex = 0
  $p.Location = New-Object System.Drawing.Point (45,146)
  $p.Style = 1
  $p.Name = 'progressBar1'


  $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState


  $s_OnClick = {
    $t.Enabled = $true
    $t.Start()
    $s.Text = 'Countdown Started.'
  }

  $r_OnClick = {
    $t.Enabled = $false
    $p.Value = 0
    $s.Text = 'Start'
    $elapsed = New-TimeSpan -Seconds ($p.Maximum - $p.Value)
    $l.Text = ('{0:00}:{1:00}:{2:00}' -f $elapsed.Hours,$elapsed.Minutes,$elapsed.Seconds)

  }

  $t_OnTick = {
    $p.PerformStep()

    $time = $p.Maximum - $p.Value
    [char[]]$mins = "{0}" -f ($time / 60)
    $secs = "{0:00}" -f ($time % 60)

    $elapsed = New-TimeSpan -Seconds ($p.Maximum - $p.Value)
    $l.Text = ('{0:00}:{1:00}:{2:00}' -f $elapsed.Hours,$elapsed.Minutes,$elapsed.Seconds)


    if ($p.Value -eq $p.Maximum) {
      $t.Enabled = $false
      $s.Text = 'FINISHED!'
    }
  }

  $OnLoadForm_StateCorrection = {
    # Correct the initial state of the form to prevent the .Net maximized form issue
    $f.WindowState = $InitialFormWindowState
  }

  $f.MaximumSize = New-Object System.Drawing.Size (628,295)

  $f.Text = 'Timer'
  $f.MaximizeBox = $False
  $f.Name = 'form_main'
  $f.ShowIcon = $False
  $f.MinimumSize = New-Object System.Drawing.Size (628,295)
  $f.StartPosition = 1
  $f.DataBindings.DefaultDataSourceUpdateMode = 0
  $f.ClientSize = New-Object System.Drawing.Size (612,259)

  $r.TabIndex = 4
  $r.Name = 'button2'
  $r.Size = New-Object System.Drawing.Size (209,69)
  $r.UseVisualStyleBackColor = $True

  $r.Text = 'Reset'
  $r.Font = New-Object System.Drawing.Font ('Verdana',12,0,3,0)

  $r.Location = New-Object System.Drawing.Point (362,13)
  $r.DataBindings.DefaultDataSourceUpdateMode = 0
  $r.add_click($r_OnClick)

  $f.Controls.Add($r)

  $l.TabIndex = 3
  $l.TextAlign = 32
  $l.Size = New-Object System.Drawing.Size (526,54)
  $elapsed = New-TimeSpan -Seconds ($p.Maximum - $p.Value)
  $l.Text = ('{0:00}:{1:00}:{2:00}' -f $elapsed.Hours,$elapsed.Minutes,$elapsed.Seconds)
  $l.Font = New-Object System.Drawing.Font ("Courier New",20.25,1,3,0)

  $l.Location = New-Object System.Drawing.Point (45,89)
  $l.DataBindings.DefaultDataSourceUpdateMode = 0
  $l.Name = 'label1'

  $f.Controls.Add($l)

  $s.TabIndex = 2
  $s.Name = 'button1'
  $s.Size = New-Object System.Drawing.Size (310,70)
  $s.UseVisualStyleBackColor = $True

  $s.Text = 'Start'
  $s.Font = New-Object System.Drawing.Font ("Verdana",12,0,3,0)

  $s.Location = New-Object System.Drawing.Point (45,12)
  $s.DataBindings.DefaultDataSourceUpdateMode = 0
  $s.add_click($s_OnClick)

  $f.Controls.Add($s)


  $f.Controls.Add($p)

  $t.Interval = 1000
  $t.add_tick($t_OnTick)

  $InitialFormWindowState = $f.WindowState
  $f.add_Load($OnLoadForm_StateCorrection)
  $f.ShowDialog() | Out-Null

}

#Call the Function
GenerateForm
