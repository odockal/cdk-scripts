#!/bin/sh

# set -e

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

IS_SOURCE=0
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    IS_SOURCE=1
fi
# Stops and deletes given existing minishift instance
# Takes parameter that represents path to minishift binary file

. "${__dir}/script-utils.sh"

# usage output
function usage {
    echo "Minishift stop script"
    echo "Usage  $0 -p minishift_binary"
    echo "       -p, --path (required)"
    echo "          Minishift binary path"
    exit 1
}

# minishift clean up function takes minishift binary path as a parameter
function minishift_cleanup() {
    # stop-delete minishift and remove binary file
    minishift="$(realpath $1)"
    status="$(${minishift} status)"
    log_info "Minishift status: ${status}"
    if [ "${status}" == "Running" ]; then
        ${minishift} stop
        ${minishift} delete
    elif [ "${status}" == "Stopped" ]; then
        ${minishift} delete
    fi
}

if [ ${IS_SOURCE} == 1 ]; then
    log_info "${__file} is sourced"
else
    log_info "${__file} is running"
    # Two parameters are required
    if [ ! $# -eq 2 ]
    then
        usage
    fi

    while [ $# -gt 0 ]; do
        case $1 in
            -p | --path)
                shift
                if [ -f "${1}" ]; then
                    if [ "$(test_minishift_binary ${1})" == 0 ]; then
                        log_error "${1} is not minishift binary"
                        exit 1
                    fi
                    clear_minishift_home
                    log_info "Trying to stop cdk with ${1}"
                    minishift_cleanup ${1}
                else
                    log_error "Given minishift binary path ${1} is not a file or does not exist"
                    exit 1
                fi
                ;;
            *)
                usage
                ;;
        esac
        shift
    done
fi
