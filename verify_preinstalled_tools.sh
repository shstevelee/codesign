#!/usr/bin/env bash

# Verification script to check if preinstalled OpenROAD, ScaleHLS, and StreamHLS are correctly identified
# This script checks the same conditions used in full_env_start_inside.sh

set -e

echo "=== Verifying Preinstalled Tool Identification ==="
echo

# Change to codesign directory if not already there
if [[ ! -f "full_env_start.sh" ]]; then
    echo "Error: Please run this script from the codesign root directory"
    exit 1
fi

# 1. Check OpenROAD
echo "1. Checking OpenROAD..."
OPENROAD_PATH="openroad_interface/OpenROAD/build/src/openroad"
if [[ -f "$OPENROAD_PATH" && -x "$OPENROAD_PATH" ]]; then
    echo "   ✅ OpenROAD executable found at: $OPENROAD_PATH"
    echo "   ✅ OpenROAD is executable"
    # Try to get version
    if "$OPENROAD_PATH" --version >/dev/null 2>&1; then
        echo "   ✅ OpenROAD responds to --version"
    else
        echo "   ⚠️  OpenROAD exists but may not be fully functional (--version failed)"
    fi
else
    echo "   ❌ OpenROAD executable NOT found at: $OPENROAD_PATH"
    if [[ -f "$OPENROAD_PATH" ]]; then
        echo "   ❌ File exists but is not executable"
    fi
fi
echo

# 2. Check ScaleHLS
echo "2. Checking ScaleHLS..."
SCALEHLS_DIR="ScaleHLS-HIDA/build/tools/scalehls/python_packages/scalehls_core"
if [[ -d "$SCALEHLS_DIR" ]]; then
    echo "   ✅ ScaleHLS directory found at: $SCALEHLS_DIR"
    # Check if it contains expected files
    if [[ -f "$SCALEHLS_DIR/__init__.py" ]]; then
        echo "   ✅ ScaleHLS __init__.py found"
    else
        echo "   ⚠️  ScaleHLS directory exists but __init__.py not found"
    fi
else
    echo "   ❌ ScaleHLS directory NOT found at: $SCALEHLS_DIR"
fi
echo

# 3. Check StreamHLS
echo "3. Checking StreamHLS..."
# First check if miniconda3 exists and source conda
if [[ -d "miniconda3" ]]; then
    export PATH="$(pwd):$PATH"
    source miniconda3/etc/profile.d/conda.sh 2>/dev/null || true

    if conda env list 2>/dev/null | grep -q "^streamhls "; then
        echo "   ✅ StreamHLS conda environment 'streamhls' found"
        # Try to activate and check if it works
        if conda activate streamhls 2>/dev/null; then
            echo "   ✅ StreamHLS environment can be activated"
            conda deactivate 2>/dev/null || true
        else
            echo "   ⚠️  StreamHLS environment exists but cannot be activated"
        fi
    else
        echo "   ❌ StreamHLS conda environment 'streamhls' NOT found"
    fi
else
    echo "   ❌ Miniconda3 directory not found - cannot check StreamHLS environment"
fi
echo

# 4. Summary
echo "=== Summary ==="
echo "Based on the checks above, the scripts would identify:"
echo

# OpenROAD check
if [[ -f "$OPENROAD_PATH" && -x "$OPENROAD_PATH" ]]; then
    echo "✅ OPENROAD_PRE_INSTALLED=1 would be honored"
else
    echo "❌ OPENROAD_PRE_INSTALLED=1 would NOT be honored (build would proceed)"
fi

# ScaleHLS check
if [[ -d "$SCALEHLS_DIR" ]]; then
    echo "✅ SCALEHLS_PRE_INSTALLED=1 would be honored"
else
    echo "❌ SCALEHLS_PRE_INSTALLED=1 would NOT be honored (setup would proceed)"
fi

# StreamHLS check
if [[ -d "miniconda3" ]] && conda env list 2>/dev/null | grep -q "^streamhls "; then
    echo "✅ STREAMHLS_PRE_INSTALLED=1 would be honored"
else
    echo "❌ STREAMHLS_PRE_INSTALLED=1 would NOT be honored (setup would proceed)"
fi

echo
echo "=== Verification Complete ==="