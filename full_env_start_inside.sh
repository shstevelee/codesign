#!/bin/bash

################## CHECK BUILD LOG / FORCE FULL ##################

SETUP_SCRIPTS_FOLDER="$(pwd)/setup_scripts"
BUILD_LOG="$SETUP_SCRIPTS_FOLDER/build.log"
FORCE_FULL=0
SKIP_OPENROAD=0
USE_MAX_PARALLEL=0
MAX_PARALLEL_CORES=24

# Start timer
start_time=$(date +%s)

record_full_build_metadata() {
    local build_time root_commit
    build_time=$(date "+%Y-%m-%d %H:%M:%S")
    root_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    {
        echo "build_time: $build_time"
        echo "root_commit: $root_commit"
        echo "submodules:"

        if git config --file .gitmodules --get-regexp 'submodule\..*\.path' >/dev/null 2>&1; then
            git submodule foreach --recursive --quiet '
                sub_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
                printf "  - %s: %s\n" "$path" "$sub_commit"
            '
        else
            echo "  - none"
        fi
    } > "$BUILD_LOG"
}

# Parse command line options
for arg in "$@"; do
    case "$arg" in
        --full) FORCE_FULL=1 ;;
        --skip-openroad) SKIP_OPENROAD=1 ;;
        --max_parallel_install) USE_MAX_PARALLEL=1 ;;
    esac
done

if [[ $FORCE_FULL -eq 0 ]]; then
    if [[ ! -f "$BUILD_LOG" ]]; then
        echo "No build log found — forcing full build."
        FORCE_FULL=1
    else
        last_epoch=$(date -r "$BUILD_LOG" +%s)
        now_epoch=$(date +%s)
        diff_days=$(( (now_epoch - last_epoch) / 86400 ))
    fi
fi

echo ">>> Performing $( [[ $FORCE_FULL -eq 1 ]] && echo "FULL" || echo "incremental" ) build"

# Core calculation
TOTAL_CORES=$(nproc 2>/dev/null || echo 1)
TARGET_CORES=$(( USE_MAX_PARALLEL == 1 ? TOTAL_CORES : TOTAL_CORES / 2 ))
[[ $TARGET_CORES -lt 1 ]] && TARGET_CORES=1
[[ $TARGET_CORES -gt $MAX_PARALLEL_CORES ]] && TARGET_CORES=$MAX_PARALLEL_CORES

################## AMPL UUID LICENSE PROMPT ##################

AMPL_UUID_FILE="$(pwd)/ampl_uuid.txt"
if [[ $FORCE_FULL -eq 1 ]]; then
    echo "Using $TARGET_CORES cores for this build."
    if [ -z "$AMPL_UUID" ]; then
        echo -n "Please enter your AMPL UUID license: "
        read -r ampl_uuid
    else
        ampl_uuid="$AMPL_UUID"
    fi
    echo "$ampl_uuid" > "$AMPL_UUID_FILE"
    echo "AMPL UUID saved to: $AMPL_UUID_FILE"
fi

################## OPENROAD DETECTION LOGIC ##################

detect_openroad() {
    # Priority: User Env Var -> Local Build Path -> System PATH
    if [[ -n "${PREINSTALLED_OPENROAD_PATH:-}" && -x "$PREINSTALLED_OPENROAD_PATH" ]]; then
        echo "$PREINSTALLED_OPENROAD_PATH"
    elif [[ -x "openroad_interface/OpenROAD/build/src/openroad" ]]; then
        echo "$(pwd)/openroad_interface/OpenROAD/build/src/openroad"
    else
        command -v openroad 2>/dev/null
    fi
}

FOUND_OR_PATH=$(detect_openroad)

################## SCALEHLS DETECTION LOGIC ##################
detect_scalehls() {
    if [[ -n "${PREINSTALLED_SCALEHLS_PATH:-}" ]]; then
        if [[ -d "$PREINSTALLED_SCALEHLS_PATH" && -f "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-opt" && -x "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-opt" && -f "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-translate" && -x "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-translate" && -f "$PREINSTALLED_SCALEHLS_PATH/scalehls_env.sh" ]]; then
            echo "$PREINSTALLED_SCALEHLS_PATH"
        fi
    fi
}

################# STREAMHLS DETECTION LOGIC #################

