curl -O https://runtime.fivem.net/client/cfx-server.7z
p7zip -d cfx-server.7z
rm -rf cfx-server.7z
pushd cfx-server
#TODO add CI mod to AutostartResources in citmp.yml
#TODO copy CI mod to resources folder

#TODO 
#if CI_STATUS line one equals fail then
exit 1
#else
#if  CI_STATUS line one equals pass then
# exit 0
