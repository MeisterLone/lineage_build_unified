# LineageOS 23 TrebleDroid patch-port findings

## Verdict

**GO for A16 patch-tree integration and a first controlled build.**

All 306 manifest rows reached an Opus terminal verdict at confidence >= 90. The retained chain contains 265 patches; 41 rows are verified omissions. Every normalized repository chain was reconstructed with ordered `git apply --check` and `git am` on a fresh baseline worktree. No full ROM build, `systemimage`, device operation, or flash was performed.

The promoted trees are:

- Local: `port-los23-td/patches-l23/`
- Build server: `/root/port-los23-td/patches-l23/`
- Patch count: 265
- Aggregate over sorted `SHA-256  relative/path` records: `167a9ab4e2618131985d9d336017782412acbf458c9578d7b04eed34dd9c6e1b`

## Scope and revisions

- Build host: `192.168.1.44`, pinned host key `SHA256:dtRtfEvjwb5TTxCSpO8iCuOLPZli5NVzEvGQUoNtCi8`
- A14 reference: `/root/custom_android/lineage21`
- Canonical A14 patch stack: `lineage-21-td`, commit `b0d95291662e6707af8bcc24458d98f6a6aa33da`
- A16 platform target: `/root/custom_android/lineage23`, branch `lineage-23.2`, Android `android-16.0.0_r4`
- A16 TD targets: `device/phh/treble` `android-16.0`; `treble_app` master
- Repository-specific baseline commits are recorded in each job's verifier `result.json`.

## Totals

### Port-stage outcomes

| Outcome | Rows |
|---|---:|
| CLEAN_AM | 148 |
| REBASED | 114 |
| DROPPED_OBSOLETE | 11 |
| SKIPPED_IRRELEVANT | 32 |
| SKIPPED_RETIRED | 1 |
| Unresolved / blocked | 0 |

Opus subsequently restored or fixed several port-stage drops/rebases. Final artifact totals therefore differ from the port-stage categories.

### Final Opus outcomes

| Outcome | Rows |
|---|---:|
| VERIFIED_HIGH | 289 |
| FIXED_VERIFIED_HIGH | 17 |
| Confidence below 90 | 0 |
| Retained patch artifacts | 265 |
| Verified omissions | 41 |

## Final dropped or superseded rows

- **#1 Bluetooth disabled-commands revert** — its target behavior is absent after the A16 controller refactor; there is nothing to revert.
- **#33 TelephonyMetrics shim** — `TelephonyMetrics.java` and the legacy clearcut metrics path were deleted upstream; no caller remains.
- **#107 VNDK-28 sepolicy selector** — omitted together with #163. VNDK-28 policy is unreachable for this VNDK-33 device; selector without data breaks Soong and data without selector is inert.
- **#216 Display Cutout Error** — equivalent fix is already upstream as AOSP commit `911464cc30f6`.
- **#220/#221/#224 notification and QS color-series changes** — superseded by A16 notification redesign and `materialColor`/`customColor` theming. Partial reverts would create an incoherent visual stack.
- **#229 SplitShade header colors** — behavior is absorbed into A16 `ShadeHeaderController.updateColors()`.
- **#237 QSCarrier visibility fixup** — its target method is gone and its parent #229 is omitted.

Port-stage drops **#4** and **#134** were rejected by Opus: the fingerprint-cleanup gate migrated to AIDL `FingerprintProvider.java`. Both were restored and verified. Personal small-clock counterpart **#285** was also restored to stay coherent with #276.

## Verified skips

- Retired identity patch **#260** remains omitted; retail model `C10` is supplied by the fixed #262 patch.
- Device-specific personal TD rows **#304-306** remain omitted to preserve the known-good C10 build configuration.
- Frameworks/base FOD/UDFPS group **#3/#146/#154/#159** is omitted after payload review; all touched behavior is UDFPS-only and the C10 has no fingerprint hardware.
- Most frameworks/base personal UI rows **#278-299** remain omitted after individual payload review. **#285** is the exception and was restored.
- Personal telephony SPN **#267** and Chinese OEM captive-portal override **#273** remain omitted.
- VNDK-28 policy data **#163** is omitted with selector #107.

## Opus fixes incorporated

The promoted tree uses verifier artifacts for all fixed rows:

