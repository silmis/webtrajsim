#!/bin/bash

trap 'kill -HUP 0' EXIT
exec 3>&1

./websocketd --port=8002 --address=localhost bash -c "tee 1>&3" 1>&2 &

primusrun chromium --user-data-dir=chromium-data --allow-file-access-from-files "file://$PWD/index.html?disableDefaultLogger=true&wsLogger=ws://localhost:8002"

#primusrun chromium --user-data-dir=chromium-data --allow-file-access-from-files index.html

