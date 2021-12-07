#!/bin/bash

ClassName() {
    # A pointer to this Class. (2)
    base=$FUNCNAME
    this=$1

    # Inherited classes (optional).
    export ${this}_inherits="Class1 Class2 Class3" # (3.1)
    for class in $(eval "echo \$${this}_inherits")
    do
        for property in $(compgen -A variable ${class}_)
        do
            export ${property/#$class\_/$this\_}="${property}" # (3.2)
        done

        for method in $(compgen -A function ${class}_)
        do
            export ${method/#$class\_/$this\_}="${method} ${this}"
        done
    done

    # Declare Properties.
    export ${this}_x=$2
    export ${this}_y=$3
    export ${this}_z=$4

    # Declare methods.
    for method in $(compgen -A function); do
        export ${method/#$base\_/$this\_}="${method} ${this}"
    done
}

function ClassName_MethodName()
{
    #base is where the magic happens, its what holds the class name
    base=$(expr "$FUNCNAME" : '\([a-zA-Z][a-zA-Z0-9]*\)')
    this=$1

    x=$(eval "echo \$${this}_x")

    echo "$this ($x)"
}