- **#4, #134** — restored fingerprint cleanup reverts at the migrated AIDL provider.
- **#16** — repaired MTK GED KPI port: malformed escapes, raw NUL, invalid binder conversion, and missing `NO_BINDER` guards.
- **#22** — rustfmt-compliant no-BPF Rust logging hunk.
- **#35** — restored an unrelated A16 radio diagnostic lost during conflict resolution.
- **#99** — guarded V7 metadata conversion so `libaudiohal@2.0` compiles.
- **#151** — fixed illegal Java capture of a newly non-final brightness variable.
- **#166** — converted all A16 kernel-version hard exits, not only one, to the intended no-BPF failure flag.
- **#171** — added the missing A2DP sysbta client-interface path.
- **#177** — moved the stray HCI command guard to the actually reachable assertion.
- **#184** — repaired author/Change-Id metadata without changing code.
- **#198** — removed an unintended residual blank line from the Messaging chain.
- **#211** — restored the navbar ContentObserver attach/detach lifecycle.
- **#262** — replaced the build-breaking A14 identity mechanism with A16 Soong build-property overrides; exact FancyDay/C10US/C10 identity retained.
- **#263** — updated the restored `/sbin` PATH to preserve A16 `/apex/com.android.virt/bin`.
- **#264** — removed personal `CGMod` branding while retaining the LineageOS self-built property mechanism.
- **#285** — restored the SystemUI small-clock counterpart to retained ThemePicker #276.

## A16 project and mechanism moves

| A14 target | A16 handling |
|---|---|
| `packages/apps/Trebuchet` | Retargeted to `packages/apps/Launcher3`; apply-directory normalization verified. |
| `packages/apps/Nfc` | Mainlined into `packages/modules/Nfc`; #266 retargeted to the resource default. |
| `system/nfc` | Mainlined into `packages/modules/Nfc`; #44 retargeted to `searchConfigPath()`. Co-apply with #266 is order-independent. |
| `build/make` build-info scripts | Product/system build props moved to `build/soong/scripts/gen_build_prop.py`; #108/#264 retargeted there. |
| C++ `system/bpf` bpfloader | Split into Rust `loader/bpfloader.rs`, C++ `loader/Loader.cpp`, and mainline `netbpfload`; all no-BPF failure analogs were mapped. |
| `system/core/rootdir/Android.mk` | Root-structure logic moved to `create_root_structure.mk`/Soong-generated environment rc. |
| `Fingerprint21.java` cleanup gate | Migrated to AIDL `FingerprintProvider.java`; #4/#134 restored at the new site. |

## Cross-project constraints

These rows must be promoted/applied as a unit; the promoted tree contains every member:

- frameworks/native **#15** with hardware/interfaces **#190** (`vendor800_1`).
- telephony **#34/#35/#40** with frameworks/base **#150/#158** and packages/services/Telephony **#82**.
- build/Soong **#264** with vendor/lineage **#269**.
- LineageParts **#199** with lineage-sdk **#200**.
- Securize removal **#258** with TrebleApp **#249**.
- VNDK-28 selector/data **#107/#163** remain omitted together.

## Security and identity checks

- `9001-model-allwinner-a523.patch` remains retired.
- #262 uses the retail identity: brand/manufacturer `FancyDay`, device/model `C10`, name `C10US`, exact dump-derived fingerprint/description/display ID, tablet characteristics.
- #261 contains only the intended self-signed `f74ca33f.0` certificate; no private key and no unrelated trust material changes.
- Securize 1/2 and 2/2 remove the dangerous relock path while preserving unrelated `rw-system.sh` and TrebleApp behavior.
- No secrets were added to the promoted patch tree.

## First integration-build gates

No row remains low-confidence, but the first integration build should pay particular attention to:

1. `m SystemUI services` for the large frameworks/base chain and cross-repo telephony symbols.
2. `libaudiopolicymanagerdefault`, `libaudiohal@2.0`, and `libcameraservice` for frameworks/av.
3. SurfaceFlinger/libgui targets for frameworks/native #14-16 and #20.
4. Connectivity/netbpfload source composition for the verified no-BPF family.
5. Building TrebleApp and copying its APK through the existing TD overlay workflow; the source patch alone does not update a prebuilt APK.

## Integration command

The A16 tree currently has no installed `lineage_build_unified` or `lineage_patches_unified` checkout. First wire `/root/port-los23-td/patches-l23/` into an A16 build-wrapper patch repository, preserving its five set directories and project names. Do not modify the read-only A14 reference stack.

To apply the full promoted stack, including retained `patches_platform_personal` rows, use the A16 wrapper's equivalent of:

```bash
setsid nohup bash lineage_build_unified/buildbot_unified.sh treble 64GN personal \
  > /root/custom_android/build-los23.log 2>&1 < /dev/null &
```

For known-good L21 recipe parity without personal-set patches, omit `personal`:

```bash
setsid nohup bash lineage_build_unified/buildbot_unified.sh treble 64GN \
  > /root/custom_android/build-los23.log 2>&1 < /dev/null &
```

Do not use `nosync` for the first A16 integration run. The wrapper/patch-repository setup is a separate prerequisite and was intentionally not installed or downloaded during patch-level work.
