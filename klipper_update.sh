#!/bin/bash
# Get CAN devicies id
# ~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0

### Start config ###
MCU_NAME=mcu

OCTOPUS_NAME=octopus
OCTOPUS_CAN=ce5f75f5c4f0
# OCTOPUS_SERIAL_ID=usb-CanBoot_stm32f429xx_2E004E001450304738313820-if00

EBB_NAME=ebb
EBB_CAN=d22185cfd0c4

WORKING_DIR=/home/ilya
### End config ###


ask=$1
forceflash=$2

build_klipper() {
  echo ----------- $1 -----------
  KCONFIG_FILE=$WORKING_DIR/klipper_config/script/klipper_$1.cfg
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
  if [[ "$ask" == "2" ]]; then
    read -p "Do you want to configure $1? [Y:n]" -n 1 -r REPLY
    REPLY=${REPLY:-Y}
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      make menuconfig KCONFIG_CONFIG=$KCONFIG_FILE
    fi
  fi
  if [ -f "$KCONFIG_FILE" ]; then
    # sed -i -e '1iOUT=out_'"$1"'/' -e '/OUT=/d' $KCONFIG_FILE
    sed -i -e '/OUT=/d' $KCONFIG_FILE
    make clean KCONFIG_CONFIG=$KCONFIG_FILE OUT=out_"$1"/
    if [[ "$2" == "build" ]]; then
      make KCONFIG_CONFIG=$KCONFIG_FILE OUT=out_"$1"/
    fi
    if [[ "$2" == "flash" ]]; then
      make flash $3 KCONFIG_CONFIG=$KCONFIG_FILE OUT=out_"$1"/
    fi
  fi
}

main() {
  cd $WORKING_DIR/klipper/
  klipper_ver=$(git rev-parse HEAD)
  git pull
  if [[ $klipper_ver == $(git rev-parse HEAD)]] && ! [["$forceflash" == "1" ]]; then
    # Same klipper version.
    echo "Exiting."
    exit 0
  fi

  rm -rf $WORKING_DIR/klipper/out

  # Build klipper
  build_klipper $MCU_NAME
  build_klipper $OCTOPUS_NAME build
  build_klipper $EBB_NAME build

  ### Stoping services
  echo "Stoping services"
  service klipper stop
  service klipper_mcu stop

  echo "Flashing"
  ### Flash MCU (rpi)
  build_klipper $MCU_NAME flash

  ### Flash Octopus
  #python3 $WORKING_DIR/CanBoot/scripts/flash_can.py -i can0 -f $WORKING_DIR/klipper/out_$OCTOPUS_NAME/klipper.bin -u $OCTOPUS_CAN
  #python3 $WORKING_DIR/CanBoot/scripts/flash_can.py -f $WORKING_DIR/klipper/out_$OCTOPUS_NAME/klipper.bin -d /dev/serial/by-id/$OCTOPUS_SERIAL_ID
  sudo sh $WORKING_DIR/gpio.sh write 20 1 # dfu mode on
  sudo sh $WORKING_DIR/gpio.sh write 21 0 # reset on
  sleep 0.5
  sudo sh $WORKING_DIR/gpio.sh write 21 1 # reset off
  sleep 1
  build_klipper $OCTOPUS_NAME flash FLASH_DEVICE=0483:df11
  sudo sh $WORKING_DIR/gpio.sh write 20 0 # dfu mode off
  sudo sh $WORKING_DIR/gpio.sh write 21 0 # reset on
  sleep 0.5
  sudo sh $WORKING_DIR/gpio.sh write 21 1 # reset off
  sleep 1

  ### Flash EBB
  python3 $WORKING_DIR/CanBoot/scripts/flash_can.py -i can0 -f $WORKING_DIR/klipper/out_$EBB_NAME/klipper.bin -u $EBB_CAN

  ### List CAN devices
  echo "List CAN devices"
  $WORKING_DIR/klippy-env/bin/python $WORKING_DIR/klipper/scripts/canbus_query.py can0

  ## Starting services
  echo "Starting services"
  service klipper_mcu start
  service klipper start
}

main

exit 0
