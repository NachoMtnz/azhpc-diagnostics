#!/bin/usr/env bats
# Tests for infiniband diagnostic collection

function setup {
    load "test_helper/bats-support/load"
    load "test_helper/bats-assert/load"
    load ../src/gather_azhpc_vm_diagnostics.sh --no-update

    DIAG_DIR=$(mktemp -d)
    mkdir -p "$DIAG_DIR"

    SYSFS_PATH=$(mktemp -d)
    
    local IB_DEVICES_PATH="$SYSFS_PATH/class/infiniband"
    mkdir -p "$IB_DEVICES_PATH/mlx4_0/ports/1/pkeys"
    echo 0xffff > "$IB_DEVICES_PATH/mlx4_0/ports/1/pkeys/0"
    echo 0x0001 > "$IB_DEVICES_PATH/mlx4_0/ports/1/pkeys/1"
    mkdir -p "$IB_DEVICES_PATH/mlx5_1/ports/1/pkeys"
    echo 0xffff > "$IB_DEVICES_PATH/mlx5_1/ports/1/pkeys/0"
    echo 0x0001 > "$IB_DEVICES_PATH/mlx5_1/ports/1/pkeys/1"
}

function teardown {
    rm -rf "$DIAG_DIR" "$SYSFS_PATH"
}

@test "Confirm that pkeys get collected" {
    run run_infiniband_diags
    assert_success

    run cat "$DIAG_DIR/Infiniband/mlx4_0/pkeys/0"
    assert_success
    assert_output 0xffff

    run cat "$DIAG_DIR/Infiniband/mlx4_0/pkeys/1"
    assert_success
    assert_output 0x0001
}

@test "Confirm that ib tools get run" {
    . "$BATS_TEST_DIRNAME/mocks.bash"

    run run_infiniband_diags
    assert_success

    run cat "$DIAG_DIR/Infiniband/ibstat.txt"
    assert_success
    assert_output

    run cat "$DIAG_DIR/Infiniband/ibv_devinfo.txt"
    assert_success
    assert_output "full output"
}

@test "Confirm that lack of ibstat is noticed" {
    . "$BATS_TEST_DIRNAME/mocks.bash"

    hide_command ibstat

    run run_infiniband_diags
    assert_success

    assert_output --partial "No Infiniband Driver Detected"

    refute [ -f "$DIAG_DIR/Infiniband/ibstat.txt" ]
    refute [ -f "$DIAG_DIR/Infiniband/ibv_devinfo.txt" ]
}

@test "Confirm that ib-vmext-status gets collected" {
    local dir_exists
    if [ -d /var/log/azure ]; then
        dir_exists=true
    else
        dir_exists=false
        mkdir -p /var/log/azure
    fi
    local file_exists
    if [ -f /var/log/azure/ib-vmext-status ]; then
        file_exists=true
    else
        file_exists=false
        touch /var/log/azure/ib-vmext-status
    fi

    run run_infiniband_diags
    assert_success

    assert [ -f "$DIAG_DIR/Infiniband/ib-vmext-status" ]

    if [ "$file_exists" == false ]; then
        rm /var/log/azure/ib-vmext-status
    fi
    if [ "$dir_exists" == false ]; then
        rm -r /var/log/azure
    fi
}

@test "Confirm that lack of pkeys is noticed" {
    . "$BATS_TEST_DIRNAME/mocks.bash"
    run_infiniband_diags

    run check_pkeys
    refute_output

    rm "$DIAG_DIR/Infiniband/mlx4_0/pkeys/0"
    run check_pkeys
    assert_output --partial "Could not find pkey 0 for device mlx4_0"
    refute_output --partial "Could not find pkey 1 for device mlx4_0"
    refute_output --partial "Could not find pkey 0 for device mlx5_1"
    refute_output --partial "Could not find pkey 1 for device mlx5_1"

    rm "$DIAG_DIR/Infiniband/mlx5_1/pkeys/1"
    run check_pkeys
    assert_output --partial "Could not find pkey 0 for device mlx4_0"
    refute_output --partial "Could not find pkey 1 for device mlx4_0"
    refute_output --partial "Could not find pkey 0 for device mlx5_1"
    assert_output --partial "Could not find pkey 1 for device mlx5_1"
}