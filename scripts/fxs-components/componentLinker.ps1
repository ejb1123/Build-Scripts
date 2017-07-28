Param(
[string]$SrcDir = ".",
[string]$WorkDir = "C:\fivem\dev\fivem"
)
Push-Location -Path "$SrcDir\components"

Get-ChildItem -Path "." | foreach {
    $fullname = $_.FullName
    if($(Test-Path "$fullname\component.json") -eq $true){
        $ll = $_.Name
        $j = Get-Content "$fullname\component.json" | ConvertFrom-Json
        $l= $j.name
        if(Test-Path "$WorkDir\code\components\config.lua"){
            $config1 = Get-Content "$WorkDir\code\components\config.lua"
            if($config1.Contains("component `'$l`'")){
                "contains"
            }
            else{
                Add-Content -Value "component `'fs-web`'`n" -Path "$WorkDir\code\components\config.lua" -Encoding UTF8
            }
            echo $fullname
            if(! $(Test-Path -PathType Container "$WorkDir\code\components\$l") -or $(Get-ItemPropertyValue -Path "$WorkDir\code\components\$ll" -Name "LinkType" ) -ne "Junction"){
                New-Item -Path "$WorkDir\code\components" -ItemType Junction -Name $ll -Value "$fullname" -Force
            }
        }
    }

    Pop-Location
}