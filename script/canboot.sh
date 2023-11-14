#!/bin/bash

cd ~/CanBoot
make clean
make KCONFIG_CONFIG=~/printer_data/config/script/CanBoot.cfg
sudo dfu-util -a 0 -D ~/CanBoot/out/canboot.bin --dfuse-address 0x08000000:force:mass-erase:leave -d 0483:df11
