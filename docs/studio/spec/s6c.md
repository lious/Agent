## 6C · 探测、资源准入与兼容存储合同

| 对象 | 可编码接口与字段 | 判定与失效 |
| --- | --- | --- |
| DeviceProbeService → DeviceSnapshot | snapshot{platform,osVersion,osBuild,arch,deviceModel,gpuId,gpuDriver,runtimeBuilds,physicalMemory,availableProcessMemory?,deviceLocalBudget?,storageFreeBytes,thermalStatus,foreground,capturedAt,probeEpoch}；数量用U64十进制字符串，未知用null，不填0。 | iOS查询可用进程内存/压力，Android getMemoryClass仅managed heap提示，不能代表native/GPU总预算；Windows查询DXGI预算、macOS统一池明确标记。可用预算是瞬态，分配前再查，执行中继续监听压力。 |
| CompatibilityRegistry → QualifiedProfile | resolve{appNamespace,feature,profileId,revision,buildFingerprint,modelPackHashes,runtimeFingerprint,workload,phase,qualifiedFixtureHash}；下列完整Schema为独立sidecar。 | planned/adapting只显示目标；labValidated仅测试渠道；released须证据齐全。结构Schema不自动验证OS语义/epoch/引用/内存。版本/驱动/模型/EP变更使旧资格与probe过期，不自动继承。 |
| CodecProbePort | probe{direction,container,codec,profile,level,bitDepth,chroma,width,height,fpsNum,fpsDen,colorPrimaries,transfer,matrix,range,hdrMetadata,alpha,sampleRate,channelCount,channelLayout,bitrate,sampleFormat,extradataHash,buildFingerprint,osBuild,gpuId,driver}→{advertised,sessionCreated,sampleProcessed,hwActuallyUsed,actualPixelFormat,copyMode,reason,fixtureHash}。 | Apple codec硬解bool之后仍创建目标format session；Android codecInfos/profileLevels/sizeAndRate之后仍配置并处理样本；Windows枚举hardware MFT之后仍激活设type并处理样本；Web分别调用Video/Audio的isConfigSupported与实际样本。decode和encode不互认；返回unknown不写supported=true。音频另查sample-rate/channel-count ranges/bitrate并实际编解码，不能从VideoCapabilities或最大声道数推全部组合；无关模态字段显式null而非伪造0。 |
| ResourceAdmissionController | admit(snapshot,profile,incrementalAllocationLedger,jobIntent)→allow\|allow_with_warning\|waitingResource\|unsupported\|needsApproval＋reason＋fallbackProposals；ResourceLease可撤销。 | 统一池增量host独占＋device独占＋shared只计一次；离散卡分别验host/shared和VRAM，空闲RAM不能抵扣VRAM。先扣已驻留共享Pack，避免既重复计权重又错误减两次；mmap不等于0驻留。 |
| CompatibilityStore / ModelLease | 设备本地缓存probe、资格证据、预算样本；以appNamespace+deviceFingerprint+profileFingerprint为键。共享ModelStore仅共享获权限的只读CAS字节，不跨App偷读会话/voice embedding。 | 重模型手机默认同池并发1，预览decoder/纹理/音频也占预算；Harness两个异构Agent可以轮换而非强制两套模型并驻。thermal严重先减并发/暂停；无法中断的GPU kernel完成后丢晚到候选并释放lease。 |
| CompatibilityFallbackPlanner | propose{sameFormatSoftware,lowerPreviewProxy,smallerQualifiedModel,selfOwnedWorker,approvedCloud,manual}；每项说明时间/画质/隐私/费用/新审批hash。 | 同格式已验软件处理可按用户既有本地偏好回退并记日志；输出尺寸/HDR/模型语义/上传/花费变化必须确认。不存在encoder不得伪装CPU保底；没有任何可用本地路径就显示待适配/不支持，不静默云。 |

默认基础交付候选：MP4容器、H264 Main Level4.0、8-bit 4:2:0、SDR BT.709 limited、最大1920×1080/30fps（竖屏1080×1920同等宏块预算）、AAC-LC 48k stereo。每个方向单独probe；容器可demux不等于码流可解或可编。10-bit HEVC、4:2:2/4:4:4、4K60、HDR PQ/HLG、ProRes、alpha及VFR均独立fixture；保留原件/PTS/color metadata，显式归一或告知不支持。HDR→SDR需确认tonemap/operator，不能静默截断成8bit；改交付fps应重采样时间轴PTS而非改header致变速。第7节时间/帧所有权仍为唯一执行语义。

