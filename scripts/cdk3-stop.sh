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
    echo "Usage  $0 -p minishift_binary [--profile] profile_name"
    echo "       -p, --path (required)"
    echo "          Minishift binary path"
    echo "       --profile (optional)"
    echo "          Minishift profile"
    echo "       --all (optional)"
    echo "          Delete all minishift profiles"
    exit 1
}

# minishift clean up function takes minishift binary path as a parameter
function minishift_cleanup() {
    local minishift="$(get_absolute_filepath ${1})"
    echo "${minishift}"
    if [ $(support_profiles ${minishift}) == 1 ]; then
        minishift_delete ${minishift} "$(get_active_profile_status ${minishift})"
    else
        minishift_delete ${minishift} "$(${minishift} status)"
    fi
}

# minishift clean up function takes minishift binary path and profile name as a parameters
function minishift_cleanup_profile() {
    # status for cdk-3.2.0 and higher consists of 4 line string with status of minishift, openshift, diskusage and profile name
    local minishift="$(get_absolute_filepath ${1})"
    if [ -n "${2}" ]; then 
        if [ "$(check_profile ${minishift} ${2})" == 1 ]; then
            switch_profile ${minishift} ${2}
            minishift_delete ${minishift} "$(get_active_profile_status ${minishift})"
        else
            log_warning "Given profile ${2} is not listed in existing profiles: "
            log_info "Path given: ${minishift}"
            ${minishift} profile list
            exit 1
        fi
    else
        minishift_delete ${minishift} "$(get_active_profile_status ${minishift})"
    fi
}

function minishift_delete_all() {
    log_info "Deleting all profiles"
    log_info "Available profiles are:"
    list_all_profiles ${1}
    for profile in $(list_all_profiles ${1}); do
        minishift_cleanup_profile ${1} "${profile}"
    done
}

# takes two parameters. minishift path and miishift status
function minishift_delete() {
    # stop-delete minishift
    local minishift="${1}"
    local status="${2}"
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
        log_info "Do nothing here..."
    fi
}

SUPPORT_PROFILES=0
PROFILE=
MINISHIFT=
ACTIVE_PROFILE=
DELETE_ALL=0

if [ ${IS_SOURCE} == 0 ]; then
    # Two parameters are required
    if [ ! $# -gt 1 ]
    then
        log_error "Wrong number of parameters"
        usage
    fi

    while [ $# -gt 0 ]; do
        case $1 in
            -p | --path)
                shift
                if [ -f "${1}" ]; then
                    log_info "Trying to stop cdk with ${1}"
                    if [ $(support_profiles ${1}) == 1 ]; then
                        SUPPORT_PROFILES=1
                    fi
                    MINISHIFT="${1}"
                else
                    log_error "Given minishift binary path ${1} is not a file or does not exist"
                    exit 1
                fi
                ;;
            --profile)
                shift
                PROFILE="${1}"
                ;;
            --all)
                DELETE_ALL=1
                ;;
            *)
                usage
                ;;
        esac
        shift
    done
fi

if [ ${IS_SOURCE} == 0 ]; then
    log_info "Script parameters:"
    log_info "SUPPORT PROFILES: ${SUPPORT_PROFILES}"
    log_info "PROFILE PARAM: ${PROFILE}"
    log_info "MINISHIFT PATH: ${MINISHIFT}"

    if [ "${SUPPORT_PROFILES}" == 1 ]; then
        if [ ${DELETE_ALL} == 1 ]; then
            log_info "DELETE ALL is active"
            log_info "Deleting all profiles available..."
            minishift_delete_all ${MINISHIFT}
        elif [ -n "${PROFILE}" ]; then
            log_info "Profile to be stopped: ${PROFILE}"
            minishift_cleanup_profile ${MINISHIFT} "${PROFILE}"  
        else
            log_info "No profile specified, and given minishift is using profiles, stopping active profile: $(get_active_profile ${MINISHIFT})"
            minishift_cleanup_profile ${MINISHIFT} "$(get_active_profile ${MINISHIFT})"    
        fi
    else
        log_info "Stopping minishift..."
        minishift_cleanup ${MINISHIFT}
    fi
fi


        
        
        
        
