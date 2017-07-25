param (
    [string] $mode = ""
)
function CheckPython() {
    $testPath = "HKLM:\SOFTWARE\Python\PythonCore\2.7\InstallPath"
  
  
    if (Test-Path $testPath) {
        return $true
    }
    elseif (Test-Path "C:\FiveM-dev\python27") { 
        return $true
    }
    else {
        return $false
    }
}

function CreateMainPath() {
    New-Item -ItemType Directory .\libs
}

function DownloadPythonInstaller() {
    $url = "https://www.python.org/ftp/python/2.7.13/python-2.7.13.amd64.msi"
    $output = "$env:TEMP\python27installer.msi"
    $start_time = Get-Date
  
    Invoke-WebRequest -Uri $url -OutFile $output
    Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}

function InstallPython() {
    DownloadPythonInstaller
    msiexec.exe /i "$env:TEMP\python27installer.msi" /norestart  /qb ADDLOCAL=ALL TARGETDIR=.\libs\python27 ALLUSERS=0  
}

function CheckPremake5() {
    if (Test-Path -Path .\libs\Premake5\Premake5.exe) {
        return $true
    }
    else {
        return $false;
    }
}

function InstallPremake5 () {
    7z x "$env:TEMP\premake-5.0.0-alpha11-windows.zip" -olibs\Premake5
}

function DownloadPremake5() {
    $url = "https://github.com/premake/premake-core/releases/download/v5.0.0-alpha11/premake-5.0.0-alpha11-windows.zip"
    $output = "$env:TEMP\premake-5.0.0-alpha11-windows.zip"
    $start_time = Get-Date
    #Invoke-WebRequest -Uri $url -OutFile $output
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $output)
    Write-Output "Time taken: $((Get-Date).Subtract($start_time).TotalSeconds) second(s)"
}
function CheckBoost () {
    if ($(Test-Path -Path .\libs\boost_1_64_0) -and $($(Get-ChildItem .\libs\boost_1_64_0 | Measure-Object ).Count -gt 0)) {
        return $true
    }
    else {
        return $false
    }
}
function DownloadBoost () {
    Remove-Item -Path ".\boost_1_64_0.zip" -Force -Recurse -ErrorAction SilentlyContinue
    $url = "https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.zip"
    $output = ".\boost_1_64_0.zip"
    if (!(Test-Path -Path "boost_1_64_0.zip")) {
        $start_time = Get-Date 
        #Start-BitsTransfer -Source "https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.zip" -Destination "boost_1_64_0.zip"
        Invoke-WebRequest -Uri $url -OutFile $output -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome
        Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    }
}
function InstallBoost () {
    Remove-Item -Path ".\libs\boost_1_64_0" -Recurse -Force -ErrorAction SilentlyContinue
    & "C:\Program Files\7-Zip\7z.exe" x "boost_1_64_0.zip" -olibs
}

If (-Not $(Test-Path -Path .\libs)) {
    CreateMainPath
}

if ($mode -eq "premake") {
    if (CheckPython) {
        "Python Exists"
    }
    else {
        "Installing Python"
        InstallPython
    }
}
if ($mode -eq "premake") {
    if (CheckPremake5) {
        "Premake5 exists"
    }
    else {
        "Downloading Premake5"
        DownloadPremake5
        "Installing Premake5"
        InstallPremake5
    }
}
if ($mode -eq "boost") {
    if (CheckBoost) {
        "Boost exists"
    }
    else {
        "Downloading Boost"
        DownloadBoost
        "Installing Boost"
        InstallBoost
    }
}

