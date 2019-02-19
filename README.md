Vault PKI - Demo
================

Prerequisities
--------------

* Linux / MacOS
* wget  
* Openssl or LibreSSL
* Java >= 8
* tmux (Optional)
* docker (Optional)

TL;DR
-----

    scripts/download-dependencies.sh
    # This will start in backgroud
    scripts/start-all-servers.sh
    scripts/configure-client-acl.sh
    scripts/start-consumer.sh
    # Start in aifferent terminal
    scripts/start-producer.sh

Step by Step
------------

1. Configure Vault and Kafka

    ```sh
    scripts/download-dependencies.sh
    scripts/configure-vault.sh
    scripts/configure-kafka.sh
    ```

2. Kafka Clients

    ```sh
    scripts/configure-client-acl.sh
    scripts/start-consumer.sh
    scripts/start-producer.sh
    ```

    Alternative - Kafka Clients in one window (tmux required)

    ```sh
    scripts/start-kafka-cli.sh
    ```

3. Kafka Management UI

    ```sh
    scripts/start-management-ui.sh
    ```

4. Shutdown

    ```sh
    scripts/shutdown.sh
    ```

5. Reset

    ```sh
    scripts/clean-up.sh
    ```

Local hacking
-------------

    scripts/download-dependencies.sh
    $(scripts/init-local-env.sh)
