# Script reads the 3D printer log files and builds a file based upon critical data that is used to report on jobs, resin uses, number of stops, ect.
#Get working Directory
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

#Set the 3D Analysis file
$3DAnalysis = $PSScriptRoot + "\3DAnalysis1.csv"

#Set 3D Log Location
$3DFiles = "I:\"

# Check 3D Analysis file
$logfilepath = (Test-Path $3DFiles)
$logfilepath
if ($logFilePath -MATCH "False")
{
	Write-Host "Invalid 3D Log Location entered: " + $3dFiles -foregroundcolor red -backgroundcolor yellow
}
else
{
	$3dFileCount = Get-ChildItem -Path $3DFiles -filter *.csv -file | Measure-Object | %{ $_.Count }
	If ($3dFileCount -gt 0)
	{
		# Check 3D Analysis file
		$logfilepath = (Test-Path $3DAnalysis)
		if (($logFilePath) -match "False")
		{
			New-Item $3DAnalysis -ItemType File
			
			Add-Content $3DAnalysis "3D LogFile, Resin File, Resin Type, Rows, Start Time, Compensation Count, Total Layers, Start Layer, PreBuild Layers, PreBuild End Time, PreBuild Status, Build Layers, Build End Time, Build Status, Altitude 1, Altitude 2, 1st Thickness, 2nd Thickness, Files"
		}
		$FileC = 1
		#$ParametersFile =''
		Get-ChildItem $3dFiles -Filter *.csv |
		Foreach-Object {
			$content = Get-Content $_.fullname
			Write-Output "Processing File # $FileC - $_"
			$ParametersFile = $_.fullname.replace("build_log", "parameters")
			$ParametersFile = $ParametersFile.replace(".csv", ".phd")
			$ParametersFile = $ParametersFile
			$Row = 0
			
			$FileNameExtension = '.stl'
			$FilePaths = 'File(s):'
			$CompensationMesage = 'A compensation from recoater sink done'
			$CompensationCount = 0
			$StartLayer = ''
			$StartLayerStat = 0
			$LayeringMessage = 'Starting layer'
			$LayerStartTimeold = 0
			$LayerStartTime = 0
			
			$AltitudeMessage = 'Altitude \(mm\):'
			$Altitude = 0
			$Altitude1 = ''
			$Altitude2 = ''
			
			$LayerThickness = 'Layer thickness\(mm\):'
			$Thickness1 = ''
			$Thickness2 = ''
			
			$PreBuildZero = "0:00:00"
			$PreBuildZeroLayer = 'No prebuild'
			$PreBuildZeroTime = 'No prebuild'
			$PreBuildZeroCompletionMessage = 'No prebuild'
			$PreBuildZeroStat = 0
			$PreBuildStat = 0
			$PreBuildLayerCount = 0
			$PreBuildCompletionMessage = 'PreBuild completed normally'
			$PreBuildCompletionFailure = 'Did not reach altitude of 8.6mm'
			
			$BuildCompletionMessage1 = 'Build completed normally'
			$BuildCompletionMessage2 = 'The build has been stopped by the user'
			$BuildCompletionMessage3 = 'Build paused'
			$BuildCompletionFailure = 'See log for reason'
			
			$StopCompletion = 'False'
			
			foreach ($line in $content)
			{
				$Row += 1
				If ($Row -eq 1)
				{
					$StartTime = $Line
					$StartTime = [regex]::Matches($StartTime, '(\d{2}/\d{2}/\d{2}.+) :').value
					$StartTime = $StartTime.replace(" :", "")
				}
				
				if ($Line -match $PreBuildZero)
				{
					$PreBuildStat = 1
					$PreBuildZeroStat = 1
					$PreBuildLayerCount = $PreBuildZeroLayer
					$PreBuildEndTime = $PreBuildZeroTime
					$PreBuildCompletionStaus = $PreBuildZeroCompletionMessage
				}
				
				if ($line -match $FileNameExtension)
				{
					$FilePaths = $FilePaths + $Line + ';'
				}
				
				if ($Line -match $CompensationMesage)
				{
					$CompensationCount += 1
				}
				if ($line -match $LayeringMessage)
				{
					$LayerStartTimeold = $LayerStartTime
					$LayerCount = $Line
					$LayerStartTime = [regex]::Matches($LayerCount, '(\d{2}/\d{2}/\d{2}.+) :').value
					$LayerStartTime = $LayerStartTime.replace(" :", "")
					$LayerCount = $LayerCount.substring(25)
					$LayerCount = $LayerCount.replace("-", "")
					$LayerCount = $LayerCount.replace($LayeringMessage, "")
					$LayerCount = $LayerCount.replace(" ", "")
					if ($StartLayerStat -eq 0)
					{
						$StartLayer = $LayerCount
						$StartLayerStat = 1
					}
				}
				
				if ($Line -match $AltitudeMessage)
				{
					$Altitude = $line.replace("Altitude (mm): ", "")
					$AltitudeCheck
					if ($Altitude -gt 8.6 -and $PreBuildStat -eq 0)
					{
						$PreBuildLayerCount = $LayerCount - 1
						$PreBuildEndTime = $LayerStartTimeold
						$PreBuildCompletionStaus = $PreBuildCompletionMessage
						$PreBuildStat = 1
					}
					
					elseif ($Altitude -le 8.6 -and $PreBuildStat -eq 0)
					{
						$PreBuildLayerCount = $LayerCount
						$PreBuildEndTime = $LayerStartTime
						$PreBuildCompletionStaus = $PreBuildCompletionFailure
					}
					
					If ($Altitude1 -eq '')
					{
						$Altitude1 = $Line
					}
					else
					{
						$Altitude2 = $Line
					}
					
				}
				
				if ($line -match $LayerThickness)
				{
					If ($Thickness1 -eq '')
					{
						$Thickness1 = $Line
					}
					else
					{
						$Thickness2 = $Line
					}
				}
				
				if ($line -match $BuildCompletionMessage1 -or $line -match $BuildCompletionMessage2 -or $line -match $BuildCompletionMessage3)
				{
					If ($PreBuildStat -eq 1)
					{
						If ($line -match $BuildCompletionMessage1)
						{ $BuildCompletionStaus = $BuildCompletionMessage1 }
						elseif ($line -match $BuildCompletionMessage2)
						{ $BuildCompletionStaus = $BuildCompletionMessage2 }
						elseif ($line -match $BuildCompletionMessage3)
						{ $BuildCompletionStaus = $BuildCompletionMessage3 }
						else
						{ }
						$BuildCompletion = 1
						$BuildEndTime = $Line
						$BuildEndTime = [regex]::Matches($BuildEndTime, '(\d{2}/\d{2}/\d{2}.+) :').value
						if ($BuildEndTime -ne $null)
						{
							$BuildEndTime = $BuildEndTime.replace(" :", "")
						}
						$StopCompletion = 1
					}
					else
					{
						
						$BuildCompletionStaus = $BuildCompletionFailure
						
					}
				}
				if ($StopCompletion -eq 'False')
				{
					$BuildEndTime = $Line
					$BuildEndTime = [regex]::Matches($BuildEndTime, '(\d{2}/\d{2}/\d{2}.+) :').value
					if ($BuildEndTime -ne $null)
					{
						$BuildEndTime = $BuildEndTime.replace(" :", "")
					}
				}
				
				if ($PreBuildStat -eq 1 -and $PreBuildZeroStat -eq 0)
				{
					$BuildLayerCount = $LayerCount - $PreBuildLayerCount
					$TotalLayers = $LayerCount - $StartLayer
				}
				if ($PreBuildStat -eq 1 -and $PreBuildZeroStat -eq 1)
				{
					$BuildLayerCount = $LayerCount - $StartLayer
					$TotalLayers = $LayerCount - $StartLayer
				}
				
			}
			
			$ResinTypeContent = 'current resin'
			$ResinStat = 0
			$ResinFileError = 'DNE'
			$ResinError = 'Resin Type Unknown'
			$ParamPath = (Test-Path $ParametersFile)
			if (($ParamPath) -match "True")
			{
				$ResinFile = $ParametersFile
				$paramcontent = Get-Content $ParametersFile
				foreach ($ParamLine in $paramcontent)
				{
					if ($ParamLine -match $ResinTypeContent)
					{
						$Resin = $ParamLine
						$Resin = $Resin.replace("leaf[current resin]  = ", "")
						$Resin = $Resin.replace(";", "")
						$ResinStat = 1
					}
					
				}
				If ($ResinStat -eq 0)
				{
					$Resin = $ResinError
				}
			}
			else
			{
				$ResinFile = "NF: $ParametersFile"
				$Resin = $resinFileError
			}
			
			
			Add-Content $3DAnalysis "$_, $ResinFile, $Resin, $Row, $StartTime, $CompensationCount, $TotalLayers, $StartLayer, $PreBuildLayerCount, $PreBuildEndTime, $PreBuildCompletionStaus, $BuildLayerCount, $BuildEndTime, $BuildCompletionStaus, $Altitude1, $Altitude2, $Thickness1, $Thickness2, $FilePaths"
			$FileC += 1
		}
	}
	else
	{
		write-host "Error 3d File Count - $3dFileCount"
	}
	
}

