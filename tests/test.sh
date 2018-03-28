#!/bin/sh

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

if [ -f ${1} ]; then
    . ${1}
else
    echo "File ${1} does not exist"
    exit 1
fi

passed_tests=0
failed_tests=0
erroneous_tests=0
total_tests=0
total_test_cases=0

function fail() {
    if [ -n "${1}" ]; then
        echo "${1}"
    fi
    ((failed_tests++))
    ((total_tests++))
    echo "Resolution: FAILED"
}

function pass() {
    if [ -n "${1}" ]; then
        echo "${1}"
    fi
    ((passed_tests++))
    ((total_tests++))
    echo "Resolution: PASSED"
}

function error() {
    if [ -n "${1}" ]; then
        echo "${1}"
    fi
    echo "Resolution: ERROR"
    ((erroneous_tests++))
    ((total_tests++))
}

function test_start() {
    echo ""
    echo "### Test Case ###"
    if [ -n "${1}" ]; then
        echo "  ${1}"
        echo ""
    fi
    ((total_test_cases++))
}

function summary() {
    echo ""
    echo "#################"
    echo "Tests resolution:"
    echo "Tests passed:     ${passed_tests}"
    echo "Tests failed:     ${failed_tests}"
    echo "Tests in error:   ${erroneous_tests}"
    echo "Total tests run:  ${total_tests}"
    echo "Test cases:       ${total_test_cases}"
}

function output_contains {
    echo "Test that output string contains given substring:"
    echo -e "Output: ${1}"
    echo "Contains: ${2}"
    if [[ "${1}" == *${2}* ]]; then
        pass
        return
    else
        fail
    fi
}

function has_one_of() {
    echo "Checks if sequence '${1}' contains one of items"
    for item in ${@:2}; do
        if [[ ${1} == *$item* ]]; then
            pass
            return
        fi
    done
    fail "None of '${@:2}' contained '${1}'"
}

function test_not_empty() {
    echo "Testing if '${1}' is not empty..."
    if [ "${1}" ]; then
        pass
    else
        fail
    fi    
}

function test_is_empty() {
    echo "Testing if '${1}' is empty..."
    if [ -z "${1}" ]; then
        pass
    else
        fail
    fi    
}

EXISTING_PATH="${HOME}/"
EXISTING_FILE="${__file}"
NON_EXISTING_FILE="${HOME}/random_file"

MINISHIFT_PROFILE_STATUS_RUNNIG="
Minishift:  Running
Profile:    minishift2
OpenShift:  Stopped
DiskUsage:  56% of 3.9G
"
MINISHIFT_PROFILE_STATUS_STOPPED="
Minishift:  Stopped
Profile:    minishift2
OpenShift:  Stopped
DiskUsage:  56% of 3.9G
"
MINISHIFT_PROFILE_STATUS_PAUSED="
Minishift:  Paused
Profile:    minishift2
OpenShift:  Stopped
DiskUsage:  56% of 3.9G
"
MINISHIFT_SETUP_CDK="You need to run 'minishift setup-cdk' first to install required CDK components."
MINISHIFT_DOES_NOT_EXIST="Does Not Exist"
MINISHIFT_PROFILE_LIST="
- minishift     Running        (Active)
- minishift2        Stopped
- nonregistered     Stopped
"
MINISHIFT_PROFILE_LIST_2="
- minishift     Stopped
- minishift2        Stopped     (Active)
- nonregistered     Stopped
"
MINISHIFT_VERSION_OLD="
minishift v1.3.1+a2d3799
CDK v3.1.1-1
"
MINISHIFT_VERSION_PROFILE="
minishift v1.13.1+75352e5
CDK v3.4.0-alpha.1-1
"

# Tests for script-utils.sh functions
function test_get_absolute_filepath {
    test_start "get_absolute_filepath"
    output_contains "$(get_absolute_filepath $EXISTING_PATH)" "does not exist"
    output_contains "$(get_absolute_filepath $NON_EXISTING_FILE)" "does not exist"
    output_contains "$(get_absolute_filepath $EXISTING_FILE)" "${__file}"
}

# Unit tests for script-utils.sh functions

