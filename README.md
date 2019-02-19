Vault PKI - Demo
----------------

Prerequisities
--------------

* Openssl or LibreSSL
* Java >= 8

Configure Vault and Kafka
-------------------------

    scripts/download-dependencies.sh
    scripts/configure-vault.sh
    scripts/configure-kafka.sh

Kafka Clients
-------------

    scripts/configure-kafka-cli.sh
    scripts/start-consumer.sh
    scripts/start-producer.sh

Shutdown
--------

    scripts/shutdown.sh

Reset
-----

    scripts/clean-up.sh