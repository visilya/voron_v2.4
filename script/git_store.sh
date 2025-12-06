#/usr/bin/env bash
cd ~/printer_data/config
rm -f printer-*.cfg
TODAY=$(date)
git add .
git commit -m "$TODAY"
git push origin main # to my local gitlab repo
git push github main
