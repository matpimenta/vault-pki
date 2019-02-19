#!/usr/bin/env bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

set -o errexit
set -o pipefail
set -o nounset
IFS=$'\n\t'
# set -o xtrace

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"

DOWNLOAD_HOME="${__root}/downloads"

VAULT_VERSION="1.0.3"
VAULT_BIN="${__root}/vault"
VAULT_PID=${__root}/vault.pid

KAFKA_VERSION="2.1.0"
SCALA_VERSION="2.11"
KAFKA_HOME=${__root}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}
KAFKA_BIN=${KAFKA_HOME}/bin
KAFKA_NODE_SIZE=3

DEFAULT_PASSWORD=changeme

_detect_os() {
    local OUT="$(uname -s)"
    local OS=
    case "${OUT}" in
        Linux*)     OS=linux;;
        Darwin*)    OS=darwin;;
        *)          OS="UNKNOWN:${OS}"
    esac
    echo "${OS}"
}

OS=$(_detect_os)

_detect_tmux() {
    local TMUX_TEST=${TMUX:-}
    if [ "$TMUX_TEST" == "" ]; then
        echo "false"
    else 
        echo "true"
    fi
}

USE_TMUX=$(_detect_tmux)

_clean_up() {
    rm -rf ${DOWNLOAD_HOME}
    rm -rf kafka_${SCALA_VERSION}-${KAFKA_VERSION}
    rm -f vault
    rm -f *.hcl *.pem *.csr *.jks *.log
}

_download_dependencies() {
    _create_download_dir
    _download_vault
    _download_kafka
}

_create_download_dir() {
    if [ ! -d ${DOWNLOAD_HOME} ]; then
        mkdir -p ${DOWNLOAD_HOME}
    fi
}

_download_vault() {

    local FILENAME=vault_${VAULT_VERSION}_${OS}_amd64.zip

    echo "Downloading Vault ${VAULT_VERSION}"

    if [ ! -f "${DOWNLOAD_HOME}/${FILENAME}" ]; then
        wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/${FILENAME} -P ${DOWNLOAD_HOME}
    else
        echo "File downloaded. Skipping..."
    fi

    if [ ! -f "${VAULT_BIN}" ]; then
        unzip ${DOWNLOAD_HOME}/${FILENAME}
    fi
}

_download_kafka() {

    local FILE_PREFIX=kafka_${SCALA_VERSION}-${KAFKA_VERSION}
    local FILENAME=${FILE_PREFIX}.tgz

    echo "Downloading Kafka ${KAFKA_VERSION}"

    if [ ! -f "${DOWNLOAD_HOME}/${FILENAME}" ]; then
        wget http://www.mirrorservice.org/sites/ftp.apache.org/kafka/${KAFKA_VERSION}/${FILENAME} -P ${DOWNLOAD_HOME}
    else
        echo "File downloaded. Skipping..."
    fi

    if [ ! -d "${__root}/${FILE_PREFIX}" ]; then
        tar xvfx ${DOWNLOAD_HOME}/${FILENAME}
    fi

}

_pause() {
    read -n1 -r -p "Press any key to continue..." key
}

_vault_start() {
    if [ "${USE_TMUX}" == "true" ]; then 
        tmux new-window -d -n vault "${VAULT_BIN} server -dev"
        tmux list-panes -t vault -F '#{pane_pid}' > ${VAULT_PID}
    else 
        ${VAULT_BIN} server -dev 2>&1 ${__root}/vault.log &
        echo $! > ${VAULT_PID}
    fi
    _vault_init_connection
    _wait_for_vault
    ${VAULT_BIN} secrets list
}

_wait_for_vault() {
    while ! vault status 2>&1 > /dev/null; do
        echo "Waiting for Vault to be up..."
        sleep 1
    done
    echo "Vault is up"
}

_vault_init_connection() {
    export VAULT_ADDR='http://127.0.0.1:8200'
    export PATH=${__root}:$PATH
}

