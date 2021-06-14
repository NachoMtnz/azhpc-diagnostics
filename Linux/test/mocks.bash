#!/bin/bash
# mocks of 3rd party tools

declare -a MOCK_GPU_SBE_DBE_COUNTS
MOCK_GPU_SBE_DBE_COUNTS=( "0, 0" "0, 0" "0, 0" "0, 0" )

declare -a MOCK_GPU_PCI_DOMAINS
MOCK_GPU_PCI_DOMAINS=( 0x0001 0x0002 0x0003 0x0004 )

declare -a MOCK_GPU_PCI_SERIALS
MOCK_GPU_PCI_SERIALS=( 0000000000001 0000000000002 0000000000003 0000000000004 )

function nvidia-smi {
    if ! PARSED_OPTIONS=$(getopt -n "$0" -o i: --long 'query-gpu:,format:' -- "$@"); then
        echo "Invalid combination of input arguments. Please run 'nvidia-smi -h' for help."
        return 1
    fi
    eval set -- "$PARSED_OPTIONS"
    local query i format
    while [ "$1" != "--" ]; do
        case "$1" in
            --query-gpu)
                shift
                query="$1"
            ;;
            -i)
                shift
                i="$1"
            ;;
            --format)
                shift
                format="$1"
            ;;
        esac
        shift
    done
    if [ "$format" != "csv,noheader" ]; then
        echo '"--format=" switch is missing. Please run 'nvidia-smi -h' for help.'
        return 1
    fi
    local data
    declare -a data
    case "$query" in
        retired_pages.sbe,retired_pages.dbe) data=("${MOCK_GPU_SBE_DBE_COUNTS[@]}");;
        pci.domain) data=("${MOCK_GPU_PCI_DOMAINS[@]}");;
        serial) data=("${MOCK_GPU_PCI_SERIALS[@]}");;
        
        *) echo "Field \"$query\" is not a valid field to query."; return 1;;
    esac
    if [ -z "$i" ]; then
        for line in "${data[@]}"; do echo "$line"; done
    else
        echo "${data[$i]}"
    fi
    return 0
}

function journalctl {
    cat "$BATS_TEST_DIRNAME/samples/journald.log"
}

declare -a MOCK_PCI_DEVICES
MOCK_PCI_DEVICES=( "0001:00:00.0 NVIDIA" "0002:00:00.0 NVIDIA" "0003:00:00.0 NVIDIA" "0004:00:00.0 NVIDIA" "0005:00:00.0 MELLANOX" )
function lspci {
    if ! PARSED_OPTIONS=$(getopt -n "$0" -o d:mD -- "$@"); then
        return 1
    fi
    eval set -- "$PARSED_OPTIONS"
    local vendor # machine_readable show_domain
    while [ "$1" != "--" ]; do
        case "$1" in
            -d) shift; vendor="$1";;
            # -m) machine_readable=true;;
            # -D) show_domain=true;;
        esac
        shift
    done
    for device in "${MOCK_PCI_DEVICES[@]}"; do 
        if echo "$device" | grep -q NVIDIA || [ "$vendor" != 10de: ]; then
            echo "$device"
        fi
    done
}