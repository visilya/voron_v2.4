#!/bin/bash

sudo service klipper stop

cd ~/klipper/
git pull
make clean

sudo sh ~/gpio.sh write 20 1 # dfu mode on
sudo sh ~/gpio.sh write 21 0 # reset on
sleep 1
sudo sh ~/gpio.sh write 21 1 # reset off
make flash FLASH_DEVICE=0483:df11
sudo sh ~/gpio.sh write 20 0 # dfu mode off
sudo sh ~/gpio.sh write 21 0 # reset on
sleep 1
sudo sh ~/gpio.sh write 21 1 # reset off

# Update MCU if you need
sudo service klipper_mcu stop
cd ~/klipper_mcu/
git pull
make clean
make flash
sudo service klipper_mcu start

# Update EBB if you need
cd ~/klipper_ebb/
git pull
make clean
make
python3 ~/CanBoot/scripts/flash_can.py -i can0 -f ./out/klipper.bin -u d22185cfd0c4

sudo service klipper start
