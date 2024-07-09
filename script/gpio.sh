# usage:
# >sudo sh gpio.sh <action> <pin> <value>
# reading example:
# >sudo sh gpio.sh read 1
# >0
# writing example:
# >sudo sh gpio.sh write 3 1

#!/bin/bash

#assign parameters
action=$1
pin=$2
value=$3

if [ $action = "read" ];then
  gpioget 0 $pin
elif [ $action = "write" ];then
  gpioset 0 $pin=$value
  gpioget 0 $pin
else
   	echo "Unknown parameter"
fi
