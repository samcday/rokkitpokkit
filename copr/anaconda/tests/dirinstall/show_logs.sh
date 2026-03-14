#!/bin/sh -x

ls /tmp

LOG_DIR=/tmp

cd ${LOG_DIR}
KS_SCRIPT_LOGS=$(ls ks-script-*.log)
cd -

ANACONDA_LOGS="anaconda.log storage.log packaging.log program.log dbus.log dnf.librepo.log ${KS_SCRIPT_LOGS}"

for log in ${ANACONDA_LOGS} ; do
    LOG_PATH=${LOG_DIR}/${log}
    if [ -f ${LOG_PATH} ]; then
        echo "----------------------- Dumping log file $LOG_PATH:"
        cat $LOG_PATH
        # clear for the following test
        rm $LOG_PATH
    fi
done
