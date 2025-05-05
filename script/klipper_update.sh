#!/bin/bash
# Get CAN devicies id
# ~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0
# python3 ~/katapult/scripts/flash_can.py -i can0 -q
# https://www.shellcheck.net/

### Start config ###
MCU_NAME=mcu

OCTOPUS_NAME=octopus
OCTOPUS_CAN=ce5f75f5c4f0
# OCTOPUS_SERIAL_ID=usb-katapult_stm32f429xx_2E004E001450304738313820-if00

EBB_NAME=ebb
EBB_CAN=d22185cfd0c4

TR_NAME=tr
TR_CAN=48ca42bbc884

WORKING_DIR=/home/ilya
### End config ###

ask=$1
forceflash=$2

check_kconfig() {
  if [ ! -f "$1" ]; then
    if [[ "$ask" == "1" ]]; then
      echo "$1 does not exists."
      read -p "Do you want to configure $1? [Y:n]" -n 1 -r REPLY
      REPLY=${REPLY:-Y}
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        make menuconfig KCONFIG_CONFIG="$1"
      else
        echo "$1 does not exists."
        return 1
      fi
    else
      echo "$1 does not exists."
      return 1
    fi
  fi
  return 0
}

build_klipper() {
  echo ----------- "$1" -----------
  KCONFIG_FILE=$WORKING_DIR/printer_data/config/script/klipper_$1.cfg
  if ! check_kconfig "$KCONFIG_FILE"; then
    exit 1
  fi
  if [ -f "$KCONFIG_FILE" ]; then
    echo 'Config file: '$WORKING_DIR'/printer_data/config/script/klipper_'$1'.cfg'
    # sed -i -e '1iOUT=out_'"$1"'/' -e '/OUT=/d' "$KCONFIG_FILE"
    sed -i -e '/OUT=/d' "$KCONFIG_FILE"
    make clean KCONFIG_CONFIG="$KCONFIG_FILE" OUT=out_"$1"/
    if [[ "$2" == "build" ]]; then
      make -j4 KCONFIG_CONFIG="$KCONFIG_FILE" OUT=out_"$1"/
    fi
    if [[ "$2" == "flash" ]]; then
      echo make -j4 flash "$3" KCONFIG_CONFIG="$KCONFIG_FILE" OUT=out_"$1"/
      make -j4 flash $3 KCONFIG_CONFIG="$KCONFIG_FILE" OUT=out_"$1"/
    fi
  fi
}

do_can() {
    KCONFIG_FILE=$WORKING_DIR/printer_data/config/script/canboot_"$1".cfg
    if check_kconfig "$KCONFIG_FILE"; then
      if [ -f "$KCONFIG_FILE" ]; then
        make clean KCONFIG_CONFIG="$KCONFIG_FILE" OUT=out_$1/
        make -j4 KCONFIG_CONFIG="$KCONFIG_FILE" OUT=out_$1/
        python3 ~/katapult/scripts/flash_can.py -i can0 -f ~/katapult/out_$1/deployer.bin -u $2
      fi
    else
      echo "$KCONFIG_FILE does not exists. Skipping $3 katapult update."
    fi
}


main() {

  force_katapult=1
  forceflash_can=1
  forceflash=1
  flashmcu=0
  flashebb=1
  flashtr=0
  flashboard=0

  cd $WORKING_DIR/katapult/ || exit
  canboot_ver=$(git rev-parse HEAD)
  git pull
  if [[ ! ($canboot_ver == $(git rev-parse HEAD)) ]] || [[ $force_katapult -eq 1 ]]; then
    do_can $EBB_NAME $EBB_CAN TR
    do_can $TR_NAME $TR_CAN TR
    forceflash_can=1
  else
    echo Same katapult version.
  fi

  cd $WORKING_DIR/klipper/ || exit
  klipper_ver=$(git rev-parse HEAD)
  git pull
  if [[ $klipper_ver == $(git rev-parse HEAD) ]] && ! [[ $forceflash -eq 1 ]]; then
    echo Same klipper version.
    exit
  fi

  rm -rf $WORKING_DIR/klipper/out

  ### Stoping services
  echo "Stoping services"
  service klipper stop
#  service klipper_mcu stop

  # Build and flash klipper
  echo "Flashing"
  if [ $flashmcu -eq 1 ]; then
    build_klipper $MCU_NAME
    build_klipper $MCU_NAME flash
  fi
  if [[ $flashebb -eq 1 ]] || [[ $forceflash_can -eq 1 ]]; then
    build_klipper $EBB_NAME build
    ### Flash EBB
    python3 $WORKING_DIR/katapult/scripts/flash_can.py -i can0 -f $WORKING_DIR/klipper/out_$EBB_NAME/klipper.bin -u $EBB_CAN
    ### List CAN devices
    echo "List CAN devices"
    $WORKING_DIR/klippy-env/bin/python $WORKING_DIR/klipper/scripts/canbus_query.py can0
  fi
  if [[ $flashtr -eq 1 ]] || [[ $forceflash_can -eq 1 ]]; then
    build_klipper $TR_NAME build
    ### Flash EBB
    python3 $WORKING_DIR/katapult/scripts/flash_can.py -i can0 -f $WORKING_DIR/klipper/out_$TR_NAME/klipper.bin -u $TR_CAN
    ### List CAN devices
    echo "List CAN devices"
    $WORKING_DIR/klippy-env/bin/python $WORKING_DIR/klipper/scripts/canbus_query.py can0
  fi
  if [ $flashboard -eq 1 ]; then
    #build_klipper $OCTOPUS_NAME build
    ### Flash Octopus
    #python3 $WORKING_DIR/katapult/scripts/flash_can.py -i can0 -f $WORKING_DIR/klipper/out_$OCTOPUS_NAME/klipper.bin -u $OCTOPUS_CAN
    #python3 $WORKING_DIR/katapult/scripts/flash_can.py -f $WORKING_DIR/klipper/out_$OCTOPUS_NAME/klipper.bin -d /dev/serial/by-id/$OCTOPUS_SERIAL_ID

    # sudo apt-get install gpiod
    sudo gpioset 0 20=1 &&  # dfu mode on \
    sudo gpioset 0 21=0 && # reset on \ 
    sudo sleep 0.5 && \
    sudo gpioset 0 21=1 && # reset off \
    sudo sleep 2 && \
    sudo gpioset 0 20=0 # dfu mode off
#    make -j4 OUT=out_octopus/ KCONFIG_CONFIG=~/printer_data/config/script/klipper_octopus.cfg flash FLASH_DEVICE=0483:df11
#    python3 ~/katapult/scripts/flash_can.py -i can0 -r -u $OCTOPUS_CAN
    build_klipper $OCTOPUS_NAME flash FLASH_DEVICE=0483:df11
    sudo gpioset 0 21=0 && # reset on \
    sudo sleep 0.5 && \
    sudo gpioset 0 21=1 && # reset off \
    sudo sleep 2
  fi

  ## Starting services
  echo "Starting services"
#  service klipper_mcu start
  service klipper start
}

main

exit 0
