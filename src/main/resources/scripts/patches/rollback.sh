# Copyright (c) 2011, Andrew Eells. All Rights Reserved.

#!/bin/sh

# Parameters
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

# rollback all patches from a particular release number (multiple patch version numbers)
RELEASE_NUMBER=`${MYSQL_CONNECT} --skip-column-names -e "SELECT value FROM seq_patch_metadata"`

for PATCH_NUMBER in $(find src/main/resources/scripts/patches/**/install.txt | cut -f6 -d/ | sort -t\. -k 1n,1n -k 2n,2n -k 3n,3n -r);
do
    for PATCH_SCRIPT in `cat src/main/resources/scripts/patches/${PATCH_NUMBER}/install.txt | sort -r`;
    do
        RELEASE_GROUP=`${MYSQL_CONNECT} -e "
            SELECT COUNT(*) FROM patch_metadata
                WHERE patch_number = '${PATCH_NUMBER}'
                AND script = '${PATCH_SCRIPT}'
                AND release_number = ${RELEASE_NUMBER}
                AND patch_type IN ('PATCH');"`

        if [ ${RELEASE_GROUP//[^0-9]/} = "1" ];
        then
            # Check that patch has not already been executed.
            PATCH_APPLIED=`${MYSQL_CONNECT} -e "
                SELECT COUNT(*) FROM patch_metadata
                    WHERE patch_number = '${PATCH_NUMBER}'
                    AND script = '${PATCH_SCRIPT}'
                    AND patch_type IN ('PATCH', 'BASELINE');"`

            # Check that rollback has not already been executed.
            ROLLBACK_APPLIED=`${MYSQL_CONNECT} -e "
                SELECT COUNT(*) FROM patch_metadata
                    WHERE patch_number = '${PATCH_NUMBER}'
                    AND script = '${PATCH_SCRIPT}'
                    AND patch_type IN ('ROLLBACK');"`

            SCRIPT_CHECKSUM=`cksum ${SCRIPTS_DIR}/patches/${PATCH_NUMBER}/rollback/${PATCH_SCRIPT} | awk '{print $1}'`

            if [ ${PATCH_APPLIED//[^0-9]/} = "1" ];
            then
                echo "  * Applying rollback ${PATCH_NUMBER} ${PATCH_SCRIPT}"
                ${MYSQL_CONNECT} < ${SCRIPTS_DIR}/patches/${PATCH_NUMBER}/rollback/${PATCH_SCRIPT};

                ${MYSQL_CONNECT} -e "
                    UPDATE patch_metadata SET patch_type = 'ROLLBACK', patch_timestamp = NOW(), script_checksum = ${SCRIPT_CHECKSUM}
                        WHERE patch_number = '${PATCH_NUMBER}'
                        AND script = '${PATCH_SCRIPT}';
                    COMMIT;"

            elif [ ${ROLLBACK_APPLIED//[^0-9]/} = "0" ];
            then
                echo "  * Applying rollback ${PATCH_NUMBER} ${PATCH_SCRIPT}"
                ${MYSQL_CONNECT} < ${SCRIPTS_DIR}/patches/${PATCH_NUMBER}/rollback/${PATCH_SCRIPT};

                ${MYSQL_CONNECT} -e "
                    UPDATE patch_metadata SET patch_type = 'ROLLBACK', patch_timestamp = NOW(), script_checksum = '${SCRIPT_CHECKSUM}'
                        WHERE patch_number = '${PATCH_NUMBER}'
                        AND script = '${PATCH_SCRIPT}';
                    COMMIT;"
            else
                echo "  * Already applied ${PATCH_NUMBER} ${PATCH_SCRIPT}";
            fi
        fi
    done
done
