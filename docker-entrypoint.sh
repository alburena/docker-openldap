#!/bin/bash
# docker entrypoint script
# configures and starts LDAP

function ldap_add_or_modify (){
    local LDIF_FILE=$1

    echo "Processing file ${LDIF_FILE}"
    sed -i "s|{{ LDAP_BASE_DN }}|${LDAP_BASE_DN}|g" $LDIF_FILE
    sed -i "s|{{ LDAP_BACKEND }}|${LDAP_BACKEND}|g" $LDIF_FILE
    sed -i "s|{{ LDAP_DOMAIN }}|${LDAP_DOMAIN}|g" $LDIF_FILE
    
    if grep -iq changetype $LDIF_FILE ; then
        ldapmodify -Y EXTERNAL -Q -H ldapi:/// -f $LDIF_FILE 2>&1 || ldapmodify -h localhost -p 389 -D cn=admin,$LDAP_SUFFIX -w "$LDAP_ROOTPW" -f $LDIF_FILE 2>&1
    else
        ldapadd -Y EXTERNAL -Q -H ldapi:/// -f $LDIF_FILE 2>&1 || ldapadd -h localhost -p 389 -D cn=admin,$LDAP_SUFFIX -w "$LDAP_ROOTPW" -f $LDIF_FILE 2>&1
    fi
}


SLAPD_CONF=/etc/ldap/ldap.conf
SLAPD_CONF_DIR=/etc/ldap/slapd.d
SLAPD_DATA_DIR=/var/lib/ldap

# remove default ldap db
rm -rf ${SLAPD_DATA_DIR} ${SLAPD_CONF_DIR}

echo "Configuring OpenLDAP via slapd.d"
if [[ ! -d ${SLAPD_CONF_DIR} ]]; then
    mkdir -p ${SLAPD_CONF_DIR}
fi
if [[ ! -d ${SLAPD_DATA_DIR} ]]; then
    mkdir -p ${SLAPD_DATA_DIR}
fi

chown -R openldap:openldap ${SLAPD_CONF_DIR}
chown -R openldap:openldap ${SLAPD_DATA_DIR}

cat <<EOF | debconf-set-selections
slapd slapd/no_configuration boolean false
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANIZATION}
slapd slapd/password1 password ${LDAP_ROOTPW}
slapd slapd/password2 password ${LDAP_ROOTPW}
slapd slapd/backend select MDB
slapd slapd/purge_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/move_old_database boolean true
slapd slapd/internal/generated_adminpw password ${LDAP_ROOTPW}
slapd slapd/internal/adminpw password ${LDAP_ROOTPW}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
EOF

dpkg-reconfigure -f noninteractive slapd

slapd -h "ldap://$HOSTNAME ldap://localhost ldapi:///" -u openldap -g openldap -d $LDAP_LOG_LEVEL 2>&1 & _PID=$!

echo "Waiting for OpenLDAP to start..."
while [ ! -e /run/slapd/slapd.pid ]; do sleep 5; done

# add ppolicy schema
echo "Adding ppolicy schema..."
ldapadd -c -Y EXTERNAL -Q -H ldapi:/// -f /etc/ldap/schema/ppolicy.ldif

# Add cn=config password
echo "dn: olcDatabase={0}config,cn=config
changeType: modify
add: OlcRootPW
OlcRootPW: $(slappasswd -s ${LDAP_ROOTPW})" | ldapadd -Y EXTERNAL -H ldapi:/// 

# process config files (*.ldif) in bootstrap directory (do no process files in subdirectories)
echo "Add image bootstrap ldif..."
for f in $(find /etc/ldap/ldif_files -mindepth 1 -maxdepth 1 -type f -name \*.ldif | sort); do
    echo "Processing file ${f}"
    ldap_add_or_modify "$f"
done


echo "Tail"
tail -f $SLAPD_CONF