detect_streamhls() {
    if [[ -n "${PREINSTALLED_STREAMHLS_PATH:-}" ]]; then
        if [[ -d "$PREINSTALLED_STREAMHLS_PATH" ]]; then
            if [[ -f "$PREINSTALLED_STREAMHLS_PATH/build/bin/streamhls-opt" && -x "$PREINSTALLED_STREAMHLS_PATH/build/bin/streamhls-opt" && -f "$PREINSTALLED_STREAMHLS_PATH/build/bin/streamhls-translate" && -x "$PREINSTALLED_STREAMHLS_PATH/build/bin/streamhls-translate" ]]; then
                echo "$PREINSTALLED_STREAMHLS_PATH"
            elif [[ -f "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-opt" && -x "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-opt" && -f "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-translate" && -x "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-translate" ]]; then
                echo "$PREINSTALLED_STREAMHLS_PATH"
            fi
        fi
    fi
}

FOUND_SCALEHLS_PATH=$(detect_scalehls)
FOUND_STREAMHLS_PATH=$(detect_streamhls)


SUDO_KEEPALIVE_PID=""
stop_sudo_keepalive() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
        kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
}

start_sudo_keepalive() {
    local keepalive_seconds=28800
    (
        started_at=$(date +%s)
        while true; do
            sleep 60
            sudo -n -v >/dev/null 2>&1 || exit 0
            current_epoch=$(date +%s)
            (( current_epoch - started_at >= keepalive_seconds )) && exit 0
        done
    ) &
    SUDO_KEEPALIVE_PID=$!
    trap stop_sudo_keepalive EXIT
}

if [[ $SKIP_OPENROAD -eq 1 ]] || [[ -n "$FOUND_OR_PATH" ]]; then
    echo "Using OpenROAD at: ${FOUND_OR_PATH:-'Skipped'}. SUDO may not be required."
else
    echo "SUDO permissions may be required for OpenROAD installation. Enter password if prompted."
    sudo -v
    start_sudo_keepalive
    echo "SUDO permissions will be refreshed for up to 8 hours."
fi

################## UNIVERSITY & ENVIRONMENT SETUP ##################

host=$(hostname)
if [[ "$host" == *stanford* ]]; then
    export UNIVERSITY="stanford"
elif [[ "$host" == *cmu* ]]; then
    export UNIVERSITY="cmu"
else
    echo "Hostname '$host' unrecognized."
    read -p "Please pick your university (stanford/cmu): " choice
    case "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" in
        stanford) export UNIVERSITY="stanford" ;;
        cmu) export UNIVERSITY="cmu" ;;
        *) echo "Invalid choice. Exiting."; exit 1 ;;
    esac
fi

echo "$UNIVERSITY" > "$SETUP_SCRIPTS_FOLDER/university_name.txt"
printf '>>> SCRIPT START %s\n' "$(date)"

export OLD_HOME="$HOME"
export HOME="$(pwd)"
export PATH="$HOME/.local/bin:$PATH"
export CMAKE_PREFIX_PATH="$HOME/.local"

if [ "$UNIVERSITY" = "cmu" ]; then
    export TMPDIR="$HOME/.tmp"
    export TEMP="$TMPDIR"
    export TEMPDIR="$TMPDIR"
    export TMP="$TMPDIR"
    export PYTHONPYCACHEPREFIX="$TMPDIR/__pycache__"
    export CONDA_PKGS_DIRS="$TMPDIR/conda_pkgs"
    export PIP_CACHE_DIR="$TMPDIR/pip_cache"
    mkdir -p "$TMPDIR"
    echo "Set CMU-specific TMPDIR to $TMPDIR"
fi

git config --global fetch.parallel "$TARGET_CORES"
git config --global submodule.fetchJobs "$TARGET_CORES"

################## STEP 1: OPENROAD ##################
echo "STARTING STEP 1: OPENROAD INSTALLATION"
if [[ $SKIP_OPENROAD -eq 1 ]]; then
    echo "Skipping OpenROAD installation."
elif [[ -n "$FOUND_OR_PATH" ]]; then
    echo "OpenROAD already available at $FOUND_OR_PATH"
else
    git submodule update --init --recursive openroad_interface/OpenROAD
    
    if [ -f /etc/redhat-release ]; then
        OS_VERSION=$(cat /etc/redhat-release)
        case "$OS_VERSION" in 
            *"release 8"*)
                bash "$SETUP_SCRIPTS_FOLDER/openroad_install_rhel8.sh"
                ;;
            *"release 9"*)
                bash "$SETUP_SCRIPTS_FOLDER/openroad_install.sh"
                ;;
            *)
                echo "Unsupported OS version: $OS_VERSION"; exit 1
                ;;
        esac    
    else
        echo "Unsupported OS (RedHat/Rocky required for auto-install)"; exit 1
    fi

    if [ ! -f "openroad_interface/OpenROAD/build/src/openroad" ]; then
        echo "OpenROAD installation failed."; exit 1
    fi
fi
echo "COMPLETED STEP 1: OPENROAD INSTALLATION"

