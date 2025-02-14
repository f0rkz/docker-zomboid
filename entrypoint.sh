#!/usr/bin/bash
steamcmd.sh +quit
steamcmd.sh +force_install_dir /data/zomboid +login anonymous +app_update 380870 validate +quit
cd /data/zomboid && bash ./start-server.sh -servername ${SERVERNAME} -adminpassword ${ADMINPASSWORD} -steamvac ${STEAMVAC}