# Deletes given path
# function delete_path
function test_delete_path {
    test_start "delete_path"
    today=$(date +%Y%d%m)
    touch untouchable_file
    mkdir folder_${today}
    touch folder_${today}/myfile
    myfile=${__dir}/folder_${today}/myfile
    echo ${myfile}
    if [ -f ${myfile} ]; then
        echo "${myfile} exists"
    else
        error "File was not created"
    fi
    output_contains "$(delete_path folder_${today}_xxx)" "is not a file or a directory"
    output_contains "$(delete_path folder_${today})" "Deleting folder_${today}"
    if ! [ -e ${myfile} ] && ! [ -e ${__dir}/folder_${today} ] && [ -e ${__dir}/untouchable_file ]; then
        echo "Deleted successfully"
        echo "PASSED"
    else
        fail "Content was not deleted: ${myfile}"
    fi
}

# For actual profile
# Checks whether given path returns one of minishift statuses
# function minishift_has_status 
#test_start "minishift_has_status"
#output_contains "$(minishift_has_status "mocker.sh ${MINISHIFT_SETUP_CDK}")" "1"

# For actual profile
# checks if minishift setup-cdk was called
# function minishift_not_initialized 
# function clear_minishift_home


# return os/kernel that script runs on
# function get_os_platform 
function test_get_os_platform {
    test_start "get_os_platform"
    has_one_of "$(get_os_platform)" "win" "linux" "darwin"
}

# function add_url_suffix
function test_add_url_suffix {
    test_start "add_url_suffix"
    has_one_of "$(add_url_suffix 'http://www.top.domain/minishift/os')" "linux-amd64/minishift" "darwin-amd64/minishift" "windows-amd64/minishift.exe"
}

# checks whether basename of url contains word minishift
# function url_has_minishift 
function test_url_has_minishift {
    test_start "url_has_minishift"
    output_contains "$(url_has_minishift 'http://some.url.top/minishift/v1.14.1/minishift.tar.gz')" "1"
    output_contains "$(url_has_minishift 'http://some.url.top/minishift/v1.14.1/minishift.zip')" "1"
    output_contains "$(url_has_minishift 'http://some.url.top/minishift/v1.14.1/minishift/cdk.exe')" "0"
}

# returns http status only if status is in class 2 or 3 (2xx - successful or 3xx - redirected)
# function http_status_ok 
function test_http_status_ok {
    test_start "http_status_ok"
    test_not_empty $(http_status_ok 'https://httpbin.org')
    test_not_empty $(http_status_ok 'https://httpbin.org/status/302')
    test_not_empty $(http_status_ok 'https://httpbin.org/status/200')
    test_is_empty $(http_status_ok 'https://httpbin.org/status/404')
    test_is_empty $(http_status_ok 'https://httpbin.org/status/503')
}


# check if underline os is windows 7, returns 1 if yes, 0 otherwise
# function is_windows7 

# checks minishift version if profile is featured
# return 1 if it supports profiles, 0 otherwise
# from minishift v1.7.0 above
# function support_profiles {

# Returns minishift version, takes 1 param
# function minishift_version
function test_minishift_version {
    test_start "minishift_version"
    output_contains "$(minishift_version ${__dir}/mocker.sh \"${MINISHIFT_VERSION_OLD}\")" "1.3.1"
}

function test_mocker {
    test_start "mocker test"
    output_contains "$(./mocker.sh "${MINISHIFT_VERSION_OLD}" version)" "1.3.1"
    output_contains "$(./mocker.sh "${MINISHIFT_PROFILE_STATUS_RUNNIG}" status)" "Minishift:  Running"
    output_contains "$(./mocker.sh "${MINISHIFT_PROFILE_LIST}" "profile list")" "- minishift "
}

# Returns minishift version, takes 1 param
# function cdk_version 

# comparison of two string in x.x.x format, where x is higher or equal to 0
# if first version is higher than second, returns 1
# else if first is equal to second, returns 0
# else returns -1
# function compare_versions

# Parse version string, must be in format #.#.#
# function parse_version_string


# get active profile
# if supports profiles, should return simething like this:
# - minishift Stopped
# - profile1 Running
# if actually active profile did not have run 'minishift setup-cdk' it returns familiar message about the need to call minishift setup-cdk
# function get_active_profile()

# prints out all profile obtained via minishift profile list, takes minishift binary as param
# function list_all_profiles()

# check the existence of given profile
# function check_profile() 

# switch profile to desired one
# Requires two parameters, minishift binary and profile name to switch to
# function switch_profile()

# get minishift active profile status
# function get_active_profile_status() 

# get minishift desired profile status
# takes minishift path and profile
# function get_profile_status() 

test_add_url_suffix
test_delete_path
test_get_absolute_filepath
test_get_os_platform
test_http_status_ok
test_url_has_minishift
test_mocker
#test_minishift_version

summary
echo "Testing has ended"