```text
// Compatibility contracts; design-only, not platform implementation.
CompatibilityProfile 1.0.0: see closed JSON Schema below.
Probe cache key = SHA256(canonical(direction + fullMediaTuple + buildFingerprint
  + osBuild + gpuId + driver + runtimeFingerprint + profileRevision));
// codec-level BOOL, API presence or filename never replaces sampleProcessed evidence.

admit(profile, snapshot, ledger):
  validateSchema(); validateU64BoundsAndRefs(); requireNamespaceAndEpochs();
  retainLicenseFacts(); licenseDecision = allow_with_warning_if_gap; // policy 1C
  requireActualIntegritySafetyConsentBudgetAndBackend(); // independent, unchanged
  if !profileReleasedAndQualified: return PROFILE_NOT_QUALIFIED;
  incremental = predictPeakAllocations(profile, ledger.uniqueAllocationIds);
  // Incremental means additional to already resident allocations, NOT total App peak.
  if unified: require(hostExclusive + deviceExclusive + shared + headroom <= availableNow);
  if discrete: require(hostExclusive + shared + hostHeadroom <= hostAvailableNow
                     && deviceExclusive + deviceHeadroom <= deviceBudgetNow);
  require(diskIncremental + diskReserve <= actualWritableFree);
  if heavy && thermalUnknown: boundedForegroundCalibrationOrWaitingResource();
  if critical: checkpointThenPauseHeavy(); // do not disable basic project editing
  acquireLease(); recheckBeforeAllocate(); catch allocationFailure => waitingResource;
  startWithCancelEpoch(); doNotPromiseBackgroundCompletion();

// Initial policy knobs, not measured safety guarantees:
mobileHeadroom = max(512MiB, 15% physicalMemory);
desktopHostHeadroom = max(2GiB, 10% physicalMemory);
discreteDeviceHeadroom = max(512MiB, 10% deviceBudget);
// Dynamic availableProcessMemory must not be confused with total physicalMemory.
// Unknown low-level budget: no heavy release qualification from a guessed RAM number.
// Basic editing can keep bounded CPU/720p proxy behavior if thermal headroom unavailable.
// Storage = new models + partial downloads + compiled copies + proxies + outputs
//         + archive staging + rollback good copy + reserve; CAS avoids re-copying weights.
// Baseline free-space suggestions in 6A do NOT guarantee a long archive fits.

```

Apple increased-memory-limit entitlement只在部分设备生效，不是保证某App有4GB/8GB；BGProcessingTask由系统决定启动，过期先checkpoint/suspend，后台续命不等于无限计算。Android native/GPU分配不受一个managed heap数字完整描述；Thermal API headroom若NaN/不支持记录unknown，轮询不快于官方10秒建议；Android16长WorkManager/前台service仍可能耗尽job quota，不能承诺一直后台跑。停止/杀进程不回滚已完成外部付费job；恢复复用已durable输出chunk，内存state须匹配runtime/driver/stateABI/源hash及取消/隐私/权利epoch，否则从稳定anchor重放。

