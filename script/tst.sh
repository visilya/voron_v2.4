#!/bin/bash
### Start config ###
MCU_NAME=mcu

OCTOPUS_NAME=octopus
OCTOPUS_CAN=ce5f75f5c4f0
OCTOPUS_SERIAL_ID=usb-CanBoot_stm32f429xx_2E004E001450304738313820-if00

EBB_NAME=ebb
EBB_CAN=d22185cfd0c4
### End config ###

cd ~/klipper/
git pull
make clean

build_klipper() {
  echo ----------- $1 ----------- 
  KCONFIG_FILE=~/klipper_config/script/klipper_$1.cfg
  if [! -f "$KCONFIG_FILE" ]; then
    echo "$KCONFIG_FILE does not exists."
    read -p "Do you want to configure $1? [Y:n]" -n 1 -r REPLY
    REPLY=${REPLY:-Y}
    if [[ $REPLY =~ ^[Yy]$ ]]; then
       make menuconfig $KCONFIG_FILE
    else
      read -p "Abort bash file? [y:N]" -n 1 -r REPLY
      REPLY=${REPLY:-N}
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi       
    fi
  fi
  if [ -f "$KCONFIG_FILE" ]; then
    sed -i -e '1iOUT=out_'"$1"'/' -e '/OUT=/d' $KCONFIG_FILE
    make clean KCONFIG_CONFIG=$KCONFIG_FILE
  fi
}

build_klipper $MCU_NAME
make flash KCONFIG_CONFIG=$KCONFIG_FILE

build_klipper $OCTOPUS_NAME
python3 ~/CanBoot/scripts/flash_can.py -i can0 -f ~/klipper/out_$TARGET/klipper.bin -u $OCTOPUS_CAN
python3 ~/CanBoot/scripts/flash_can.py -f ~/klipper/out_$TARGET/klipper.bin -d /dev/serial/by-id/$OCTOPUS_SERIAL_ID

build_klipper $EBB_NAME
python3 ~/CanBoot/scripts/flash_can.py -i can0 -f ~/klipper/out_$TARGET/klipper.bin -u $EBB_CAN
