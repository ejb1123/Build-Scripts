FROM microsoft/windowsservercore
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue';"]

RUN setx /M PATH $($Env:PATH + ';' + ${Env:ProgramFiles(x86)} + '\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin')
RUN iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
RUN choco install -y 7zip python2 vswhere microsoft-build-tools visualcpp-build-tools git

# RUN install-package -Force -Name "python2,git,vswhere,"
COPY Installer.ps1 .
COPY boost_1_64_0.7z .
RUN & 'C:\\Program Files\7-Zip\7z.exe' x -oC:\FiveM boost_1_64_0.7z
# RUN Expand-Archive -Path ".\boost_1_64_0.7z" -DestinationPath C:\FiveM-dev\Boost
ENV BOOST_ROOT=C:\FiveM-dev\boost_1_64_0


RUN .\Installer.ps1 -mode premake
RUN setx /m PATH $($ENV:PATH + ';' + 'C:\FiveM-dev\Premake5')
WORKDIR C:\\Fivem-dev
COPY fivem.ps1 .
RUN .\fivem.ps1
ENV FIVEM_SOURCE=C:\FiveM-dev\fivem