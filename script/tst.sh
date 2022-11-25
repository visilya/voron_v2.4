#!/bin/bash
### Start config ###
MCU_NAME=mcu

OCTOPUS_NAME=octopus1
OCTOPUS_CAN=ce5f75f5c4f0
OCTOPUS_SERIAL_ID=usb-CanBoot_stm32f429xx_2E004E001450304738313820-if00

EBB_NAME=ebb1
EBB_CAN=d22185cfd0c4
### End config ###

ask=$1
forceflash=$2

build_klipper() {
  echo ----------- $1 ----------- 
  KCONFIG_FILE=~/klipper_config/script/klipper_$1.cfg
  if [ ! -f "$KCONFIG_FILE" ]; then
    if [[ "$ask" == "1" ]]; then
      echo "$KCONFIG_FILE does not exists."
      read -p "Do you want to configure $1? [Y:n]" -n 1 -r REPLY
      REPLY=${REPLY:-Y}
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        make menuconfig KCONFIG_CONFIG=$KCONFIG_FILE
      else 
        read -p "Abort bash file? [y:N]" -n 1 -r REPLY
        REPLY=${REPLY:-N}
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          exit 1
        fi
      fi
    else
      echo "$KCONFIG_FILE does not exists."
      exit 1
    fi
  fi
  if [ -f "$KCONFIG_FILE" ]; then
    # sed -i -e '1iOUT=out_'"$1"'/' -e '/OUT=/d' $KCONFIG_FILE
    sed -i -e '/OUT=/d' $KCONFIG_FILE
    make clean KCONFIG_CONFIG=$KCONFIG_FILE -e OUT=out_"$1"/
    if [[ "$2" == "build" ]]; then
      make KCONFIG_CONFIG=$KCONFIG_FILE -e OUT=out_"$1"/
    fi
  fi
}

main() {
  cd ~/klipper/
  klipper_ver=$(git rev-parse HEAD)
  git pull
  if [[ $klipper_ver == $(git rev-parse HEAD)]] && ! [["$forceflash" == "1" ]]; then
    # Same klipper version. 
    echo "Exiting."
    exit 0
  fi

  make clean

  build_klipper $MCU_NAME
  rm -rf ~/klipper/out
  mv ~/klipper/out_$MCU_NAME ~/klipper/out
  make flash KCONFIG_CONFIG=$KCONFIG_FILE
  mv ~/klipper/out ~/klipper/out_$MCU_NAME

  build_klipper $OCTOPUS_NAME build
  python3 ~/CanBoot/scripts/flash_can.py -i can0 -f ~/klipper/out_$OCTOPUS_NAME/klipper.bin -u $OCTOPUS_CAN
  python3 ~/CanBoot/scripts/flash_can.py -f ~/klipper/out_$OCTOPUS_NAME/klipper.bin -d /dev/serial/by-id/$OCTOPUS_SERIAL_ID

  build_klipper $EBB_NAME build
  python3 ~/CanBoot/scripts/flash_can.py -i can0 -f ~/klipper/out_$EBB_NAME/klipper.bin -u $EBB_CAN
  ~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0

}

main
exit 0