################ SET UP SCALEHLS ##################
echo "STARTING STEP 2: SCALEHLS SETUP"
if [[ -n "$FOUND_SCALEHLS_PATH" ]] || [[ "${SCALEHLS_PRE_INSTALLED:-0}" == "1" && -d "ScaleHLS-HIDA/build/tools/scalehls/python_packages/scalehls_core" ]]; then
    echo "Skipping ScaleHLS setup (preinstalled at ${FOUND_SCALEHLS_PATH:-'local'})."
else
    source "$SETUP_SCRIPTS_FOLDER/scale_hls_setup.sh" "$FORCE_FULL"
fi
echo "COMPLETED STEP 2: SCALEHLS SETUP"

################### SET UP CONDA ENVIRONMENT ##################
echo "STARTING STEP 3: CONDA ENVIRONMENT SETUP"
if [ -d "miniconda3" ]; then
    source miniconda3/etc/profile.d/conda.sh
else   
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda_install.sh
    bash miniconda_install.sh -b -p "$(pwd)/miniconda3"
    source miniconda3/etc/profile.d/conda.sh
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
    conda env create -f "$SETUP_SCRIPTS_FOLDER/environment_simplified.yml" -y
    
    # Symlinks for g++-13
    (cd miniconda3/envs/codesign/bin && ln -sf x86_64-conda-linux-gnu-gcc gcc-13 && ln -sf x86_64-conda-linux-gnu-g++ g++-13)
fi

if [[ $FORCE_FULL -eq 1 ]]; then
    conda update -n base -c defaults conda -y
    conda env update -f "$SETUP_SCRIPTS_FOLDER/environment_simplified.yml" --prune -y
fi
conda activate codesign

################ SET UP STREAMHLS ##################
echo "STARTING STEP 4: STREAMHLS SETUP"
if [[ -n "$FOUND_STREAMHLS_PATH" ]] || { [[ "${STREAMHLS_PRE_INSTALLED:-0}" == "1" ]] && conda env list | grep -q streamhls; }; then
    echo "Skipping StreamHLS setup (preinstalled at ${FOUND_STREAMHLS_PATH:-'local'})."
else
    bash "$SETUP_SCRIPTS_FOLDER/streamhls_setup.sh" "$FORCE_FULL"
    UUID=$(cat ampl_uuid.txt)
    (
        cd Stream-HLS/ampl.linux-intel64
        ./ampl <<EOF
shell "amplkey activate --uuid $UUID";
exit;
EOF
    )
    echo "AMPL license activated."
fi
echo "COMPLETED STEP 4: STREAMHLS SETUP"

################ STEP 5-7: SUBMODULES & BUILDS ##################
echo "STARTING STEP 5: SUBMODULE UPDATE"
[[ $FORCE_FULL -eq 1 ]] && git submodule update --init --recursive

echo "STARTING STEP 6: CACTI BUILD"
(cd src/cacti && make -j"$TARGET_CORES")

echo "STARTING STEP 7: VERILATOR BUILD"
source "$SETUP_SCRIPTS_FOLDER/verilator_install.sh"

############### STEP 8: HANDLE XAUTHORITY #################
echo "STARTING STEP 8: XAUTHORITY HANDLING"
if [ "$HOME" != "$OLD_HOME" ]; then
    [ -f .Xauthority ] && rm .Xauthority
    if [ -f "$OLD_HOME/.Xauthority" ]; then
        cp "$OLD_HOME/.Xauthority" .Xauthority
        echo "Xauthority synchronized."
    fi
fi

############### STEP 9: Add useful aliases ###############
echo "STARTING STEP 9: ALIASES"
alias create_checkpoint="python3 -m test.checkpoint_controller"
alias run_codesign="python3 -m src.codesign"
alias run_tech_test="python3 -m test.experiments.dennard_multi_core"
alias clean_checkpoints="rm -rf ~/test/saved_checkpoints/*"
alias clean_logs="rm -rf ~/logs/*"
alias clean_tmp="rm -rf ~/src/tmp/*"
alias clean_codesign="clean_checkpoints; clean_logs; clean_tmp"
alias run_regression="python3 -m test.regression_run"
alias run_sweep="python3 -m src.hardware_model.tech_models.tech_library.sweep_tech_codesign"

################## FINALIZE ##################
[[ $FORCE_FULL -eq 1 ]] && record_full_build_metadata
[ -f "$BUILD_LOG" ] && cat "$BUILD_LOG"

duration=$(( $(date +%s) - start_time ))
printf "\nBUILD SUCCESSFUL. Elapsed time: %d minutes and %d seconds\n" $((duration / 60)) $((duration % 60))

if [[ $FORCE_FULL -eq 1 ]]; then
    export BUILD_START_TIME=$start_time
    source "$(pwd)/run_end_of_build_tests.sh"
fi