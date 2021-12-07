#!/bin/bash
 
# Import the class definition file.
. vector.sh
 
function main()
{
    # Create the vectors objects. (1)
    Vector 'vector1' 1 2 3
    Vector 'vector2' 7 5 3
 
    # Show it's properties. (2)
    echo "vector1 ($vector1_x, $vector1_y, $vector1_z)"
    echo "vector2 ($vector2_x, $vector2_y, $vector2_z)"
 
    # Call to it's methods.
    $vector1_show
    $vector2_show
 
    $vector1_add vector2
}
 
main