_vault_configure() {
    _vault_configure_root_ca
    _vault_configure_intermediary_ca
    _vault_configure_pki_roles
    _vault_configure_token_roles
}

_vault_configure_root_ca() {
    _vault_init_connection

    vault secrets enable -path root-ca pki
    vault secrets tune -max-lease-ttl=8760h root-ca
    vault write -field certificate root-ca/root/generate/internal \
        common_name="Acme Root CA" \
        ttl=8760h > root-ca.pem

    vault write root-ca/config/urls \
        issuing_certificates="$VAULT_ADDR/v1/root-ca/ca" \
        crl_distribution_points="$VAULT_ADDR/v1/root-ca/crl"        

}

_vault_configure_intermediary_ca() {
    _vault_init_connection

    vault secrets enable -path kafka-int-ca pki
    vault secrets tune -max-lease-ttl=8760h kafka-int-ca

    vault write -field=csr kafka-int-ca/intermediate/generate/internal \
        common_name="Acme Kafka Intermediate CA" ttl=43800h > kafka-int-ca.csr

    vault write -field=certificate root-ca/root/sign-intermediate csr=@kafka-int-ca.csr \
        format=pem_bundle ttl=43800h > kafka-int-ca.pem

    vault write kafka-int-ca/intermediate/set-signed certificate=@kafka-int-ca.pem
    
    vault write kafka-int-ca/config/urls issuing_certificates="$VAULT_ADDR/v1/kafka-int-ca/ca" \
        crl_distribution_points="$VAULT_ADDR/v1/kafka-int-ca/crl"
}

_vault_configure_pki_roles() {
    vault write kafka-int-ca/roles/kafka-client \
        allowed_domains=clients.kafka.acme.com \
        allow_subdomains=true max_ttl=72h

    vault write kafka-int-ca/roles/kafka-server \
        allowed_domains=servers.kafka.acme.com \
        allow_subdomains=true max_ttl=72h

}

_vault_configure_token_roles() {
    cat > kafka-client.hcl <<EOF
path "kafka-int-ca/issue/kafka-client" {
  capabilities = ["update"]
}
EOF

    vault policy write kafka-client kafka-client.hcl
    vault write auth/token/roles/kafka-client \
        allowed_policies=kafka-client period=24h

    cat > kafka-server.hcl <<EOF
path "kafka-int-ca/issue/kafka-server" {
  capabilities = ["update"]
}
EOF
 
    vault policy write kafka-server kafka-server.hcl
 
    vault write auth/token/roles/kafka-server \
	    allowed_policies=kafka-server period=24h

}

_create_vault_token() {
    local ROLE=$1
    _unset_vault_token
    export VAULT_TOKEN=$(vault token create -field=token -role $ROLE)
}

_unset_vault_token() {
    unset VAULT_TOKEN
}

_create_kafka_truststore() {
    if [ -f kafka-truststore.jks ]; then
        rm kafka-truststore.jks
    fi
    keytool -import -alias root-ca -trustcacerts -file root-ca.pem \
        -keystore kafka-truststore.jks -storepass ${DEFAULT_PASSWORD} -noprompt
    keytool -import -alias kafka-int-ca -trustcacerts -file kafka-int-ca.pem \
        -keystore kafka-truststore.jks -storepass ${DEFAULT_PASSWORD} -noprompt
    cp kafka-truststore.jks $KAFKA_HOME
}

