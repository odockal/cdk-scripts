#!/bin/sh

set -e
#set -x

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

#. "${__dir}/script-utils.sh"
. "${__dir}/cdk3-stop.sh"

# Script checks existence of minishift binary on a given minishift path
# If minishift binary is found, minishift vm is stopped (if running) and deleted with minishift commands
# and all the artifacts are also deleted
# In case that minishift binary file is not found, cdk minishift is downloaded
# and test for existing running minishift vm is performed
# Minishift is stopped, deleted and files are removed

# usage output
function usage {
    echo "Minishift clean up script"
    echo "Synopsis:"
    echo "       -p minishift_path -u minishift_url -h minishift_home"
    echo "Usage  $0 -p [-h] [-u]"
    echo "       -p, --path (required)"
    echo "          path with minishift binary or directory where new minishift will be downloaded"
    echo "       -u, --url (optional)"
    echo "          CDK/minishift binary url to download"
    echo "       -e, --erase"
    echo "          Will erase minishift binary, created folders and minishift home folder"
    echo "          Use it on your own risk!"
    exit 1
}

# checks whether given parameter is a single file
function check_minishift_bin() {
    # function could take multiple params
    log_info "Number of found minishift binaries: $#"
    if [ $# -eq 0 ]; then
        log_warning "There was no minishift binary in the path $MINISHIFT_PATH"
    elif [ $# -eq 1 ]; then
        log_info "Minishift binary resides in $@"
    elif [ $# -gt 1 ]; then
        log_error "There are multiple minishift binary files on the path:"
        for word in $@; do
            log_error $word
        done
        log_error "Script requires single minishift binary"
        exit 1
    else
        log_error "Unknown error while parsing parameters: $@"
        exit 1
    fi
}

MINISHIFT_PATH=
MINISHIFT_URL=
USER_HOME=
HOME_FOLDER=
EXISTING=1
ERASE=0
BASEFILE=

# At least one parameter is required
if [ $# -lt 1 ]
then
  usage
fi

while [ $# -gt 0 ]; do
    case $1 in
        -p | --path)
            shift
            MINISHIFT_PATH=${1}
            if [ ! -e ${1} ]; then
                log_warning "${MINISHIFT_PATH} does not exist, will be created"
                EXISTING=0
            elif [ -f ${1} ] && [ $(minishift_has_status "${MINISHIFT_PATH}") == 1 ]; then
                BASEFILE=$(basename ${MINISHIFT_PATH})
                log_info "Minishift binary ${MINISHIFT_PATH} will be used..."
            elif [ -d ${1} ]; then
                log_info "${MINISHIFT_PATH} is a folder..."
                EXISTING=0
            fi
            ;;
        -u | --url)
            shift
            url_status=$(http_status_ok ${1})
            log_info "Trying to reach ${1}"
            log_info "URL status: $url_status"
            if [ "${url_status}" ]; then
                if [ $(url_has_minishift ${1}) == "1" ]; then
                    MINISHIFT_URL="${1}"
                else 
                    MINISHIFT_URL="$(add_url_suffix ${1})"
                fi
                BASEFILE=$(basename ${MINISHIFT_URL})
            else
                log_error "Given minishift url ${1} cannot be reached"
                exit 1
            fi
            ;;
        -e | --erase)
            ERASE=1
            log_warning "Erase mode is on!!!"
            ;;
        *)
            usage
            ;;
	esac
	shift
done

HOME_ADDR="${HOME}"
if [ "$(get_os_platform)" == "win" ]; then
    HOME_ADDR="${USERPROFILE}"
fi
log_info "User's home folder is at ${HOME_ADDR}"

if [ -z $MINISHIFT_PATH ]; then
    log_error "--p or --path cannot be empty"
    usage
fi

# if there is no minishift home
# clearing makes no sense because we are not able to operate
# without minishift_home defined in previous jenkins job
if [ -n "${MINISHIFT_HOME}" ]; then
    log_info "Minishift home is set with MINISHIFT_HOME env. var., ${MINISHIFT_HOME}"
elif [ -d "${HOME_ADDR}/.minishift" ]; then
        HOME_FOLDER="${HOME_ADDR}/.minishift"
        log_info "Minishift home is at ${HOME_FOLDER}"
else
    log_warning "Minishift home does not exist, cannot clean old minishift configuration"
    exit 0
fi

log_info "Script parameters:"
log_info "MINISHIFT_PATH: ${MINISHIFT_PATH}"
log_info "Basefile name is: ${BASEFILE}"
log_info "MINISHIFT_URL: ${MINISHIFT_URL:-"Not set"}"

# Start script main part
if [ $EXISTING == 1 ]; then
    log_info "Checking existence of actual minishift instance..."
    minishift_cleanup $MINISHIFT_PATH
    # remove the direcotry with minishift
    if [ $ERASE == 1 ]; then
        delete_path "$(dirname ${MINISHIFT_PATH})"
    fi
else
# if there is no minishift file, there still could be running minishift vm
    # Download minishift, make it runnable and checks if there is running minishift vm
    # check that minishift url contains minishift binary file
    if [ -n "${MINISHIFT_URL}" ]; then
        if [ -n "$(curl -Is -l "${MINISHIFT_URL}" | head -n 1 | grep -i ok)" ]; then
            foldername="minishift_$(date +%Y-%m-%d_%H%M%S)"
            log_info "Creating directory $MINISHIFT_PATH/${foldername}"
            MINISHIFT_PATH=$MINISHIFT_PATH/${foldername}
            mkdir -p $MINISHIFT_PATH
            cd $MINISHIFT_PATH
            log_info "Downloading minishift from ${MINISHIFT_URL}"
            log_info "to $MINISHIFT_PATH"
            curl $MINISHIFT_URL -o ${BASEFILE}
            if [ ! -f "${MINISHIFT_PATH}/${BASEFILE}" ]; then
                log_info "Content of $MINISHIFT_PATH"
                log_info "$(ls $MINISHIFT_PATH)"
                if [ $ERASE == 1 ]; then
                    delete_path "$(dirname $MINISHIFT_PATH)" 
                fi
                log_error "Minishift file was not downloaded from $MINISHIFT_URL, please, check the given url"
                exit 1
            fi
            chmod +x ${BASEFILE}
            MINISHIFT_BIN=$(get_absolute_filepath ${BASEFILE})
            # stop/delete minishift
            minishift_cleanup $MINISHIFT_BIN
            if [ $ERASE == 1 ]; then
                delete_path "$(dirname $MINISHIFT_PATH)"
            fi
        else
            log_error "Cannot download minishift from $MINISHIFT_URL"
            exit 1
        fi
    else
        log_error "No url was specified"
        exit 1
    fi
fi

if [ $ERASE == 1 ]; then
    clear_minishift_home
fi

log_info "Script ${__base} was finished..."
