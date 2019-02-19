# Vault PKI - Demo #

## Prerequisities ##

* Linux / MacOS
* wget  
* Openssl or LibreSSL
* Java >= 8
* docker
* tmux (Optional)

## TL;DR ##

    scripts/download-dependencies.sh

    # This will start in backgroud
    scripts/start-all-servers.sh

    scripts/configure-client-acl.sh

    scripts/start-consumer.sh

    # Start in a different terminal
    scripts/start-producer.sh

## Step by Step ##

### Configure Vault and Kafka ###

    scripts/download-dependencies.sh
    scripts/configure-vault.sh
    scripts/configure-kafka.sh

### Kafka Clients ###

    scripts/configure-client-acl.sh
    scripts/start-consumer.sh
    scripts/start-producer.sh

__Alternative__ - Kafka Clients in one window (tmux required)

    scripts/start-kafka-cli.sh

### Kafka Management UI ###

    scripts/start-manager.sh

The server should be available at <http://localhost:9000>

### Shutdown ###

    scripts/shutdown.sh

### Reset ###

    scripts/clean-up.sh

## Local hacking ##

    scripts/download-dependencies.sh
    $(scripts/init-local-env.sh)

### Creating Different ACLs ###

    scripts/configure-client-acl.sh <topic> <client name>

### Customising consumer and producer ###

The CLI client will connect to the specified topic using the client name

    scripts/start-consumer.sh <topic> <client name>
    scripts/start-producer.sh <topic> <client name>
