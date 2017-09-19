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

STATUS_SETUP="setup-cdk"
STATUS_NONEXISTING="Does Not Exist"
STATUS_RUNNING="Running"
STATUS_STOPPED="Stopped"
STATUS_PAUSED="Paused"

declare -r STATUSES=("${STATUS_SETUP}" "${STATUS_NONEXISTING}" "${STATUS_RUNNING}" "${STATUS_STOPPED}" "${STATUS_PAUSED}")

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
    local output="$($(realpath ${1}) status)"
    if [[ "${output}" == *"${STATUS_SETUP}"* ]]; then
        echo 1
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
        HOME_ADDRESS=${HOME}
        if [ $(get_os_platform) == "win" ]; then
            HOME_ADDRESS=${USERPROFILE}
        fi
        log_info "Searching for .minishift in ${HOME_ADDRESS}"
        if [ -d ${HOME_ADDRESS}/.minishift ]; then
            log_info ".minishift exists"
            delete_path ${HOME_ADDRESS}/.minishift
        else
            log_info "There is no .minishift folder in user's home: ${HOME_ADDRESS}"
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

# return os/kernel that script runs on
function get_os_platform {
    if [[ "$(uname)" = *CYGWIN* ]]; then 
        echo "win"
    elif [[ "$(uname)" = *Linux* ]]; then 
        echo "linux"
    else 
        echo $(uname)
    fi
}

function add_url_suffix {
    if [ "$(get_os_platform)" == "linux" ]; then
        echo "${1}/linux-amd64/minishift"
    elif [ "$(get_os_platform)" == "win" ]; then
        echo "${1}/windows-amd64/minishift.exe"
    else
        echo "It is another os: $(get_os_platform)"
        exit -1
    fi
}

# checks whether basename of url contains word minishift
function url_has_minishift {
    if [[ $(basename ${1}) = *minishift* ]]; then
        echo 1
    else
        echo 0
    fi
}

# returns http status only if status is in class 2 or 3 (2xx - successful or 3xx - redirected)
function http_status_ok {
    echo $(curl -Is -l ${1} | head -n 1 | grep -i http/1 | awk {'print $2'} | grep -E '2[0-9]{2}|3[0-9]{2}')
}

# check if underline os is windows 7, returns 1 if yes, 0 otherwise
function is_windows7 {
    if [ $(get_os_platform) == "win" ]; then
        OS_NAME="$(powershell.exe "@(gwmi -Class Win32_OperatingSystem)[0] | Select -ExpandProperty Caption" | tr -d '\r\n' | grep -o "Windows 7")"
        if [ "$OS_NAME" == "Windows 7" ]; then
            echo 1
        else
            echo 0
        fi
    else
        echo 0
    fi
}
