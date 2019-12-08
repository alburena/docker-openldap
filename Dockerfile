FROM debian

#Proxy settings if necessary
# ENV http_proxy=http://proxy.mydomain.com:8080
# ENV https_proxy=http://proxy.mydomain.com:8080
# ENV no_proxy="127.0.0.1,localhost,.mydomain.com"

# Install OpenLDAP
RUN  apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
        openssl \
        slapd  \
        krb5-kdc-ldap  \
        ldap-utils \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


COPY docker-entrypoint.sh /
RUN chmod +xr /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]