#!/bin/bash

conf=config.h
conf_tmp=config_Makefile_tmp
minc=Makefile.inc

use_timing=1
use_signal=1
use_ncurses=0
debug=0

[ -f "config.local" ] && source config.local

rm -f $conf_tmp $minc

echo "#ifndef CONFIG_H_" >> $conf_tmp
echo "#define CONFIG_H_" >> $conf_tmp

if [ "$use_timing" == "1" ]; then
    echo "#define HAVE_TIMING" >> $conf_tmp
    echo "LDFLAGS += -lrt" >> $minc
fi
if [ "$use_signal" == "1" ]; then
    echo "#define HAVE_SIGNAL" >> $conf_tmp
fi
if [ "$use_ncurses" == "1" ]; then
    echo "#define HAVE_NCURSES" >> $conf_tmp
    echo "LDFLAGS += -lncurses" >> $minc
fi
if [ "$debug" == "1" ]; then
    echo "#define DEBUG" >> $conf_tmp
fi

echo -n "#define MINICOMP_VERSION \"" >> $conf_tmp
(git describe --dirty --always 2>/dev/null || echo 0) | tr '\n' '"' >> $conf_tmp
echo >> $conf_tmp

echo "#endif" >> $conf_tmp

echo "CFLAGS += -DHAVE_CONFIG_H" >> $minc

if ! cmp $conf_tmp $conf > /dev/null 2>&1
then mv $conf_tmp $conf
else rm $conf_tmp
fi

