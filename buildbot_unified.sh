#!/bin/bash
echo ""
echo "LineageOS 23.2 TrebleDroid Unified Buildbot"
echo "Executing in 5 seconds - CTRL-C to exit"
echo ""
sleep 5

if [ $# -lt 2 ]
then
    echo "Not enough arguments - exiting"
    echo ""
    exit 1
fi

MODE=${1}
if [ ${MODE} != "device" ] && [ ${MODE} != "treble" ]
then
    echo "Invalid mode - exiting"
    echo ""
    exit 1
fi

NOSYNC=false
PERSONAL=false
SIGNABLE=true
for var in "${@:2}"
do
    if [ ${var} == "nosync" ]
    then
        NOSYNC=true
    fi
    if [ ${var} == "personal" ]
    then
        PERSONAL=true
        SIGNABLE=false
    fi
done
if [ ! -d "$HOME/.android-certs" ]; then
    echo "$HOME/.android-certs not found - output will not be signed"
    echo ""
    SIGNABLE=false
fi

# Abort early on error
set -eE
trap '(\
echo;\
echo \!\!\! An error happened during script execution;\
echo \!\!\! Please check console output for bad sync,;\
echo \!\!\! failed patch application, etc.;\
echo\
)' ERR

START=`date +%s`
BUILD_DATE="$(date -u +%Y%m%d)"
LINEAGE_VERSION="23.2"

prep_build() {
    for repo in lineage_build_unified lineage_patches_unified; do
        if [ "$(git -C "${repo}" branch --show-current)" != "lineage-23-td" ]; then
            echo "${repo} must be checked out on lineage-23-td" >&2
            exit 1
        fi
    done

    echo "Preparing local manifests"
    mkdir -p .repo/local_manifests
    cp ./lineage_build_unified/local_manifests_${MODE}/*.xml .repo/local_manifests
    echo ""

    echo "Syncing repos"
    repo sync -c --force-sync --no-clone-bundle --no-tags --optimized-fetch --retry-fetches=5 -j8
    echo ""

    echo "Setting up build environment"
    source build/envsetup.sh &> /dev/null
    source vendor/lineage/vars/aosp_target_release
    mkdir -p ~/build-output
    echo ""

    : repopick 321337 -r -f # Deprioritize important developer notifications
    : repopick 321338 -r -f # Allow disabling important developer notifications
    : repopick 321339 -r -f # Allow disabling USB notifications
    : repopick 368923 -r -f # Launcher3: Show clear all button in recents overview
}

apply_patches() {
    local patch_dir="./lineage_patches_unified/${1}"
    if [ ! -d "${patch_dir}" ]; then
        echo "Patch group ${1} is absent - skipping"
        return
    fi
    echo "Applying patch group ${1}"
    bash ./lineage_build_unified/apply_patches.sh "${patch_dir}"
}

prep_device() {
    :
}

prep_treble() {
    apply_patches patches_treble_prerequisite
    apply_patches patches_treble_td
}

finalize_device() {
    :
}

finalize_treble() {
    cd device/phh/treble
    git clean -fdx
    bash generate.sh lineage
    cd ../../..
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    cd vendor/hardware_overlay
    git add TrebleApp/app.apk
    git commit -m "[TEMP] Up TrebleApp to $BUILD_DATE"
    cd ../..
}

build_device() {
    brunch ${1}
    mv $OUT/lineage-*.zip ~/build-output/lineage-$LINEAGE_VERSION-$BUILD_DATE-UNOFFICIAL-${1}$($PERSONAL && echo "-personal" || echo "").zip
}

validate_treble_identity() {
    local system_prop="$OUT/system/build.prop"
    local product_prop="$OUT/system/product/etc/build.prop"
    local system_ext_prop="$OUT/system/system_ext/etc/build.prop"
    local expected

    for expected in \
        "$system_prop:ro.product.system.brand=FancyDay" \
        "$system_prop:ro.product.system.manufacturer=FancyDay" \
        "$system_prop:ro.product.system.device=C10" \
        "$system_prop:ro.product.system.name=C10US" \
        "$system_prop:ro.product.system.model=C10" \
        "$system_prop:ro.build.fingerprint=FancyDay/C10US/C10:14/UP1A.231105.001.A1/20240316:user/release-keys" \
        "$system_prop:ro.system.build.fingerprint=FancyDay/C10US/C10:14/UP1A.231105.001.A1/20240316:user/release-keys" \
        "$system_prop:ro.build.description=a523_y83_arm64-user 14 UP1A.231105.001.A1 20240316 release-keys" \
        "$system_prop:ro.build.display.id=863C_C10_20240619" \
        "$system_prop:service.adb.root=1" \
        "$system_prop:ro.lmk.use_new_strategy=true" \
        "$system_prop:ro.lmk.use_psi=true" \
        "$product_prop:ro.product.product.brand=FancyDay" \
        "$product_prop:ro.product.product.manufacturer=FancyDay" \
        "$product_prop:ro.product.product.device=C10" \
        "$product_prop:ro.product.product.name=C10US" \
        "$product_prop:ro.product.product.model=C10" \
        "$product_prop:ro.build.display.id=863C_C10_20240619" \
        "$product_prop:ro.build.characteristics=tablet" \
        "$system_ext_prop:ro.product.system_ext.brand=FancyDay" \
        "$system_ext_prop:ro.product.system_ext.manufacturer=FancyDay" \
        "$system_ext_prop:ro.product.system_ext.device=C10" \
        "$system_ext_prop:ro.product.system_ext.name=C10US" \
        "$system_ext_prop:ro.product.system_ext.model=C10"
    do
        local file="${expected%%:*}"
        local property="${expected#*:}"
        if ! grep -Fxq "$property" "$file"; then
            echo "Identity validation failed: $property not found in $file" >&2
            exit 1
        fi
    done
}

build_treble() {
    case "${1}" in
        ("A64VN") TARGET=a64_bvN;;
        ("A64VS") TARGET=a64_bvS;;
        ("A64GN") TARGET=a64_bgN;;
        ("64VN") TARGET=arm64_bvN;;
        ("64VS") TARGET=arm64_bvS;;
        ("64GN") TARGET=arm64_bgN;;
        (*) echo "Invalid target - exiting"; exit 1;;
    esac
    lunch lineage_${TARGET}-${aosp_target_release}-userdebug
    make installclean
    WITH_ADB_INSECURE=true make -j$(lscpu -b -p=Core,Socket | grep -v '^#' | sort -u | wc -l) systemimage
    validate_treble_identity
    SIGNED=false
    if [ ${SIGNABLE} = true ] && [[ ${TARGET} == *_bg? ]]
    then
        WITH_ADB_INSECURE=true make -j$(lscpu -b -p=Core,Socket | grep -v '^#' | sort -u | wc -l) target-files-package otatools
        bash ./lineage_build_unified/sign_target_files.sh $OUT/signed-target_files.zip
        unzip -joq $OUT/signed-target_files.zip IMAGES/system.img -d $OUT
        SIGNED=true
        echo ""
    fi
    mv $OUT/system.img ~/build-output/lineage-$LINEAGE_VERSION-$BUILD_DATE-UNOFFICIAL-${TARGET}$(${PERSONAL} && echo "-personal" || echo "")$(${SIGNED} && echo "-signed" || echo "").img
    #make vndk-test-sepolicy
}

if ${NOSYNC}
then
    echo "ATTENTION: syncing/patching skipped!"
    echo ""
    echo "Setting up build environment"
    source build/envsetup.sh &> /dev/null
    source vendor/lineage/vars/aosp_target_release
    echo ""
else
    prep_build
    echo "Applying patches"
    prep_${MODE}
    apply_patches patches_platform
    apply_patches patches_${MODE}
    if ${PERSONAL}
    then
        apply_patches patches_platform_personal
        apply_patches patches_${MODE}_personal
    fi
    finalize_${MODE}
    echo ""
fi


for var in "${@:2}"
do
    if [ ${var} == "nosync" ] || [ ${var} == "personal" ]
    then
        continue
    fi
    echo "Starting $(${PERSONAL} && echo "personal " || echo "")build for ${MODE} ${var}"
    build_${MODE} ${var}
done
ls ~/build-output | grep 'lineage' || true

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))
echo "Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo ""