资源/系统参考（2026-11-24访问；API证据不等于实测）：https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit ；https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app ；https://developer.android.com/topic/performance/memory-overview ；https://developer.android.com/games/optimize/adpf/thermal ；https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/long-running 。媒体探测参考：https://developer.apple.com/documentation/videotoolbox/vtishardwaredecodesupported(_:) ；https://developer.android.com/media/platform/supported-formats ；https://developer.android.com/reference/android/media/MediaCodecInfo.VideoCapabilities ；https://developer.android.com/reference/android/media/MediaCodecInfo.AudioCapabilities ；https://learn.microsoft.com/en-us/windows/win32/api/mfapi/nf-mfapi-mftenumex 。Android标准支持表也不保证硬件实现或并发性能。

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:studio:compatibility-profile:1.0.0",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schemaVersion",
    "id",
    "revision",
    "platform",
    "arch",
    "osMin",
    "apiMin",
    "phase",
    "buildFingerprint",
    "modelPackHashes",
    "runtimeFingerprint",
    "backend",
    "workload",
    "incrementalBudget",
    "evidenceUrls",
    "qualifiedFixtureHash"
  ],
  "properties": {
    "schemaVersion": {
      "const": "1.0.0"
    },
    "id": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9._-]{1,95}$"
    },
    "revision": {
      "$ref": "#/$defs/U64"
    },
    "platform": {
      "enum": [
        "ios",
        "ipados",
        "android",
        "macos",
        "windows",
        "linux",
        "web"
      ]
    },
    "arch": {
      "enum": [
        "arm64",
        "x64",
        "wasm32"
      ]
    },
    "osMin": {
      "type": "string",
      "minLength": 1,
      "maxLength": 128
    },
    "apiMin": {
      "type": [
        "integer",
        "null"
      ],
      "minimum": 1,
      "maximum": 999
    },
    "phase": {
      "enum": [
        "planned",
        "adapting",
        "labValidated",
        "released",
        "disabled"
      ]
    },
    "buildFingerprint": {
      "$ref": "#/$defs/HashOrNull"
    },
    "modelPackHashes": {
      "type": "array",
      "uniqueItems": true,
      "maxItems": 64,
      "items": {
        "$ref": "#/$defs/Hash"
      }
    },
    "runtimeFingerprint": {
      "$ref": "#/$defs/HashOrNull"
    },
    "backend": {
      "enum": [
        "cpu",
        "xnnpack",
        "metal",
        "coreml",
        "nnapi",
        "vulkan",
        "cuda",
        "nativeCodec",
        "webcodecs",
        "litert"
      ]
    },
    "workload": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "width",
        "height",
        "fpsNum",
        "fpsDen",
        "contextCapacity",
        "maxOutputTokens",
        "parallelModels"
      ],
      "properties": {
        "kind": {
          "enum": [
            "edit",
            "llm",
            "asr",
            "image",
            "track",
            "audioGenerate",
            "videoGenerate",
            "tts",
            "clone"
          ]
        },
        "width": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 1,
          "maximum": 131072
        },
        "height": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 1,
          "maximum": 131072
        },
        "fpsNum": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 1,
          "maximum": 1000000
        },
        "fpsDen": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 1,
          "maximum": 1000000
        },
        "contextCapacity": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 1,
          "maximum": 1048576
        },
        "maxOutputTokens": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 1,
          "maximum": 1048576
        },
        "parallelModels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 16
        }
      }
    },
    "incrementalBudget": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "memoryKind",
        "hostExclusiveBytes",
        "deviceExclusiveBytes",
        "sharedBytes",
        "diskBytes",
        "measurement"
      ],
      "properties": {
        "memoryKind": {
          "enum": [
            "unified",
            "discrete"
          ]
        },
        "hostExclusiveBytes": {
          "$ref": "#/$defs/U64"
        },
        "deviceExclusiveBytes": {
          "$ref": "#/$defs/U64"
        },
        "sharedBytes": {
          "$ref": "#/$defs/U64"
        },
        "diskBytes": {
          "$ref": "#/$defs/U64"
        },
        "measurement": {
          "enum": [
            "estimated",
            "measured"
          ]
        }
      }
    },
    "evidenceUrls": {
      "type": "array",
      "minItems": 1,
      "maxItems": 64,
      "uniqueItems": true,
      "items": {
        "type": "string",
        "pattern": "^https://",
        "maxLength": 2048
      }
    },
    "qualifiedFixtureHash": {
      "$ref": "#/$defs/HashOrNull"
    }
  },
  "$defs": {
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,19})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^[a-f0-9]{64}$"
    },
    "HashOrNull": {
      "anyOf": [
        {
          "$ref": "#/$defs/Hash"
        },
        {
          "type": "null"
        }
      ]
    }
  }
}
```

Schema所有列出字段required、所有对象additionalProperties=false；未知用显式null，仅基础无模型Profile可令modelPackHashes=[]。schemaVersion无隐式default；不兼容major只读，不把feature元数据塞进closed Project2.0.0根。U64字符串结构校验之外还须BigInt检查≤18446744073709551615；OS/build与driver不是简单字典序比较。semanticValidate要求released/labValidated具备非null fingerprints、fixture hash、完整Pack引用、measurement=measured；还要由CompatibilityRegistry.verifyQualification核对可信资格结果记录的profileFingerprint、deviceClass、osBuild、driver、runtimeFingerprint、workloadHash及fixture/result hash，不能填一个任意hash或改measured标志就自称实测。设备标识仅用SKU/芯片/OS/driver组合，不采序列号/广告ID；跨设备不可移植本机资格。本轮实物Profile都尚未满足，不假称已发布。workload按kind校验字段成组：edit/image/track/videoGenerate需width+height，视频需fps两字段；llm需ctx+maxOutput且输出≤总容量、其余模态这些字段null；shape上限不能只靠Schema当资源许可。

```text
-- Independent device-local compatibility cache. Not a second ProjectDocument authority.
CREATE TABLE compatibility_profile (
 app_namespace TEXT NOT NULL, profile_id TEXT NOT NULL, revision_u64 TEXT NOT NULL,
 schema_version TEXT NOT NULL CHECK(schema_version='1.0.0'), fingerprint TEXT NOT NULL,
 phase TEXT NOT NULL CHECK(phase IN('planned','adapting','labValidated','released','disabled')),
 payload_json TEXT NOT NULL CHECK(json_valid(payload_json)),
 PRIMARY KEY(app_namespace,profile_id,revision_u64)
);
CREATE TABLE device_probe_cache (
 app_namespace TEXT NOT NULL, device_fingerprint TEXT NOT NULL, probe_key TEXT NOT NULL,
 profile_fingerprint TEXT NOT NULL, result_json TEXT NOT NULL CHECK(json_valid(result_json)),
 observed_at TEXT NOT NULL, expires_at TEXT NOT NULL, invalidated_epoch_u64 TEXT NOT NULL,
 PRIMARY KEY(app_namespace,device_fingerprint,probe_key)
);
-- U64 parsing/ordering and FK-to-CAS referential checks live in semanticValidate/transaction.
-- Device IDs, free memory/driver probes are NOT portable project requirements.
-- Archive includes referenced profile fingerprint + portable build/model manifest for provenance,
-- NOT another device's qualification bit, live RAM state, secrets or user-session DB.
-- Opening on another device: re-probe and offer supported preview/export, never rewrite source edits.

```

模型/组件许可unknown/restricted/missing默认allow_with_warning，个人开发者商业用途与1C现行策略不变。它不使未支持的算子、未授权人声/肖像、上传/费用、系统拒绝、资源不足或签名失败变成允许；反过来也不能以“兼容资格”为名偷偷将纯商业许可缺口硬阻断。UI应分别显示“许可风险可继续”和“此设备能力待适配/资源等待”，不伪造商业授权。
