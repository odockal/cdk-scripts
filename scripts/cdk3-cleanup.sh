#!/bin/sh

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
    echo "       -p minishift_path -h minishift_home -u minishift_url"
    echo "Usage  $0 -p [-h] [-u]"
    echo "       -p, --path (required)"
    echo "          minishift folder with minishift binary"
    echo "       -h, --home (optional)"
    echo "          path to the minisihft home folder, default is home folder"
    echo "       -u, --url (optional)"
    echo "          CDK/minishift binary url"
    exit 1
}

function log_info {
    echo "[INFO] $@"
}

function log_error {
    echo "[ERROR] $@"
}

function log_warning {
    echo "[WARNING] $@"
}

# minishift clean up function takes minishift binary path as a parameter
function minishift_cleanup() {
    # stop-delete minishift and remove binary file
    minishift=$(realpath $1)
    status=$($minishift status)
    log_info "Minishift status: $status"
    if [ "$status" == "Running" ]; then
        $minishift stop
        $minishift delete
    elif [ "$status" == "Stopped" ]; then
        $minishift delete
    fi
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

HOME_FOLDER=$HOME
MINISHIFT_PATH=
MINISHIFT_URL=
EXISTING=1

# At least one parameter is required
if [ $# -lt 1 ]
then
  usage
fi

while [ $# -gt 0 ]; do
    case $1 in
        -h | --home)
            shift
            if [ -d ${1} ]; then
                HOME_FOLDER=${1}
            else
                log_warning "Given path ${1} is not a folder or does not exist"
                log_warning "$HOME will be used as a minishift home directory"
            fi
            ;;
        -p | --path)
            shift
            MINISHIFT_PATH=${1}
            if [ ! -e ${1} ]; then
                log_warning "$MINISHIFT_PATH does not exist, will be created"
                EXISTING=0
            elif [ -f ${1} ]; then
                log_error "Given minishift path ${1} is a file, expects a directory"
                exit 1
            fi
            ;;
        -u | --url)
            shift
            url_status=$(curl -Is -l ${1} | head -n 1 | grep -i ok)
            log_info "Trying to reach ${1}"
            log_info "URL status: $url_status"
            if [ "$url_status" ]; then
                MINISHIFT_URL=${1}
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

log_info "Script parameters:"
log_info "MINISHIFT_PATH: $MINISHIFT_PATH"
log_info "MINISHIFT_URL: $MINISHIFT_URL"
log_info "HOME_FOLDER: $HOME_FOLDER"

if [ -z $MINISHIFT_PATH ]; then
    log_error "--p or --path cannot be empty"
    usage
fi

# Start script main part
if [ $EXISTING == 1 ]; then
    log_info "Checking existence of actual minishift instance..."
    # check for every "minishift" file in the given path
    MINISHIFT_BIN=$(find $MINISHIFT_PATH -type f -name "minishift" 2>&1 | grep -i minishift)
    # check whether there is multiple minishift files in the path
    check_minishift_bin $MINISHIFT_BIN
    # if there is an existing minishift binary, try to clean everything
    if [ -f $MINISHIFT_BIN ] && [ $MINISHIFT_BIN ]; then
        # try to stop and/or delete minishift 
        minishift_cleanup $MINISHIFT_BIN
        # remove the direcotry with minishift
        #rm -rf $MINISHIFT_PATH/minishift
    fi
else
# if there is no minishift file, there still could be running minishift vm
    # Download minishift, make it runnable and checks if there is running minishift vm
    # check that minishift url contains minishift binary file
    if [ -n "$MINISHIFT_URL" ]; then
        if [ -n "$(curl -Is -l "${MINISHIFT_URL}" | head -n 1 | grep -i ok)" ]; then
            log_info "Creating directory $MINISHIFT_PATH/minishift"
            mkdir -p $MINISHIFT_PATH/minishift
            log_info "Downloading minishift from $MINISHIFT_URL"
            log_info "to $MINISHIFT_PATH/minishift/"
            cd $MINISHIFT_PATH/minishift
            wget $MINISHIFT_URL
            if [ ! -f $MINISHIFT_PATH/minishift/minishift ]; then
                log_info "Content of $MINISHIFT_PATH/minishift/"
                log_info "$(ls $MINISHIFT_PATH/minishift/)"
                log_error "Minishift file was not downloaded from $MINISHIFT_URL, please, check the given url"
                rm -rf $MINISHIFT_PATH/minishift/
                exit 1
            fi
            chmod +x minishift
            MINISHIFT_BIN=$(realpath minishift)
            # stop/delete minishift
            minishift_cleanup $MINISHIFT_BIN
            rm -rf $MINISHIFT_PATH/minishift
        else
            log_error "Cannot download minishift from $MINISHIFT_URL"
            exit 1
        fi
    else
        log_error "No url was specified"
        exit 1
    fi
fi

# Clean up old minishift artifacts
if [ -d $HOME_FOLDER/.minishift ]; then
    log_info "Deleting $HOME_FOLDER/.minishift"
	rm -rf $HOME_FOLDER/.minishift
fi
if [ -d $HOME_FOLDER/.kube ]; then
	log_info "Deleting $HOME_FOLDER/.kube"
	rm -rf $HOME_FOLDER/.kube
fi
