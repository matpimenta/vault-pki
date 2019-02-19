Vault PKI - Demo
----------------

Prerequisities
--------------

* Linux / MacOS
* wget  
* Openssl or LibreSSL
* Java >= 8
* tmux (Optional)
* docker (Optional)

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

Kafka Clients in one window (tmux required)
-------------------------------------------

    scripts/start-kafka-cli.sh

Kafka Management UI
-------------------

    scripts/start-management-ui.sh

Shutdown
--------

    scripts/shutdown.sh

Reset
-----

    scripts/clean-up.sh