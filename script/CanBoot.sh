#!/bin/bash

cd ~/CanBoot
make clean
make KCONFIG_CONFIG=~/klipper_config/script/CanBoot.cfg

