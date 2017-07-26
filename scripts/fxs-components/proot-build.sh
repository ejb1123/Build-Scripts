#!/bin/sh
set -e


# get an alpine rootfs
curl -sLo alpine-minirootfs-3.6.1-x86_64.tar.gz http://mirrors.gigenet.com/alpinelinux/latest-stable/releases/x86_64/alpine-minirootfs-3.6.1-x86_64.tar.gz

# get our patched proot build
# source code: https://runtime.fivem.net/build/proot-v5.1.1.tar.gz
curl -sLo proot-x86_64 https://runtime.fivem.net/build/proot-x86_64
chmod +x proot-x86_64


# clone fivem-private
#git clone https://github.com/citizenfx/fivem.git

#echo "private_repo '../../fivem-private/'" > fivem/code/privates_config.lua

# start building
cd fivem

# extract the alpine root FS
mkdir alpine
cd alpine
tar xf ../alpine-minirootfs-3.6.1-x86_64.tar.gz
cd ..

echo '#pragma once' > code/shared/cfx_version.h
echo '#define GIT_DESCRIPTION "1000 v1.0.0 0 linux"' >> code/shared/cfx_version.h



# build
./proot-x86_64 -S $PWD/alpine/ -b $PWD/:/src/ /bin/sh /src/code/tools/ci/build_server_2.sh

# package artifacts
cp data/server_proot/run.sh run.sh
chmod +x run.sh
mv proot-x86_64 proot

tar cJf fx.tar.xz alpine/ proot run.sh