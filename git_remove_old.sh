#!/bin/bash

list=$(git branch --all  | grep bordes)

for i in $list 
do 
    name=${i/remotes\/origin\//} 
    echo $name
    echo -n "confirm (y/n) ? " 
    read resp 
    if [[ "$resp" == "y" ]] ; then
        git push --delete origin $name
    fi
done

