#!/bin/bash

trap 'kill -HUP 0' EXIT
exec 3>&1

EXPERIMENT=$1

./websocketd --port=8002 --address=localhost bash -c "tee 1>&3" 1>&2 &
#./websocketd --port=8002 --address=localhost bash -c "tee 1>$outpath" 1>&2 &

BROWSER="primusrun chromium --user-data-dir=chromium-data --allow-file-access-from-files" 

$BROWSER "file://$PWD/index.html?disableDefaultLogger=true&wsLogger=ws://localhost:8002&experiment=$EXPERIMENT"

#primusrun chromium --user-data-dir=chromium-data --allow-file-access-from-files index.html

