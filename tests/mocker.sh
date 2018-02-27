# Mocker provides different outputs representating minishift/cdk binary reports base

if [ "${2}" == "status" ]; then
    echo "${1}"
fi

if [ "${2}" == "version" ]; then
    echo "${1}"
fi

if [ "${2}" == "profile list" ]; then
    echo ${1}
fi
