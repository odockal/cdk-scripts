#!/bin/sh

# Script utilities

function log_info {
    echo "[INFO] $@"
}

function log_error {
    echo "[ERROR] $@"
}

function log_warning {
    echo "[WARNING] $@"
}

STATUS_SETUP="You need to run 'minishift setup-cdk' first to install required CDK components"
STATUS_NONEXISTING="Does Not Exist"
STATUS_RUNNING="Running"
STATUS_STOPPED="Stopped"

declare -r STATUSES=("${STATUS_SETUP}" "${STATUS_NONEXISTING}" "${STATUS_RUNNING}" "${STATUS_STOPPED}")

# Takes one parameter and checks whether given file is minishift binary file
# Beware, minishift version creates minishift folder structure in minishift_home
# returns 1 if it succeeds or 0 otherwise
function call_minishift_version {
    if [ -f ${1} ]; then
        output="$($(realpath ${1}) version)"
        if [[ "${output}" == *"Minishift"* ]]; then
            echo 1
        else 
            echo 0
        fi
    else
        echo 0
    fi
}

# Deletes given path
function delete_path {
    if [ -e "${1}" ]; then
        log_info "Deleting ${1}"
        rm -rf ${1}
    else
        log_warning "'${1}' is not a file or a directory"
    fi
}

# Checks whether given path returns one of minishift statuses
function minishift_has_status {
    local output="$($(realpath ${1}) status)"
    local result=0
    for item in "${STATUSES[@]}"; do
        if [[ "${output}" == *"${item}"* ]]; then
            result=1
            break
        fi
    done
    [[ ${result} = 0 ]] && echo 0 || echo 1
}

# checks if minishift setup-cdk was called
function minishift_not_initialized {
    if [ -f ${1} ]; then
        output="$($(realpath ${1}) status)"
        if [[ "${output}" == *"${STATUS_SETUP}"* ]]; then
            echo 1
        else 
            echo 0
        fi
    else
        echo 0
    fi   
}

function clear_minishift_home {
    log_info "Clearing minishift home directory"
    if [ $# -eq 1 ] && [ -d ${1} ]; then
        log_info "Deleting given ${1}"
        delete_path ${1}
    elif [ -z ${MINISHIFT_HOME+x} ]; then
        log_info "MINISHIFT_HOME is not set"
        if [ -d ${HOME}/.minishift ]; then
            delete_path ${HOME}/.minishift
        fi
    elif [ -d "${MINISHIFT_HOME}" ]; then
        log_info "MINISHIFT_HOME is set to ${MINISHIFT_HOME}"
        if [ -d ${MINISHIFT_HOME} ]; then
            delete_path ${MINISHIFT_HOME}                
        else
            log_warning "$MINISHIFT_HOME does not exist"
        fi
    else
        log_info "Nothing to clear"
    fi
}
