#!/bin/bash

ff1() { local -n ff1_val=$1; echo "!!!${ff1_val[@]}!!!" ; }

ff() { local -n val=$1; echo ${val[@]}; ff1 val ; }

toto=TOTO
myvar=( hello from here $toto \; ls \; uname -a )

ff myvar

