#!/bin/sh

# set -e
# set -x

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

. "${__dir}/script-utils.sh"

# usage output
function usage {
    echo "Minishift install script"
    echo "Synopsis:"
    echo "       -u minishift_url -p minishift_path"
    echo "Usage  $0 -u [-p]"
    echo "       -u, --url (required)"
    echo "          CDK/minishift binary url to download, will overwrite existing minishift file"
    echo "       -p, --path (optional)"
    echo "          path where the file should be downloaded"
    exit 1
}

MINISHIFT_PATH=$(pwd)
MINISHIFT_URL=
EXISTING=1

# At least one parameter is required
if [ $# -lt 2 ]
then
  usage
fi

while [ $# -gt 1 ]; do
    case $1 in
        -p | --path)
            shift
            MINISHIFT_PATH=${1}
            if [ ! -e ${MINISHIFT_PATH} ]; then
                log_warning "${MINISHIFT_PATH} does not exist, will be created"
                EXISTING=0
            elif [ -d ${MINISHIFT_PATH} ]; then
                log_info "${MINISHIFT_PATH} is an existing folder"
                EXISTING=1
            elif [ ! -d ${MINISHIFT_PATH} ]; then
                log_error "${MINISHIFT_PATH} is not a directory..."
                exit 1
            fi
            ;;
        -u | --url)
            shift
            url_status=$(curl -Is -l ${1} | head -n 1 | grep -i ok)
            log_info "Trying to reach ${1}"
            log_info "URL status: $url_status"
            if [ "${url_status}" ]; then
                MINISHIFT_URL="${1}"
            else
                log_error "Given minishift url ${1} cannot be reached"
                exit 1
            fi
            ;;
        *)
            usage
            ;;
	esac
	shift
done

if [ ${EXISTING} == 0 ]; then
    log_info "Creating ${MINISHIFT_PATH}"
    mkdir -p ${MINISHIFT_PATH}
fi

cd ${MINISHIFT_PATH}

log_info "Downloading minishift from ${MINISHIFT_URL}"
log_info "to $MINISHIFT_PATH"

wget -O minishift ${MINISHIFT_URL}
if [ $? == 1 ]; then
    log_error "Downloading ${MINISHIFT_URL} fails to save the file as minishift"
    exit 1
fi

log_info "Make the file executable"
chmod +x minishift

if [ $(minishift_not_initialized "${MINISHIFT_PATH}/minishift") == 1 ]; then
    log_info "Minishift was not initialized, running 'minishift setup-cdk'"
    ${MINISHIFT_PATH}/minishift setup-cdk
fi
