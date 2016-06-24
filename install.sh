#!/bin/sh
#http://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`
if [ -z "$1" ]
    then
        echo "You need to specify installation root"
        exit 1
fi
install -d -v $1/usr/local/verilog/
install -d -v $1/usr/local/bin/
install -v -m 0755 $SCRIPTPATH/py393/*.py $1/usr/local/bin/
#install -v -m 0755 $SCRIPTPATH/py393/*.pyc $1/usr/local/bin/

install -d -v $1/www/pages/
install -v -m 0755 $SCRIPTPATH/py393/imgsrv.py $1/www/pages/
#unistall
rm $1/usr/local/bin/imgsrv.py

install -v -m 0644 $SCRIPTPATH/*.bit $1/usr/local/verilog/

install -v -m 0644 $SCRIPTPATH/system_defines.vh $1/usr/local/verilog/
install -v -m 0644 $SCRIPTPATH/includes/x393_parameters.vh $1/usr/local/verilog/
install -v -m 0644 $SCRIPTPATH/includes/x393_localparams.vh $1/usr/local/verilog/
install -v -m 0644 $SCRIPTPATH/includes/x393_cur_params_target.vh $1/usr/local/verilog/
install -v -m 0644 $SCRIPTPATH/py393/hargs      $1/usr/local/verilog/
install -v -m 0644 $SCRIPTPATH/py393/hargs-auto $1/usr/local/verilog/
install -v -m 0644 $SCRIPTPATH/py393/includes   $1/usr/local/verilog/
install -v -m 0644 $SCRIPTPATH/py393/startup5   $1/usr/local/verilog/
install -v -m 0644 $SCRIPTPATH/py393/startup14  $1/usr/local/verilog/

exit 0
