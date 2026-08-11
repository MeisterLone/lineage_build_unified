#!/bin/bash
set -euo pipefail

OUTFILE="${1:-signed-target_files.zip}"

APEX_APKS=(
    com.android.appsearch.apk
    AdServicesApk
    FederatedCompute
    HalfSheetUX
    HealthConnectBackupRestore
    HealthConnectController
    OsuLogin
    SafetyCenterResources
    ServiceConnectivityResources
    ServiceUwbResources
    ServiceWifiResources
    TelecomServiceResources
    TelecomUi
    WebAppService
    WifiDialog
)

APEXES=(
    com.android.adbd
    com.android.adservices
    com.android.adservices.api
    com.android.appsearch
    com.android.art
    com.android.bluetooth
    com.android.bt
    com.android.btservices
    com.android.cellbroadcast
    com.android.compos
    com.android.configinfrastructure
    com.android.connectivity.resources
    com.android.conscrypt
    com.android.crashrecovery
    com.android.devicelock
    com.android.extservices
    com.android.graphics.pdf
    com.android.hardware.authsecret
    com.android.hardware.biometrics.face.virtual
    com.android.hardware.biometrics.fingerprint.virtual
    com.android.hardware.boot
    com.android.hardware.cas
    com.android.hardware.contexthub
    com.android.hardware.dumpstate
    com.android.hardware.gatekeeper.nonsecure
    com.android.hardware.neuralnetworks
    com.android.hardware.power
    com.android.hardware.rebootescrow
    com.android.hardware.thermal
    com.android.hardware.threadnetwork
    com.android.hardware.uwb
    com.android.hardware.vibrator
    com.android.hardware.wifi
    com.android.healthfitness
    com.android.hotspot2.osulogin
    com.android.i18n
    com.android.ipsec
    com.android.media
    com.android.media.swcodec
    com.android.mediaprovider
    com.android.nearby.halfsheet
    com.android.networkstack.tethering
    com.android.neuralnetworks
    com.android.nfcservices
    com.android.npumanager
    com.android.ondevicepersonalization
    com.android.os.statsd
    com.android.permission
    com.android.profiling
    com.android.resolv
    com.android.rkpd
    com.android.runtime
    com.android.safetycenter.resources
    com.android.scheduling
    com.android.sdkext
    com.android.support.apexer
    com.android.telephony
    com.android.telephonycore
    com.android.telephonymodules
    com.android.tethering
    com.android.tzdata
    com.android.uprobestats
    com.android.uwb
    com.android.uwb.resources
    com.android.virt
    com.android.vndk.current
    com.android.vndk.current.on_vendor
    com.android.webapp
    com.android.wifi
    com.android.wifi.dialog
    com.android.wifi.resources
    com.google.pixel.camera.hal
    com.google.pixel.vibrator.hal
    com.qorvo.uwb
)

shopt -s nullglob
TARGET_FILES=("$OUT"/obj/PACKAGING/target_files_intermediates/*-target_files*.zip)
if [ "${#TARGET_FILES[@]}" -ne 1 ]; then
    echo "Expected exactly one input target-files archive, found ${#TARGET_FILES[@]}" >&2
    printf '%s\n' "${TARGET_FILES[@]}" >&2
    exit 1
fi

SIGN_ARGS=(-o -d "$HOME/.android-certs" --allow_gsi_debug_sepolicy)
for apk in "${APEX_APKS[@]}"; do
    SIGN_ARGS+=(--extra_apks "$apk.apk=$HOME/.android-certs/releasekey")
done
for apex in "${APEXES[@]}"; do
    for suffix in pk8 x509.pem pem; do
        if [ ! -f "$HOME/.android-certs/$apex.$suffix" ]; then
            echo "Missing signing key: $HOME/.android-certs/$apex.$suffix" >&2
            exit 1
        fi
    done
    SIGN_ARGS+=(--extra_apks "$apex.apex=$HOME/.android-certs/$apex")
    SIGN_ARGS+=(--extra_apex_payload_key "$apex.apex=$HOME/.android-certs/$apex.pem")
done

sign_target_files_apks "${SIGN_ARGS[@]}" "${TARGET_FILES[0]}" "$OUTFILE"
