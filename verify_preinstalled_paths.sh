#!/usr/bin/env bash

# Verification script to check if the preinstalled tool paths used in automated-scripts.sh
# are correctly pointing to functional executables

set -e

echo "=== Verifying Preinstalled Tool Paths ==="
echo

# Change to codesign directory if not already there
if [[ ! -f "full_env_start.sh" ]]; then
    echo "Error: Please run this script from the codesign root directory"
    exit 1
fi

# 1. Check OpenROAD preinstalled path (from automated-scripts.sh)
echo "1. Checking OpenROAD preinstalled path..."
PREINSTALLED_OPENROAD_PATH="/scratch/seunghyeok/codesign/openroad_interface/OpenROAD/build/src/openroad"
echo "   Expected path: $PREINSTALLED_OPENROAD_PATH"

if [[ -f "$PREINSTALLED_OPENROAD_PATH" && -x "$PREINSTALLED_OPENROAD_PATH" ]]; then
    echo "   ✅ File exists and is executable"
    # Try to get version
    if "$PREINSTALLED_OPENROAD_PATH" --version >/dev/null 2>&1; then
        echo "   ✅ OpenROAD responds to --version"
    else
        echo "   ⚠️  OpenROAD exists but may not be fully functional (--version failed)"
    fi
else
    echo "   ❌ File does NOT exist or is not executable"
    if [[ ! -f "$PREINSTALLED_OPENROAD_PATH" ]]; then
        echo "   ❌ File not found"
    else
        echo "   ❌ File exists but is not executable"
    fi
fi
echo

# 2. Check ScaleHLS preinstalled path (from automated-scripts.sh)
echo "2. Checking ScaleHLS preinstalled path..."
PREINSTALLED_SCALEHLS_PATH="/scratch/seunghyeok/codesign/ScaleHLS-HIDA"
echo "   Expected path: $PREINSTALLED_SCALEHLS_PATH"

if [[ -d "$PREINSTALLED_SCALEHLS_PATH" ]]; then
    echo "   ✅ ScaleHLS directory exists"
    # Check for key files
    if [[ -f "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-opt" && -x "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-opt" ]]; then
        echo "   ✅ scalehls-opt found and executable"
    else
        echo "   ❌ scalehls-opt not found or not executable"
    fi
    if [[ -f "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-translate" && -x "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-translate" ]]; then
        echo "   ✅ scalehls-translate found and executable"
    else
        echo "   ❌ scalehls-translate not found or not executable"
    fi
    if [[ -f "$PREINSTALLED_SCALEHLS_PATH/scalehls_env.sh" ]]; then
        echo "   ✅ scalehls_env.sh found"
    else
        echo "   ❌ scalehls_env.sh not found"
    fi
else
    echo "   ❌ ScaleHLS directory does NOT exist"
fi
echo

# 3. Check StreamHLS preinstalled path (from automated-scripts.sh)
echo "3. Checking StreamHLS preinstalled path..."
PREINSTALLED_STREAMHLS_PATH="/scratch/seunghyeok/codesign/miniconda3/envs/streamhls"
echo "   Expected path: $PREINSTALLED_STREAMHLS_PATH"

if [[ -d "$PREINSTALLED_STREAMHLS_PATH" ]]; then
    echo "   ✅ StreamHLS conda environment directory exists"
    # Check for key files
    if [[ -f "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-opt" && -x "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-opt" ]]; then
        echo "   ✅ streamhls-opt found and executable"
    else
        echo "   ❌ streamhls-opt not found or not executable"
    fi
    if [[ -f "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-translate" && -x "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-translate" ]]; then
        echo "   ✅ streamhls-translate found and executable"
    else
        echo "   ❌ streamhls-translate not found or not executable"
    fi
else
    echo "   ❌ StreamHLS conda environment directory does NOT exist"
fi
echo

# 4. Summary
echo "=== Summary ==="
echo "Preinstalled path verification results:"
echo

# OpenROAD check
if [[ -f "$PREINSTALLED_OPENROAD_PATH" && -x "$PREINSTALLED_OPENROAD_PATH" ]]; then
    echo "✅ OpenROAD: Preinstalled path is valid and functional"
else
    echo "❌ OpenROAD: Preinstalled path is INVALID or non-functional"
fi

# ScaleHLS check
if [[ -d "$PREINSTALLED_SCALEHLS_PATH" ]]; then
    SCALEHLS_VALID=true
    if [[ ! -f "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-opt" || ! -x "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-opt" ]]; then
        SCALEHLS_VALID=false
    fi
    if [[ ! -f "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-translate" || ! -x "$PREINSTALLED_SCALEHLS_PATH/build/bin/scalehls-translate" ]]; then
        SCALEHLS_VALID=false
    fi
    if [[ ! -f "$PREINSTALLED_SCALEHLS_PATH/scalehls_env.sh" ]]; then
        SCALEHLS_VALID=false
    fi
    
    if [[ "$SCALEHLS_VALID" == "true" ]]; then
        echo "✅ ScaleHLS: Preinstalled path is valid and functional"
    else
        echo "❌ ScaleHLS: Preinstalled path exists but is missing required components"
    fi
else
    echo "❌ ScaleHLS: Preinstalled path does NOT exist"
fi

# StreamHLS check
if [[ -d "$PREINSTALLED_STREAMHLS_PATH" ]]; then
    STREAMHLS_VALID=true
    if [[ ! -f "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-opt" || ! -x "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-opt" ]]; then
        STREAMHLS_VALID=false
    fi
    if [[ ! -f "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-translate" || ! -x "$PREINSTALLED_STREAMHLS_PATH/bin/streamhls-translate" ]]; then
        STREAMHLS_VALID=false
    fi
    
    if [[ "$STREAMHLS_VALID" == "true" ]]; then
        echo "✅ StreamHLS: Preinstalled path is valid and functional"
    else
        echo "❌ StreamHLS: Preinstalled path exists but is missing required components"
    fi
else
    echo "❌ StreamHLS: Preinstalled path does NOT exist"
fi

echo
echo "=== Verification Complete ==="
echo "If any tools show ❌, the automated scripts may fail when using preinstalled flags."