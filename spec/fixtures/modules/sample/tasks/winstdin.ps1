$line = [Console]::In.ReadLine()
Write-Output "STDIN: $line"
Write-Output "ENV: $env:PT_message_one $env:PT_message_two"
