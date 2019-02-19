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
        if [ "$(_detect_tmux)" == "false" ]; then
        echo "This command can only be used with tmux"
        exit 1
    fi

    _configure_producer
    _configure_consumer
    _start_consumer_and_producer
    
}

_main "$@"