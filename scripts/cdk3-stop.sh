#!/bin/sh

set -e
# set -x

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
    # stop-delete minishift
    local minishift="$(realpath $1)"
    local status="$(${minishift} status)"
    log_info "Minishift status: ${status}"
    if [ "${status}" == "Running" ] || [ "${status}" == "Paused" ]; then
        ${minishift} stop || log_warning "minishift stop failed, proceeding..."
        log_info "Executing 'minishift delete --force'"
        ${minishift} delete --force
    elif [ "${status}" == "Stopped" ]; then
        ${minishift} stop || log_warning "minishift stop failed, proceeding..."
        log_info "Executing 'minishift delete --force'"
        ${minishift} delete --force
    else
        log_info "Do nothing here"
    fi
}

if [ ${IS_SOURCE} == 0 ]; then
    # Two parameters are required
    if [ ! $# -eq 2 ]
    then
        log_error "Wrong number of parameters"
        usage
    fi

    while [ $# -gt 0 ]; do
        case $1 in
            -p | --path)
                shift
                if [ -f "${1}" ]; then
                    if [ "$(minishift_has_status ${1})" == 0 ]; then
                        log_error "${1} is not minishift binary"
                        exit 1
                    fi
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

log_info "${__base} script finished successfully"
