[CmdletBinding()]
param(
  [Parameter(Mandatory = $True)]
  [string]
  $ArgString,

  [Parameter(Mandatory = $False)]
  [Int32] # aka [Int]
  $ArgInt32,

  [Parameter(Mandatory = $False)]
  [Float] # aka [Single]
  $ArgFloat,

  [Parameter(Mandatory = $False)]
  [Hashtable]
  $ArgHashtable,

  [Parameter(Mandatory = $False)]
  [Array]
  $ArgArray,

  [Parameter(Mandatory = $False)]
  [Hashtable[]] # any array of type[] should work
  $ArgArrayOfHashes,

  [Parameter(Mandatory = $False)]
  [IO.FileInfo] # aka a file path
  $ArgFileInfo,

  [Parameter(Mandatory = $False)]
  [Bool]
  $ArgBool,

  [Parameter(Mandatory = $False)]
  [TimeSpan]
  $ArgTimeSpan,

  [Parameter(Mandatory = $False)]
  [Guid]
  $ArgGuid,

  [Parameter(Mandatory = $False)]
  [Regex]
  $ArgRegex,

  [Parameter(Mandatory = $False)]
  [Switch]
  $ArgSwitch,

  # Parameters may have the string `type` in them, but not have the name `type`
  [Parameter(Mandatory = $False)]
  [String]
  $types
)

function ConvertTo-String
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
    $Object
  )

  begin
  {
    $outputs = @()
  }
  process
  {
    if ($Object -is [Hashtable])
    {
      $outputs += (HashtableTo-String $Object)
    }
    else
    {
      $outputs += $Object
    }
  }
  end
  {
    $outputs -join "`r`n"
  }
}

function HashtableTo-String
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
    [Hashtable]
    $Hashtable
  )

  ($Hashtable.GetEnumerator() | Sort-Object -Property Key | % { "$($_.Key): $($_.Value)" }) -join "`r`n"
}

Write-Output "Defined with arguments:"

$PSCmdlet.MyInvocation.MyCommand.Parameters.GetEnumerator() | Sort-Object -Property Key | Where-Object { $_.Key -match "Arg.+" } | % {
  Write-Output "* $($_.Key) of type $($_.Value.ParameterType)"
}

Write-Output "`r`nReceived arguments:"

$PSBoundParameters.GetEnumerator() | Sort-Object -Property Key | % {
  Write-Output "* $($_.Key) ($($_.Value.GetType())):`r`n$($_.Value | ConvertTo-String)"
}
