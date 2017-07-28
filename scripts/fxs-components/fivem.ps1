param (
    #[Parameter(Mandatory=$true)]
    [string]
    $WorkDir = "C:\f\work",

    #[Parameter(Mandatory=$true)]
    [string]
    $SaveDir = "C:\f\save",

    [string]
    $Branch = "master",

    [bool]
    $DontUpload = $false,

    [bool]
    $DontBuild = $false
)

# from http://stackoverflow.com/questions/2124753/how-i-can-use-powershell-with-the-visual-studio-command-prompt
function Invoke-BatchFile {
    param([string]$Path)

    $tempFile = [IO.Path]::GetTempFileName()

    ## Store the output of cmd.exe.  We also ask cmd.exe to output
    ## the environment table after the batch file completesecho
    cmd.exe /c " `"$Path`" && set > `"$tempFile`" "

    ## Go through the environment variables in the temp file.
    ## For each of them, set the variable in our local environment.
    Get-Content $tempFile | Foreach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            Set-Content "env:\$($matches[1])" $matches[2]
        }
    }

    Remove-Item $tempFile
}


$IsServer = $false
$UploadType = "client"

if ($env:IS_FXSERVER -eq 1) {
    $IsServer = $true
    $UploadType = "server"
}

$Branch = "master"
$WorkDir = $WorkDir -replace '/', '\'

if ($IsServer) {
    $UploadBranch += " SERVER"
}

$WorkRootDir = "$WorkDir\code\"

$BinRoot = "$SaveDir\bin\$UploadType\" -replace '/', '\'
$BuildRoot = "$SaveDir\build\$UploadType\" -replace '/', '\'

$env:TargetPlatformVersion = "10.0.15063.0"

Add-Type -A 'System.IO.Compression.FileSystem'

New-Item -ItemType Directory $SaveDir -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory $WorkDir -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory $BinRoot -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory $BuildRoot -ErrorAction SilentlyContinue | Out-Null

Set-Location $WorkRootDir

$GlobalTag = git describe

if ((Get-Command "python.exe" -ErrorAction SilentlyContinue) -eq $null) {
    $env:Path = "C:\python27\;" + $env:Path
}

if (!($env:BOOST_ROOT)) {
    if (Test-Path C:\Libraries\boost_1_64_0) {
        $env:BOOST_ROOT = "C:\Libraries\boost_1_64_0"
    }
    else {
        $env:BOOST_ROOT = "C:\dev\boost_1_60_0"
    }
}

if (!$DontBuild) {

    Write-Host "[checking if repository is latest version]" -ForegroundColor DarkMagenta

    $VCDir = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7)."15.0"

    if (!(Test-Path Env:\DevEnvDir)) {
        Invoke-BatchFile "$VCDir\VC\Auxiliary\Build\vcvars64.bat"
    }

    if (!(Test-Path Env:\DevEnvDir)) {
        throw "No VC path!"
    }

    Write-Host "[updating submodules]" -ForegroundColor DarkMagenta
    Push-Location $WorkDir

    git submodule init

    $SubModules = git submodule | ForEach-Object { New-Object PSObject -Property @{ Hash = $_.Substring(1).Split(' ')[0]; Name = $_.Substring(1).Split(' ')[1] } }

    foreach ($submodule in $SubModules) {
        $SubmodulePath = git config -f .gitmodules --get "submodule.$($submodule.Name).path"
        $SubmoduleRemote = git config -f .gitmodules --get "submodule.$($submodule.Name).url"

        $Tag = (git ls-remote --tags $SubmoduleRemote | Select-String -Pattern $submodule.Hash) -replace '^.*tags/([^^]+).*$', '$1'

        if (!$Tag) {
            git clone $SubmoduleRemote $SubmodulePath
        }
        else {
            git clone -b $Tag --depth 1 --single-branch $SubmoduleRemote $SubmodulePath
        }
    }

    git submodule update

    Pop-Location

    Write-Host "[running prebuild]" -ForegroundColor DarkMagenta
    Push-Location $WorkDir
    .\prebuild.cmd
    Pop-Location

    Write-Host "[building]" -ForegroundColor DarkMagenta
    
    $GameName = "five"
    $BuildPath = "$BuildRoot\five"

    if ($IsServer) {
        $GameName = "server"
        $BuildPath = "$BuildRoot\server\windows"
    }

    Invoke-Expression "& $WorkRootDir\tools\ci\premake5 vs2017 --game=$GameName --builddir=$BuildRoot --bindir=$BinRoot"

    $GameVersion = ((git rev-list HEAD | measure-object).Count * 10) + 1100000
    $LauncherVersion = $GameVersion

    "#pragma once
    #define BASE_EXE_VERSION $GameVersion" | Out-File -Force shared\citversion.h

    "#pragma once
    #define GIT_DESCRIPTION ""$UploadBranch $GlobalTag win32""" | Out-File -Force shared\cfx_version.h

    # remove-item env:\platform

    #echo $env:Path
    #/logger:C:\f\customlogger.dll /noconsolelogger
    msbuild /p:preferredtoolarchitecture=x64 /p:configuration=release /v:q /fl /m:4 $BuildPath\CitizenMP.sln

    if (!$?) {
        #Invoke-WebHook "Building FiveM failed :("
        throw "Failed to build the code."
    }
}

