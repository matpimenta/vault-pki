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

source ${__dir}/main.sh

_main() {
    _create_kafka_truststore
    _configure_kafka_tls
    _start_zookeeper
    _configure_kafka_acl
    _start_kafka
}

_main "$@"