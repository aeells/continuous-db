#!/bin/sh

DB_USER=$1
DB_PASS=$2
DB_HOST=$3
DB_DATABASE=$4

if [ $# -ne 4 ]
then
    echo "Usage: sh $0 <DB_USER> <DB_PASSWORD> <DB_HOST> <DB_DATABASE>"
    exit 1
fi

MYSQL_CONNECT="/usr/local/mysql/bin/mysql -u${DB_USER} -p${DB_PASS} -h${DB_HOST} ${DB_DATABASE}"
SCRIPTS_DIR=`pwd`/src/main/resources/scripts

# Delete database tables.
${MYSQL_CONNECT} < ${SCRIPTS_DIR}/baseline/p_clean_tables.sql;
${MYSQL_CONNECT} -e "CALL p_clean_tables('${DB_DATABASE}');"

# Baseline database tables.
${MYSQL_CONNECT} < ${SCRIPTS_DIR}/baseline/patch_metadata.sql;
for SCRIPT in `cat ${SCRIPTS_DIR}/baseline/install.txt`
do
    echo "  * Applying baseline ${SCRIPT};"
    ${MYSQL_CONNECT} < ${SCRIPTS_DIR}/baseline/${SCRIPT};
done

# Iterate previous patches and create dummy records in PATCH_METADATA (don't apply existing patches after baseline).
for PATCH_NUMBER in $(find src/main/resources/scripts/patches/**/install.txt | cut -f6 -d/ | sort -t\. -k 1n,1n -k 2n,2n -k 3n,3n);
do
    for PATCH_SCRIPT in `cat src/main/resources/scripts/patches/${PATCH_NUMBER}/install.txt`;
    do
        SCRIPT_CHECKSUM=`cksum ${SCRIPTS_DIR}/patches/${PATCH_NUMBER}/patch/${PATCH_SCRIPT} | awk '{print $1}'`
        ${MYSQL_CONNECT} -e "
            INSERT INTO patch_metadata (release_number, patch_number, script, patch_type, patch_timestamp, script_checksum)
                VALUES(0, '${PATCH_NUMBER}', '${PATCH_SCRIPT}', 'BASELINE', NOW(), $SCRIPT_CHECKSUM);
            COMMIT;"
    done
done