Set-Location $WorkRootDir
$GameVersion = ((git rev-list HEAD | measure-object).Count * 10) + 1100000
$LauncherVersion = $GameVersion

if (!$DontBuild -and $IsServer) {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $WorkDir\out

    New-Item -ItemType Directory -Force $WorkDir\out | Out-Null
    New-Item -ItemType Directory -Force $WorkDir\out\server | Out-Null

    Copy-Item -Force $BinRoot\server\windows\release\*.exe $WorkDir\out\server\
    Copy-Item -Force $BinRoot\server\windows\release\*.dll $WorkDir\out\server\

    Copy-Item -Force -Recurse $WorkDir\data\shared\* $WorkDir\out\server\
    Copy-Item -Force -Recurse $WorkDir\data\server\* $WorkDir\out\server\
    Copy-Item -Force -Recurse $WorkDir\data\server_windows\* $WorkDir\out\server\

    Copy-Item -Force -Recurse $BinRoot\server\windows\release\citizen\* $WorkDir\out\server\citizen\

    Copy-Item -Force "$WorkRootDir\tools\ci\7z.exe" 7z.exe

    .\7z.exe a $WorkDir\out\server.zip $WorkDir\out\server\*

    #Invoke-WebHook "Bloop, building a SERVER/WINDOWS build completed!"
}

if (!$DontBuild -and !$IsServer) {
    # prepare caches
    New-Item -ItemType Directory -Force $WorkDir\caches | Out-Null
    New-Item -ItemType Directory -Force $WorkDir\caches\fivereborn | Out-Null
    Set-Location $WorkDir\caches

    # create cache folders

    # copy output files
    Copy-Item -Force $BinRoot\five\release\*.dll $WorkDir\caches\fivereborn\
    Copy-Item -Force $BinRoot\five\release\*.com $WorkDir\caches\fivereborn\

    Copy-Item -Force -Recurse $WorkDir\data\shared\* $WorkDir\caches\fivereborn\
    Copy-Item -Force -Recurse $WorkDir\data\client\* $WorkDir\caches\fivereborn\

    Copy-Item -Force -Recurse $BinRoot\five\release\citizen\* $WorkDir\caches\fivereborn\citizen\

    if (Test-Path C:\f\tdd2) {
        Copy-Item -Force -Recurse C:\f\tdd2\citizen\ui.rpf $WorkDir\caches\fivereborn\citizen\
    }

    Copy-Item -Force -Recurse $WorkDir\vendor\cef\Release\*.dll $WorkDir\caches\fivereborn\bin\
    Copy-Item -Force -Recurse $WorkDir\vendor\cef\Release\*.bin $WorkDir\caches\fivereborn\bin\

    New-Item -ItemType Directory -Force $WorkDir\caches\fivereborn\bin\cef

    Copy-Item -Force -Recurse $WorkDir\vendor\cef\Resources\icudtl.dat $WorkDir\caches\fivereborn\bin\
    Copy-Item -Force -Recurse $WorkDir\vendor\cef\Resources\*.pak $WorkDir\caches\fivereborn\bin\cef\
    Copy-Item -Force -Recurse $WorkDir\vendor\cef\Resources\locales\en-US.pak $WorkDir\caches\fivereborn\bin\cef\

    # build meta/xz variants
    "<Caches>
        <Cache ID=`"fivereborn`" Version=`"$GameVersion`" />
    </Caches>" | Out-File -Encoding ascii $WorkDir\caches\caches.xml

    Copy-Item -Force "$WorkRootDir\tools\ci\xz.exe" xz.exe

    Invoke-Expression "& $WorkRootDir\tools\ci\BuildCacheMeta.exe"

    # build bootstrap executable
    Copy-Item -Force $BinRoot\five\release\FiveM.exe CitizenFX.exe

    if (Test-Path CitizenFX.exe.xz) {
        Remove-Item CitizenFX.exe.xz
    }

    Invoke-Expression "& $WorkRootDir\tools\ci\xz.exe -9 CitizenFX.exe"

    Invoke-WebRequest -Method POST -UseBasicParsing "https://crashes.fivem.net/management/add-version/1.3.0.$GameVersion"

    $LauncherLength = (Get-ItemProperty CitizenFX.exe.xz).Length
    "$LauncherVersion $LauncherLength" | Out-File -Encoding ascii version.txt
}

