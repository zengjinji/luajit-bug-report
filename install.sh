##!/bin/bash

path=`pwd`


#### LUAJIT
wget https://github.com/openresty/luajit2/archive/v2.1-20190221.tar.gz; tar -zxvf v2.1-20190221.tar.gz
cd luajit2-2.1-20190221/
make install CCDEBUG=-g XCFLAGS='-msse4.2' PREFIX=$path/luajit
export LUAJIT_LIB=$path/luajit/lib
export LUAJIT_INC=$path/luajit/include/luajit-2.1
export LD_LIBRARY_PATH=$path/luajit/lib

#### nginx
cd $path
mkdir logs
wget http://nginx.org/download/nginx-1.14.2.tar.gz;tar -zxvf nginx-1.14.2.tar.gz
wget https://github.com/openresty/lua-nginx-module/archive/v0.10.14.tar.gz;tar -zxvf v0.10.14.tar.gz
wget https://codeload.github.com/simplresty/ngx_devel_kit/tar.gz/v0.3.1rc1;tar -zxvf v0.3.1rc1
cd nginx-1.14.2/
./configure  --prefix=$path/nginx --add-module=$path/ngx_devel_kit-0.3.1rc1 --add-module=$path/lua-nginx-module-0.10.14
make install

#### start
#cd $path
#./nginx/sbin/nginx -p . -c nginx.conf
