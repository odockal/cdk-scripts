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
    echo "Script that checks whether host, where script is run, supports virtualization"
    echo "Usage $0"
    echo "          writes out result and if virtualization is not supported, returns exit code 1"
    exit 1
}

VIRTUALIZATION_ENABLED="False"

while [ $# -gt 0 ]; do
    case $1 in
        *)
            usage
            ;;
    esac
done

if [ "$(get_os_platform)" == "win" ]; then
	# check if Win32_Processor.VirtualizationFirmwareEnabled property exists
	log_info "Checking if Win32_Processor.VirtualizationFirmwareEnabled property exists... "
    EXISTS="$(powershell.exe "@(gwmi -Class Win32_Processor)[0].psobject.properties.name -contains 'VirtualizationFirmwareEnabled'" | tr -d '\r\n')"
    log_info "Is Virtualization on: $EXISTS"
	if [ "$EXISTS" == "True" ]; then
    	VIRTUALIZATION_ENABLED="$(powershell.exe "@(gwmi -Class Win32_Processor)[0] | Select -ExpandProperty VirtualizationFirmwareEnabled" | tr -d '\r\n')"
	fi
else 
	if [[ "$(lscpu | grep Virtualization:)" == *VT-x* ]]; then
    VIRTUALIZATION_ENABLED="True"
    fi
fi

if [ "$VIRTUALIZATION_ENABLED" == "False" ]; then
	log_error "Virtualization is not enabled on this host, forcing build to fail..."
    exit 1
else
	log_info "Virtualization is enabled on this host..."
fi

log_info "Script $__base is finished sucessfully..."
