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

# takes one parameter and checks whether given file is minishift binary file
# returns 1 if it is minishift binary or 0 otherwise
function test_minishift_binary {
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

function clear_minishift_home {
    log_info "Clearing minishift home directory"
    if [ -z ${MINISHIFT_HOME+x} ]; then
        log_info "MINISHIFT_HOME is not set"
        if [ -d ${HOME}/.minishift ]; then
            log_info "Deleting ${HOME}/.minishift"
            #rm -rf $HOME/.minishift
        fi
    else
        log_info "MINISHIFT_HOME is set to ${MINISHIFT_HOME}"
        if [ -d ${MINISHIFT_HOME} ]; then
            log_info "Deleting ${MINISHIFT_HOME}"
            #rm -rf $HOME/.minishift                
        fi
    fi
}
