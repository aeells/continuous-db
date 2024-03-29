# Copyright (c) 2011, Andrew Eells. All Rights Reserved.

#!/bin/sh

DB_USER=$1
DB_PASS=$2
DB_HOST=$3
DB_DATABASE=$4

if [ $# -ne 4 ]
then
    echo "Usage: sh $0 <DB_USER> <DB_PASS> <DB_HOST> <DB_DATABASE>"
    exit 1
fi

MYSQL_CONNECT="/usr/local/mysql/bin/mysql -u${DB_USER} -p${DB_PASS} -h${DB_HOST} ${DB_DATABASE}"
SCRIPTS_DIR=`pwd`/src/main/resources/scripts

# updates sequence number even if no patches i.e. we don't care if not contiguous
${MYSQL_CONNECT} -e "UPDATE seq_patch_metadata SET value = value + 1"
RELEASE_NUMBER=`${MYSQL_CONNECT} --skip-column-names -e "SELECT value FROM seq_patch_metadata"`

for PATCH_NUMBER in $(find src/main/resources/scripts/patches/**/install.txt | cut -f6 -d/ | sort -t\. -k 1n,1n -k 2n,2n -k 3n,3n);
do
    for PATCH_SCRIPT in `cat src/main/resources/scripts/patches/${PATCH_NUMBER}/install.txt`;
    do
        # Check that rollback has not already been executed.
        ROLLBACK_APPLIED=`${MYSQL_CONNECT} -e "
            SELECT COUNT(*) FROM patch_metadata
                WHERE patch_number = '${PATCH_NUMBER}'
                AND script = '${PATCH_SCRIPT}'
                AND patch_type IN ('ROLLBACK');"`

        # Check that patch has not already been executed.
        PATCH_APPLIED=`${MYSQL_CONNECT} -e "
            SELECT COUNT(*) FROM patch_metadata
                WHERE patch_number = '${PATCH_NUMBER}'
                AND script = '${PATCH_SCRIPT}'
                AND patch_type IN ('PATCH', 'BASELINE');"`

        SCRIPT_CHECKSUM=`cksum ${SCRIPTS_DIR}/patches/${PATCH_NUMBER}/patch/${PATCH_SCRIPT} | awk '{print $1}'`

        if [ ${ROLLBACK_APPLIED//[^0-9]/} = "1" ];
        then
            echo "  * Applying patch ${PATCH_NUMBER} ${PATCH_SCRIPT}"
            ${MYSQL_CONNECT} < ${SCRIPTS_DIR}/patches/${PATCH_NUMBER}/patch/${PATCH_SCRIPT};

            ${MYSQL_CONNECT} -e "
                UPDATE patch_metadata SET release_number = $RELEASE_NUMBER, patch_type = 'PATCH', patch_timestamp = NOW(), script_checksum = $SCRIPT_CHECKSUM
                    WHERE patch_number = '${PATCH_NUMBER}'
                    AND script = '${PATCH_SCRIPT}';
                COMMIT;"

        elif [ ${PATCH_APPLIED//[^0-9]/} = "0" ];
        then
            echo "  * Applying patch ${PATCH_NUMBER} ${PATCH_SCRIPT}"
            ${MYSQL_CONNECT} < ${SCRIPTS_DIR}/patches/${PATCH_NUMBER}/patch/${PATCH_SCRIPT};

            ${MYSQL_CONNECT} -e "
                INSERT INTO patch_metadata (release_number, patch_number, script, patch_type, patch_timestamp, script_checksum)
                    VALUES($RELEASE_NUMBER, '${PATCH_NUMBER}', '${PATCH_SCRIPT}', 'PATCH', NOW(), $SCRIPT_CHECKSUM);
                COMMIT;"
        else
            echo "  * Already applied ${PATCH_NUMBER} ${PATCH_SCRIPT}";
        fi
    done
done
