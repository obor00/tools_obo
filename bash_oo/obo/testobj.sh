#!/bin/bash

__testobj=0

testobj()
{
    __testobj=$(($__testobj+1))
    echo $__testobj
}

testobj.set.var1()
{
    shift
    testobj_var1[$1]="$@"
}

testobj.var1()
{
    echo ${testobj_var1[$1]}
}

testobj.set.var2()
{
    testobj_var1[$1]="$@"
}

testobj.var2()
{
    shift
    echo ${testobj_var2[$1]}
}

testobj.sum()
{
    shift
    echo "$1+$2" 
}

# test section
myobj=$(testobj)

echo "myobj=$myobj"

testobj.set.var1 $myobj "hello"
testobj.set.var2 $myobj "obo"

echo "+++"

testobj.var1 $myobj
testobj.var2 $myobj

result="$(testobj.sum $myobj $(testobj.var1 $myobj) $(testobj.var2 $myobj))"
echo "=== $result"


