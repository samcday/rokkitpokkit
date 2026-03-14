#!/bin/sh -eux

# Remove webui because it does not support much anything yet

# Possible alternative: rpm -E --nodeps anaconda-webui
dnf remove -y anaconda-webui


# Prepare test work directory

WORK_DIR=$(mktemp -d /var/tmp/dirinstall.XXXXXX)


# Create kickstart

KICKSTART_PATH=${WORK_DIR}/ks.cfg
source ./repositories
TEST_KICKSTART=./ks.dirinstall.cfg

# Dump URLs of installation repositories found in local repositories whose names are configured in 'repositories' file
echo "url --metalink=$(dnf repoinfo $BASE_REPO | grep -e "^ *Metalink *:" | cut -d: -f2- | sed 's/^ *//')" > ${KICKSTART_PATH}
for repo in $REPOS; do
    echo "repo --name=$repo --metalink=$(dnf repoinfo $repo | grep "^ *Metalink *:" | cut -d: -f2- | sed 's/^ *//')" >> ${KICKSTART_PATH}
done

cat ${TEST_KICKSTART} >> ${KICKSTART_PATH}

# Log the kickstart
cat ${KICKSTART_PATH}


# Run dirinstall

INSTALL_DIR=${WORK_DIR}/install_dir
mkdir ${INSTALL_DIR}

anaconda --dirinstall ${INSTALL_DIR} --kickstart ${KICKSTART_PATH} --${ANACONDA_UI_MODE} --noninteractive 2>&1


# Remove test work directory

rm -rf ${WORK_DIR}


# Show and remove the logs for this anaconda run

./show_logs.sh