_configure_kafka_tls() {
    _vault_init_connection
    cd $KAFKA_HOME
    for NODE in $(seq 1 ${KAFKA_NODE_SIZE}); do
        _create_vault_token "kafka-server"

        vault write -field certificate kafka-int-ca/issue/kafka-server \
            common_name=node-${NODE}.servers.kafka.acme.com alt_names=localhost \
            format=pem_bundle > node-${NODE}.pem

        openssl pkcs12 -inkey node-${NODE}.pem -in node-${NODE}.pem -name node-${NODE} \
            -export -out node-${NODE}.p12 -passin pass:${DEFAULT_PASSWORD} -passout pass:${DEFAULT_PASSWORD}
 
        keytool -importkeystore -deststorepass ${DEFAULT_PASSWORD} \
            -destkeystore node-${NODE}-keystore.jks -srckeystore node-${NODE}.p12 \
            -srcstoretype PKCS12 -srcstorepass ${DEFAULT_PASSWORD} -noprompt

        cp config/server.properties config/server-${NODE}.properties
        
        cat >> config/server-${NODE}.properties <<EOF
        
broker.id=${NODE}
listeners=SSL://:${NODE}9093
advertised.listeners=SSL://localhost:${NODE}9093
log.dirs=/tmp/kafka-logs-${NODE}

security.inter.broker.protocol=SSL

ssl.keystore.location=node-${NODE}-keystore.jks
ssl.keystore.password=${DEFAULT_PASSWORD}
ssl.key.password=${DEFAULT_PASSWORD}
ssl.truststore.location=kafka-truststore.jks
ssl.truststore.password=${DEFAULT_PASSWORD}

ssl.client.auth=required
authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer

EOF

        _unset_vault_token
    done
}

_start_zookeeper() {
    if [ "${USE_TMUX}" == "true" ]; then 
        tmux new-window -d -n zookepper "$KAFKA_BIN/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties"
    else 
        mkdir -p $KAFKA_HOME/logs
        $KAFKA_BIN/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties 2>&1 > $KAFKA_HOME/logs/zookeeper.log &
        sleep 10
    fi
}

_configure_kafka_acl() {
    for NODE in $(seq 1 ${KAFKA_NODE_SIZE}); do
        $KAFKA_BIN/kafka-acls.sh --authorizer-properties zookeeper.connect=localhost:2181 \
            --add --allow-principal User:CN=node-${NODE}.servers.kafka.acme.com \
            --operation ALL --topic '*' --cluster
    done

    $KAFKA_BIN/kafka-acls.sh --authorizer-properties zookeeper.connect=localhost:2181 \
        --add --allow-principal User:CN=my-client.clients.kafka.acme.com \
        --operation ALL --topic '*' --group '*'
}

_start_kafka() {
    cd $KAFKA_HOME
    mkdir -p $KAFKA_HOME/logs

    if [ "${USE_TMUX}" == "true" ]; then 
        tmux new-window -n kafka -d 'sleep 10'
        for NODE in $(seq 1 ${KAFKA_NODE_SIZE}); do
                JMX_PORT=${NODE}9094 
                tmux split-window -d -t kafka "bash -c 'export JMX_PORT=${JMX_PORT}; $KAFKA_BIN/kafka-server-start.sh $KAFKA_HOME/config/server-${NODE}.properties'"
        done
    else
        for NODE in $(seq 1 ${KAFKA_NODE_SIZE}); do
            export JMX_PORT=${NODE}9094
            $KAFKA_BIN/kafka-server-start.sh $KAFKA_HOME/config/server-${NODE}.properties 2>&1 > $KAFKA_HOME/logs/kafka-${NODE}.log &
        done
    fi

}

_shutdown_vault() {
    if [ -f "${VAULT_PID}" ]; then
        kill $(cat ${VAULT_PID})
        rm ${VAULT_PID}
    fi
}

_shutdown_kafka() {
    for NODE in $(seq 1 ${KAFKA_NODE_SIZE}); do
        $KAFKA_BIN/kafka-server-stop.sh $KAFKA_HOME/config/server-${NODE}.properties &
        rm -rf /tmp/kafka-logs-$NODE
    done
}

_shutdown_zookeeper() {
    $KAFKA_BIN/zookeeper-server-stop.sh $KAFKA_HOME/config/zookeeper.properties
    rm -rf /tmp/zookeeper
}

