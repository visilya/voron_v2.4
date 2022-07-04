#/usr/bin/env bash
cd ~/klipper_config
TODAY=$(date)
git add .
git commit -m "$TODAY"
git push origin main
