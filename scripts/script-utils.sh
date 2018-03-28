#!/bin/sh

# Script utilities

function log_info {
    echo -e "[INFO] $@"
}

function log_error {
    echo -e "[ERROR] $@"
}

function log_warning {
    echo -e "[WARNING] $@"
}

STATUS_SETUP="setup-cdk"
STATUS_NONEXISTING="Does Not Exist"
STATUS_RUNNING="Running"
STATUS_STOPPED="Stopped"
STATUS_PAUSED="Paused"

declare -rx STATUSES=("${STATUS_SETUP}" "${STATUS_NONEXISTING}" "${STATUS_RUNNING}" "${STATUS_STOPPED}" "${STATUS_PAUSED}")

# mac does not have realpath command, so this function substituts it
# takes one parameter (path of the file)
function get_absolute_filepath {
    if [ -f ${1} ]; then
        if [ "$(get_os_platform)" == "mac" ]; then
            DIR=$(dirname ${1})
            FILE=$(basename ${1})
            echo "${DIR}/${FILE}"
        else
            echo ${1}
        fi
    else
        log_error "File on path ${1} does not exist"
        exit 1
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

# For actual profile
# Checks whether given path returns one of minishift statuses
function minishift_has_status {
    local minishift=$(get_absolute_filepath ${1})
    local output=""
    if [ $(support_profiles ${minishift}) == 1 ]; then
        output=$(get_active_profile_status ${minishift})
    else
        output="$(${minishift} status)"
    fi
    local result=0
    for item in "${STATUSES[@]}"; do
        if [[ "${output}" == *"${item}"* ]]; then
            result=1
            break
        fi
    done
    # [[ ${result} = 0 ]] && echo 0 || echo 1
    echo ${result}
}

# For actual profile
# checks if minishift setup-cdk was called
function minishift_not_initialized {
    local output="$($(get_absolute_filepath ${1}) status)"
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
        log_info "Searching for .kube in ${HOME_ADDRESS}"
        if [ -d ${HOME_ADDRESS}/.kube ]; then
            log_info ".kube exists"
            delete_path ${HOME_ADDRESS}/.kube
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
    elif [[ "$(uname)" == *Darwin* ]]; then
        echo "mac"
    else
        echo $(uname)
    fi
}

function add_url_suffix {
    if [ "$(get_os_platform)" == "linux" ]; then
        echo "${1}/linux-amd64/minishift"
    elif [ "$(get_os_platform)" == "win" ]; then
        echo "${1}/windows-amd64/minishift.exe"
    elif [ "$(get_os_platform)" == "mac" ]; then
        echo "${1}/darwin-amd64/minishift"
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

# checks minishift version if profile is featured
# return 1 if it supports profiles, 0 otherwise
# from minishift v1.7.0 above
function support_profiles {
    if [ -n "${1}" ]; then
        minishift_ver=$(minishift_version ${1})
        # cdk_version=$(${1} version | grep --ignore-case -e "cdk" | sed 's/.*[v]\([0-9]\.[0-9]\.[0-9]\).*/\1/')
        # echo -e "Minishift version: ${minishift_version}"
        # echo -e "CDK version: ${cdk_version}"
        profile_support=$(compare_versions ${minishift_ver} "1.6.9")
        if [ ${profile_support} == "1" ] || [ ${profile_support} == "0" ]; then
            echo 1
        else
            echo 0
        fi
    else
        echo 0
    fi
}

# Returns minishift version, takes 1 param
function minishift_version {
    version=$("${1}" version | grep --ignore-case -e "minishift" | sed 's/^.*[v]\([0-9]*\.[0-9]*\.[0-9]*\).*$/\1/')
    echo ${version}
}

# Returns minishift version, takes 1 param
function cdk_version {
    version=$(${1} version | grep --ignore-case -e "cdk" | sed 's/^.*[v]\([0-9]*\.[0-9]*\.[0-9]*\).*$/\1/')
    echo ${version}
}

# comparison of two string in x.x.x format, where x is higher or equal to 0
# if first version is higher than second, returns 1
# else if first is equal to second, returns 0
# else returns -1
function compare_versions () {
    if [ ! $# -eq 2 ]; then
        log_error "You need to pass two version strings into version compare function..."
        exit 1
    fi
    parse_version_string ${1}
    parse_version_string ${2}
    # log_info "Comparing ${1} to ${2}"
    if [[ "${1}" == "${2}" ]]; then 
        echo 0
    else
        declare -r version1=("$(echo ${1} | cut -d . -f1)" "$(echo ${1} | cut -d . -f2)" "$(echo ${1} | cut -d . -f3)")
        declare -r version2=("$(echo ${2} | cut -d . -f1)" "$(echo ${2} | cut -d . -f2)" "$(echo ${2} | cut -d . -f3)")
        # compare major versions
        if [ ${version1[0]} -gt ${version2[0]} ]; then
            echo 1
        elif [ ${version1[0]} -eq ${version2[0]} ];then
            if [ ${version1[1]} -gt ${version2[1]}  ]; then 
                echo 1
            elif [ ${version1[1]} -eq ${version2[1]} ];then
                if [ ${version1[2]} -gt ${version2[2]}  ]; then 
                    echo 1
                else
                    echo -1
                fi
            else
                echo -1
            fi
        else
            echo -1
        fi
    fi
}

# Parse version string, must be in format #.#.#
function parse_version_string {
    if [ -n "${1}" ]; then
        expression="$(echo ${1} | sed 's/\([0-9]*\.[0-9]*\.[0-9]*\)/YES/')"
        if [ "${expression}" == "YES" ]; then
            return
        else
            log_error "Version string must consist of number and dots only, in format #.#.#"
            exit 1
        fi
    else
        log_error "Version string cannot be empty"
        exit 1
    fi
}


# get active profile
# if supports profiles, should return simething like this:
# - minishift Stopped
# - profile1 Running
# if actually active profile did not have run 'minishift setup-cdk' it returns familiar message about the need to call minishift setup-cdk
function get_active_profile() {
    if [ $(minishift_not_initialized ${1}) == 0 ]; then
        if [ $(support_profiles ${1}) == 1 ]; then 
            # Without quotes, the shell replaces $TEMP with the characters it contains (one of which is a newline).
            # Then, before invoking echo shell splits that string into multiple arguments using the Internal Field Separator (IFS), and 
            # passes that resulting list of arguments to echo. 
            # By default, the IFS is set to whitespace (spaces, tabs, and newlines), 
            # so the shell chops your $TEMP string into arguments and it never gets to see the newline, 
            # because the shell considers it a separator, just like a space.
            profiles="$(echo "$(${1} profile list)")"
            # echo "$profiles"
            active_profile="$(echo "${profiles}" | grep -i \(active\))"
            # echo "Active profile: ${active_profile}"
            echo "$(echo "${active_profile}" | awk '{print $2}')"
        else
            log_error "Given minishift: ${1} does not support profiles..."
            exit 1
        fi
    else
        log_error "There was not called 'minishift setup-cdk' for active profile"
        exit 1
    fi
}

# prints out all profile obtained via minishift profile list, takes minishift binary as param
function list_all_profiles() {
    for line in "$(${1} profile list)"; do
        echo "${line}" | awk '{print $2}'
    done
}

# check the existence of given profile
function check_profile() {
    if [ $(support_profiles ${1}) == 1 ]; then
        local exists=0
        for line in $(list_all_profiles ${1}); do
            if [ "${line}" == "${2}" ]; then
                exists=1
            fi
        done
        echo ${exists}
    fi
}

# switch profile to desired one
# Requires two parameters, minishift binary and profile name to switch to
function switch_profile() {
    if [ $# -eq 2 ]; then
        if [ $(minishift_has_status ${1}) == 1 ]; then
            output="$(${1} profile set ${2})"
            if [ ! $? -eq 0 ]; then 
                exit 1
            fi
            log_info "${output}"
        else
            log_error "Given minishift path ${1} does not contain minishift binary..."
            exit 1
        fi
    else
        log_error "Wrong number of parameters..."
        exit 1
    fi
}

# get minishift active profile status
function get_active_profile_status() {
    local status="$(${1} status)"
    if [[ ${status} == *${STATUS_NONEXISTING}* ]]; then
        echo ${status}
    elif [[ ${status} == *${STATUS_SETUP}* ]]; then
        echo ${status}
    else 
        echo "$(echo "${status}" | grep "Minishift:" | awk '{print $2}')"
    fi
}

# get minishift desired profile status
# takes minishift path and profile
function get_profile_status() {
    if [ $# -eq 2 ]; then
        echo "$(${1} --profile ${2} status)"
        if [ ! $? -eq 0 ]; then 
            exit 1
        fi
    else
        log_error "Wrong number of parameters..."
        exit 1
    fi
}