_configure_producer() {
    _vault_init_connection
    cd $KAFKA_HOME
    _create_vault_token "kafka-client"

    vault write -field certificate kafka-int-ca/issue/kafka-client \
    common_name=my-client.clients.kafka.acme.com format=pem_bundle > producer.pem
 
    openssl pkcs12 -inkey producer.pem -in producer.pem -name producer -export \
        -out producer.p12 -passin pass:${DEFAULT_PASSWORD} -passout pass:${DEFAULT_PASSWORD}
 
    keytool -importkeystore -deststorepass ${DEFAULT_PASSWORD} \
        -destkeystore producer-keystore.jks -srckeystore producer.p12 \
        -srcstoretype PKCS12 -srcstorepass ${DEFAULT_PASSWORD} -noprompt

    cp config/producer.properties config/producer-1.properties

    cat >> config/producer-1.properties <<EOF
 
security.protocol=SSL
ssl.truststore.location=kafka-truststore.jks
ssl.truststore.password=${DEFAULT_PASSWORD}
ssl.keystore.location=producer-keystore.jks
ssl.keystore.password=${DEFAULT_PASSWORD}
ssl.key.password=${DEFAULT_PASSWORD}
 
EOF
}

_configure_consumer() {
    _vault_init_connection
    cd $KAFKA_HOME
    _create_vault_token "kafka-client"

    vault write -field certificate kafka-int-ca/issue/kafka-client \
    common_name=my-client.clients.kafka.acme.com format=pem_bundle > consumer.pem
 
    openssl pkcs12 -inkey consumer.pem -in consumer.pem -name consumer -export \
        -out consumer.p12 -passin pass:${DEFAULT_PASSWORD} -passout pass:${DEFAULT_PASSWORD}
 
    keytool -importkeystore -deststorepass ${DEFAULT_PASSWORD} \
        -destkeystore consumer-keystore.jks -srckeystore consumer.p12 \
        -srcstoretype PKCS12 -srcstorepass ${DEFAULT_PASSWORD} -noprompt

    cp config/consumer.properties config/consumer-1.properties
 
    cat >> config/consumer-1.properties <<EOF
 
security.protocol=SSL
ssl.truststore.location=kafka-truststore.jks
ssl.truststore.password=${DEFAULT_PASSWORD}
ssl.keystore.location=consumer-keystore.jks
ssl.keystore.password=${DEFAULT_PASSWORD}
ssl.key.password=${DEFAULT_PASSWORD}

EOF

}

_start_consumer_and_producer() {
    tmux new-window -n consumer-producer 'sleep 1'
    if [ "${USE_TMUX}" == "true" ]; then 
        tmux split-pane -d -t consumer-producer "$KAFKA_BIN/kafka-console-consumer.sh --topic test --bootstrap-server localhost:19093 \
            --consumer.config $KAFKA_HOME/config/consumer-1.properties"
        tmux split-pane -d -t consumer-producer "$KAFKA_BIN/kafka-console-producer.sh --topic test --broker-list localhost:19093 \
            --producer.config $KAFKA_HOME/config/producer-1.properties"
    fi

}

_start_consumer() {
    $KAFKA_BIN/kafka-console-consumer.sh --topic test --bootstrap-server localhost:19093 \
        --consumer.config $KAFKA_HOME/config/consumer-1.properties
}

_start_producer() {
    $KAFKA_BIN/kafka-console-producer.sh --topic test --broker-list localhost:19093 \
        --producer.config $KAFKA_HOME/config/producer-1.properties
}

_start_manager() {
    local ZK_HOST="localhost"
    local NETWORK="--network=host"

    if [ "${OS}" == "darwin" ]; then
        ZK_HOST="docker.for.mac.host.internal"
        NETWORK=""
    fi

    if [ "${USE_TMUX}" == "true" ]; then 
        tmux new-window -n manager -d "docker run -it --rm -p 9000:9000 -e ZK_HOSTS=\"${ZK_HOST}:2181\" sheepkiller/kafka-manager"
    else
        docker run -it --rm ${NETWORK} -p 9000:9000 -e ZK_HOSTS="${ZK_HOST}:2181" sheepkiller/kafka-manager
    fi
}