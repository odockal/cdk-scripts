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
    echo "       -u MINISHIFT_URL [-p] PATH_TO_MINISHIFT [-s] [SETUP_PARAMS]"
    echo "Usage  $0 -u MINISHIFT_URL [-p] PATH_TO_MINISHIFT [-s] [SETUP_PARAMS]"
    echo "       -u, --url (required)"
    echo "          CDK/minishift binary url to download, will overwrite existing minishift file"
    echo "       -p, --path (optional)"
    echo "          path where the file should be downloaded"
    echo "       -s, --setup (optional)"
    echo "          runs 'minishift setup-cdk' command, if params are given, it runs it with them"
    exit 1
}

MINISHIFT_PATH=$(pwd)
MINISHIFT_URL=
EXISTING=1
SETUP_CDK=
SETUP_PARAMS=
IS_CDK=1

# At least one parameter is required
if [ $# -lt 2 ]
then
  usage
fi

while [ $# -gt 0 ]; do
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
            url_status=$(http_status_ok ${1})
            log_info "Trying to reach ${1}"
            log_info "URL status: $url_status"
            if [ "${url_status}" ]; then
                if [ $(url_has_minishift ${1}) == "1" ]; then
                    MINISHIFT_URL="${1}"
                else 
                    MINISHIFT_URL="$(add_url_suffix ${1})"
                fi
            else
                log_error "Given minishift url ${1} cannot be reached"
                exit 1
            fi
            ;;
        -s | --setup)
            shift
            SETUP_CDK="setup-cdk"
            if [ -n "${1}" ]; then
                # we need to assure that -s flag has optinal parameter, so if another flag follows, we should skip passing that flag as a -s parameter
                if [[ ${1} =~ (^-[pu])|^--(path)|(^--(url)) ]]; then
                    continue
                else
                    SETUP_CDK="${SETUP_CDK} ${1}"
                    SETUP_PARAMS="${1}"
                fi
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

BASEFILE=$(basename ${MINISHIFT_URL})
log_info "Basefile name is: ${BASEFILE}"
log_info "Downloading minishift from ${MINISHIFT_URL}"
log_info "to $MINISHIFT_PATH"

# wget -O "${BASEFILE}" ${MINISHIFT_URL}
# consider using -k param to download using https
curl -L ${MINISHIFT_URL} -o ${BASEFILE}
if [ $? == 1 ]; then
    log_error "Downloading ${MINISHIFT_URL} fails to save the file as ${BASEFILE}"
    exit 1
fi

ARCHIVE="${BASEFILE##*.}"
if [ "${ARCHIVE}" == "tgz" ]; then
    IS_CDK=0
    tar --strip-components=1 -xvzf ${BASEFILE}
    BASEFILE=$(basename minishift)
    log_info "Basefile name has changed to: ${BASEFILE}"
elif [ "${ARCHIVE}" == "zip" ]; then
    IS_CDK=0
    unzip -j ${BASEFILE}
    BASEFILE=$(basename minishift.exe)
    log_info "Basefile name has changed to: ${BASEFILE}"
fi

if [ ${IS_CDK} == 1 ]; then
    if [ -n "${SETUP_CDK}" ]; then
        log_info "'minishift ${SETUP_CDK}' will be called"
    fi
else
    log_warning "Upstream minishift does not use setup-cdk command"
    if [ -n "${SETUP_PARAMS}" ]; then
        log_info "Instead, minishift config set ${SETUP_PARAMS}"
    fi
fi

# distinguish between minishift's archive file (upstream minishift) - unzip it, skip calling setup-cdk
# or check output from minishift version

log_info "Make the file executable"
chmod +x ${BASEFILE}

if [ ${IS_CDK} == 1 ]; then
    log_info "It is using CDK downstream version"
    if [ $(minishift_not_initialized "${MINISHIFT_PATH}/${BASEFILE}") == 1 ]; then
        log_info "Minishift was not initialized"
        if [ -n "${SETUP_CDK}" ]; then
            log_info "Running ${MINISHIFT_PATH}/${BASEFILE} ${SETUP_CDK}"
            ${MINISHIFT_PATH}/${BASEFILE} ${SETUP_CDK}
        else
            log_warning "'minishift setup-cdk' will not be called, did you forget to set -s flag?"
        fi
    else
    log_warning "Minishift was already initialized, it is possible that older minishift configuration was not cleaned up. Consider using of cdk3-cleanup.sh..." 
    fi
else
    log_info "It is using upstream Minishift version"
    if [ -n "${SETUP_PARAMS}" ]; then
        log_info "Calling: ${BASEFILE} config set ${SETUP_PARAMS}"
        ${MINISHIFT_PATH}/${BASEFILE} config set ${SETUP_PARAMS}
    fi    
fi

log_info "Script $__base was finished successfully"
