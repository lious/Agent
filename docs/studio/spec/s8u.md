## 8U · 端侧完整Schema、持久化与可执行操作案例

这是新增独立ondevice/1.0.0合同，不改Project/Manifest 2.0或既有Schema工厂。对象全部字段required、additionalProperties=false；nullable显式union，default不自动填值。只有Node.parameters是有限标量字典，还需op参数白名单。U64/I64字符串由语义层验证signed64范围、Time约分/正duration、矩阵可逆、crop边界、帧/样本映射、ID引用/ACL、DAG、真实许可与能力；JSON Schema不会自动验证这些业务关系。

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/ModelPack-1.0.0.json",
  "$ref": "#/$defs/ModelPack",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/MaskAsset-1.0.0.json",
  "$ref": "#/$defs/MaskAsset",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/MaskTrack-1.0.0.json",
  "$ref": "#/$defs/MaskTrack",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/Pipeline-1.0.0.json",
  "$ref": "#/$defs/Pipeline",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/Job-1.0.0.json",
  "$ref": "#/$defs/Job",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/Checkpoint-1.0.0.json",
  "$ref": "#/$defs/Checkpoint",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/DerivedCandidate-1.0.0.json",
  "$ref": "#/$defs/DerivedCandidate",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/DialoguePlan-1.0.0.json",
  "$ref": "#/$defs/DialoguePlan",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/OutputManifest-1.0.0.json",
  "$ref": "#/$defs/OutputManifest",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/ondevice/NativeVoice-1.0.0.json",
  "$ref": "#/$defs/NativeVoice",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_.:-]{1,128}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-?[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Time": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "$ref": "#/$defs/I64"
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000000000
        }
      }
    },
    "Range": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start",
        "duration"
      ],
      "properties": {
        "start": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "Namespace": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "appId",
        "tenantId",
        "workspaceId"
      ],
      "properties": {
        "appId": {
          "$ref": "#/$defs/Id"
        },
        "tenantId": {
          "$ref": "#/$defs/Id"
        },
        "workspaceId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Pin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "hash"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetId",
        "assetVersion",
        "blobHash",
        "range",
        "frameHash"
      ],
      "properties": {
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "assetVersion": {
          "$ref": "#/$defs/U64"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "range": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameHash": {
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
    },
    "Rect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height"
      ],
      "properties": {
        "x": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1000000000000
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1000000000000
        }
      }
    },
    "Task": {
      "enum": [
        "ground",
        "segment",
        "track",
        "imageErase",
        "videoErase",
        "separate",
        "asr",
        "upscale",
        "imageDenoise",
        "speechDenoise",
        "tts",
        "voiceClone"
      ]
    },
    "Tensor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "logicalName",
        "nativeName",
        "dtype",
        "shape",
        "layout"
      ],
      "properties": {
        "logicalName": {
          "$ref": "#/$defs/Id"
        },
        "nativeName": {
          "$ref": "#/$defs/Id"
        },
        "dtype": {
          "enum": [
            "f32",
            "f16",
            "i64",
            "i32",
            "u8"
          ]
        },
        "shape": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 32
          },
          "minItems": 1,
          "maxItems": 8
        },
        "layout": {
          "enum": [
            "NCHW",
            "NHWC",
            "BCT",
            "BN",
            "scalar",
            "opaqueNamedTensors"
          ]
        }
      }
    },
    "PackFile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "path",
        "hash",
        "bytes",
        "role"
      ],
      "properties": {
        "path": {
          "type": "string",
          "maxLength": 500
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "role": {
          "enum": [
            "weights",
            "config",
            "tokenizer",
            "lexicon",
            "notice",
            "runtime"
          ]
        }
      }
    },
    "License": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "component",
        "kind",
        "licenseId",
        "evidenceUrl",
        "commercialStatus",
        "grantRef"
      ],
      "properties": {
        "component": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "code",
            "weights",
            "runtime",
            "lexicon"
          ]
        },
        "licenseId": {
          "type": "string",
          "maxLength": 100
        },
        "evidenceUrl": {
          "type": "string",
          "format": "uri",
          "maxLength": 2048
        },
        "commercialStatus": {
          "enum": [
            "allowed",
            "restricted",
            "unknown"
          ]
        },
        "grantRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ModelPack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "task",
        "upstreamModelId",
        "sourceRepo",
        "sourceRevision",
        "files",
        "tensorABIHash",
        "inputs",
        "outputs",
        "preprocessId",
        "postprocessId",
        "licenses",
        "runtime",
        "offlineOnly"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "upstreamModelId": {
          "type": "string",
          "maxLength": 300
        },
        "sourceRepo": {
          "type": "string",
          "format": "uri"
        },
        "sourceRevision": {
          "type": "string",
          "pattern": "^[0-9a-f]{40}$"
        },
        "files": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PackFile"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "tensorABIHash": {
          "$ref": "#/$defs/Hash"
        },
        "inputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Tensor"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "preprocessId": {
          "$ref": "#/$defs/Id"
        },
        "postprocessId": {
          "$ref": "#/$defs/Id"
        },
        "licenses": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/License"
          },
          "minItems": 1,
          "maxItems": 100
        },
        "runtime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "operatorFingerprint",
            "backends",
            "conformanceHash",
            "resourceCalibrationHash"
          ],
          "properties": {
            "engine": {
              "enum": [
                "onnx",
                "ncnn",
                "whisperCpp",
                "rnnoiseC",
                "torchWorker",
                "nativeOs"
              ]
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "operatorFingerprint": {
              "$ref": "#/$defs/Hash"
            },
            "backends": {
              "type": "array",
              "items": {
                "enum": [
                  "cpu",
                  "coreml",
                  "nnapi",
                  "vulkan",
                  "cuda",
                  "metal"
                ]
              },
              "minItems": 1,
              "maxItems": 6
            },
            "conformanceHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "resourceCalibrationHash": {
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
        },
        "offlineOnly": {
          "const": true
        }
      }
    },
    "Prompt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "point",
        "box",
        "strokeHash",
        "frameTime"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "positive",
            "negative",
            "box",
            "brush"
          ]
        },
        "point": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "null"
            }
          ]
        },
        "box": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rect"
            },
            {
              "type": "null"
            }
          ]
        },
        "strokeHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameTime": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "MaskAsset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "frame",
        "uprightSize",
        "encoding",
        "semantic",
        "blobHash",
        "transform",
        "prompts",
        "packPin",
        "paramsHash",
        "manual",
        "threshold",
        "featherPx",
        "dilatePx"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "frame": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "pts",
            "decodeIndex",
            "frameHash"
          ],
          "properties": {
            "pts": {
              "$ref": "#/$defs/Time"
            },
            "decodeIndex": {
              "$ref": "#/$defs/U64"
            },
            "frameHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "uprightSize": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "height": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            }
          }
        },
        "encoding": {
          "enum": [
            "r8",
            "r16",
            "f16"
          ]
        },
        "semantic": {
          "enum": [
            "objectProbability",
            "objectAlpha",
            "removeRegion"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "transform": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawToUpright",
            "sourceCrop",
            "resizedWidth",
            "resizedHeight",
            "padding",
            "uprightToModel"
          ],
          "properties": {
            "rawToUpright": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            },
            "sourceCrop": {
              "$ref": "#/$defs/Rect"
            },
            "resizedWidth": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "resizedHeight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
            },
            "padding": {
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32768
              },
              "minItems": 4,
              "maxItems": 4
            },
            "uprightToModel": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          }
        },
        "prompts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Prompt"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "paramsHash": {
          "$ref": "#/$defs/Hash"
        },
        "manual": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "strokeBlobHash",
            "lockedTileIds",
            "revision"
          ],
          "properties": {
            "strokeBlobHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "lockedTileIds": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Id"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "threshold": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "featherPx": {
          "type": "number",
          "minimum": 0,
          "maximum": 512
        },
        "dilatePx": {
          "type": "integer",
          "minimum": -512,
          "maximum": 512
        }
      }
    },
    "MaskRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "pts",
        "decodeIndex",
        "maskId",
        "maskVersion",
        "maskHash",
        "trackSegmentId",
        "quality",
        "score",
        "scoreCalibrationHash"
      ],
      "properties": {
        "pts": {
          "$ref": "#/$defs/Time"
        },
        "decodeIndex": {
          "$ref": "#/$defs/U64"
        },
        "maskId": {
          "$ref": "#/$defs/Id"
        },
        "maskVersion": {
          "$ref": "#/$defs/U64"
        },
        "maskHash": {
          "$ref": "#/$defs/Hash"
        },
        "trackSegmentId": {
          "$ref": "#/$defs/Id"
        },
        "quality": {
          "enum": [
            "unreviewed",
            "verified",
            "corrected",
            "lost"
          ]
        },
        "score": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "null"
            }
          ]
        },
        "scoreCalibrationHash": {
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
    },
    "TrackChunk": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ordinal",
        "sourceRange",
        "maskRefsHash",
        "checkpointHash",
        "commitEpoch"
      ],
      "properties": {
        "ordinal": {
          "$ref": "#/$defs/U64"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "maskRefsHash": {
          "$ref": "#/$defs/Hash"
        },
        "checkpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "commitEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "MaskTrack": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "source",
        "sourcePtsMapHash",
        "sourceRange",
        "objectId",
        "algorithm",
        "packPins",
        "frames",
        "chunks",
        "lockedKeyframeIds",
        "correctionEpoch",
        "constraintsHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "sourcePtsMapHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "objectId": {
          "$ref": "#/$defs/Id"
        },
        "algorithm": {
          "enum": [
            "flowRefine",
            "sam2Memory"
          ]
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 1,
          "maxItems": 8
        },
        "frames": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/MaskRef"
          },
          "minItems": 1,
          "maxItems": 1000000
        },
        "chunks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/TrackChunk"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "lockedKeyframeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 10000
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        },
        "constraintsHash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Params": {
      "type": "object",
      "maxProperties": 128,
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          {
            "type": "boolean"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "Node": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "op",
        "dependsOn",
        "packPin",
        "inputArtifactHashes",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "op": {
          "enum": [
            "decode",
            "segment",
            "ground",
            "track",
            "imageErase",
            "videoErase",
            "separate",
            "asr",
            "upscale",
            "imageDenoise",
            "speechDenoise",
            "tts",
            "voiceClone",
            "resample",
            "composite",
            "encode"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "packPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "inputArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "parameters": {
          "$ref": "#/$defs/Params"
        }
      }
    },
    "Pipeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "nodes",
        "outputNodeIds",
        "offlineOnly",
        "allowCloudFallback"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "nodes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Node"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "outputNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "offlineOnly": {
          "const": true
        },
        "allowCloudFallback": {
          "const": false
        }
      }
    },
    "Job": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "projectId",
        "baseRevision",
        "graphHash",
        "sourceSetHash",
        "state",
        "recordVersion",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "lastCheckpointHash",
        "lastCommittedChunk",
        "error"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "state": {
          "enum": [
            "queued",
            "waitingModel",
            "waitingResource",
            "preparing",
            "running",
            "checkpointing",
            "suspended",
            "waitingCorrection",
            "completedCandidate",
            "cancelRequested",
            "cancelled",
            "failed",
            "invalidated"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "lastCheckpointHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastCommittedChunk": {
          "$ref": "#/$defs/I64"
        },
        "error": {
          "anyOf": [
            {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "code",
                "retryable",
                "nodeId"
              ],
              "properties": {
                "code": {
                  "$ref": "#/$defs/Id"
                },
                "retryable": {
                  "type": "boolean"
                },
                "nodeId": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Id"
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Checkpoint": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "jobId",
        "namespace",
        "graphHash",
        "sourceSetHash",
        "packSetHash",
        "nodeId",
        "sourceRange",
        "completedChunkHashes",
        "stateBlobHash",
        "stateABI",
        "replayFrom",
        "cancelEpoch",
        "privacyEpoch",
        "rightsEpoch",
        "correctionEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "packSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "nodeId": {
          "$ref": "#/$defs/Id"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "completedChunkHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "stateBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "stateABI": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "replayFrom": {
          "anyOf": [
            {
              "$ref": "#/$defs/Time"
            },
            {
              "type": "null"
            }
          ]
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "correctionEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "AudioPart": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stem",
        "assetId",
        "blobHash",
        "sampleRate",
        "channels",
        "sampleCount",
        "latencySamples"
      ],
      "properties": {
        "stem": {
          "enum": [
            "vocals",
            "accompaniment",
            "drums",
            "bass",
            "other",
            "speech",
            "tts"
          ]
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "sampleRate": {
          "type": "integer",
          "minimum": 8000,
          "maximum": 192000
        },
        "channels": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8
        },
        "sampleCount": {
          "$ref": "#/$defs/U64"
        },
        "latencySamples": {
          "$ref": "#/$defs/I64"
        }
      }
    },
    "DerivedCandidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "task",
        "sourceRefs",
        "packPins",
        "artifactHashes",
        "audioParts",
        "contentRange",
        "jobId",
        "baseRevision",
        "readSetHash",
        "privacyEpoch",
        "rightsEpoch",
        "quality"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "sourceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Source"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "packPins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "artifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "audioParts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AudioPart"
          },
          "minItems": 0,
          "maxItems": 8
        },
        "contentRange": {
          "$ref": "#/$defs/Range"
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "readSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        },
        "quality": {
          "enum": [
            "unknown",
            "needsReview",
            "accepted",
            "rejected"
          ]
        }
      }
    },
    "NativeVoice": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "osName",
        "osVersion",
        "engineId",
        "voiceId",
        "language",
        "requiresNetwork",
        "installed",
        "offlineValidationHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "osName": {
          "enum": [
            "ios",
            "android",
            "macos",
            "windows",
            "linux"
          ]
        },
        "osVersion": {
          "type": "string",
          "maxLength": 100
        },
        "engineId": {
          "type": "string",
          "maxLength": 300
        },
        "voiceId": {
          "type": "string",
          "maxLength": 300
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "requiresNetwork": {
          "type": "boolean"
        },
        "installed": {
          "type": "boolean"
        },
        "offlineValidationHash": {
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
    },
    "OutputMedia": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "role",
        "blobHash",
        "mime",
        "width",
        "height",
        "channels",
        "sampleRate",
        "sampleCount",
        "colorSpace",
        "alphaMode",
        "ptsMapHash",
        "frameGeometryMapHash",
        "remainingLatency"
      ],
      "properties": {
        "role": {
          "enum": [
            "image",
            "video",
            "mask",
            "audio",
            "transcript",
            "geometry"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "height": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 131072
            },
            {
              "type": "null"
            }
          ]
        },
        "channels": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleRate": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 8000,
              "maximum": 192000
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleCount": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "colorSpace": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "alphaMode": {
          "anyOf": [
            {
              "enum": [
                "none",
                "straight",
                "premultiplied"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "ptsMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "frameGeometryMapHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "remainingLatency": {
          "$ref": "#/$defs/Time"
        }
      }
    },
    "OutputManifest": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "namespace",
        "task",
        "actualRuntime",
        "mediaOutputs",
        "observedCoverageHash",
        "inferredCoverageHash",
        "sourceSetHash",
        "graphHash",
        "qaArtifactHashes",
        "nativeVoiceDescriptorHash"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "task": {
          "$ref": "#/$defs/Task"
        },
        "actualRuntime": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engine",
            "engineVersion",
            "backend",
            "capabilitiesHash",
            "packSetHash"
          ],
          "properties": {
            "engine": {
              "$ref": "#/$defs/Id"
            },
            "engineVersion": {
              "$ref": "#/$defs/Version"
            },
            "backend": {
              "enum": [
                "cpu",
                "coreml",
                "nnapi",
                "vulkan",
                "cuda",
                "metal",
                "nativeOs"
              ]
            },
            "capabilitiesHash": {
              "$ref": "#/$defs/Hash"
            },
            "packSetHash": {
              "$ref": "#/$defs/Hash"
            }
          }
        },
        "mediaOutputs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/OutputMedia"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "observedCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "inferredCoverageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceSetHash": {
          "$ref": "#/$defs/Hash"
        },
        "graphHash": {
          "$ref": "#/$defs/Hash"
        },
        "qaArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "nativeVoiceDescriptorHash": {
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
    },
    "VoiceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "characterLibraryId",
        "characterAssetId",
        "characterVersion",
        "voiceProfileHash",
        "engineRef",
        "presetVoiceId",
        "privateReferenceId",
        "voiceRightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "characterLibraryId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterAssetId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "characterVersion": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceProfileHash": {
          "$ref": "#/$defs/Hash"
        },
        "engineRef": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "ref"
          ],
          "properties": {
            "kind": {
              "enum": [
                "modelPack",
                "nativeVoice"
              ]
            },
            "ref": {
              "$ref": "#/$defs/Pin"
            }
          }
        },
        "presetVoiceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "privateReferenceId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "voiceRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Line": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "text",
        "sourceOffset",
        "sourceLength",
        "language",
        "voiceBindingId",
        "mode",
        "styleIntent",
        "speed",
        "pronunciationOverrides",
        "targetRange",
        "lockedClipIds",
        "manualCaptionIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "sourceOffset": {
          "$ref": "#/$defs/U64"
        },
        "sourceLength": {
          "$ref": "#/$defs/U64"
        },
        "language": {
          "type": "string",
          "maxLength": 32
        },
        "voiceBindingId": {
          "$ref": "#/$defs/Id"
        },
        "mode": {
          "enum": [
            "tts",
            "clone"
          ]
        },
        "styleIntent": {
          "type": "string",
          "maxLength": 1000
        },
        "speed": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 2
        },
        "pronunciationOverrides": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "offset",
              "length",
              "phonemes",
              "alphabet"
            ],
            "properties": {
              "offset": {
                "$ref": "#/$defs/U64"
              },
              "length": {
                "$ref": "#/$defs/U64"
              },
              "phonemes": {
                "type": "string",
                "maxLength": 2000
              },
              "alphabet": {
                "enum": [
                  "ipa",
                  "pinyin"
                ]
              }
            }
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "targetRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "manualCaptionIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "DialoguePlan": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "scriptHash",
        "lines",
        "voiceBindings",
        "privacyEpoch",
        "rightsEpoch"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "scriptHash": {
          "$ref": "#/$defs/Hash"
        },
        "lines": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Line"
          },
          "minItems": 1,
          "maxItems": 10000
        },
        "voiceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/VoiceBinding"
          },
          "minItems": 1,
          "maxItems": 64
        },
        "privacyEpoch": {
          "$ref": "#/$defs/U64"
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    }
  }
}
```

| 状态/异常 | UI与持久化边界 |
| --- | --- |
| 安装 | Catalog中已批准URL/许可证→用户同意模型下载→staging流式校验/空间预检→签名/hash/ABI→原子安装索引；不运行包内代码，源不可达/校验失败保留旧好版本，用户不下载仍能手工编辑。更新固定新pin，不改变旧项目模型引用。 |
| Job状态 | queued→waitingModel/waitingResource→preparing→running↔checkpointing→completedCandidate；人工缺口waitingCorrection；OS中断suspended；取消cancelRequested→cancelled；source/rights/pack变化invalidated；错误failed。completedCandidate不是已应用或已保存工程。 |
| 原子chunk | 先写私有staging并checksum→fsync/CAS durable→同workspace事务校验recordVersion/cancel/privacy/rights/source/owner fence→写chunk/新checkpoint→ACK；未提交文件是可GC孤儿，不创建Core pending Asset。已提交chunk不重写，resume只读有效前缀。 |
| 恢复 | checkpoint验证graph/source/packSet/stateABI/rights/privacy/correction epoch；相同可从typed tensor状态继续。ABI不兼容或RNNoise/其他state不可序列化则从固定anchor/preroll重算并丢预滚输出，不memcpy指针。device后台到期先suspend；进程被杀从最后durable chunk恢复，不能保证后台一定跑完。 |
| OS差异 | iOS后台时间有限且调度不保证；Android WorkManager/前台服务按系统政策与用户通知；桌面可本地worker。权限撤销/外盘拔出/磁盘满不覆盖唯一好副本，保留已提交段并提示重新授权/选位置；model包/输入不可用则waitingModel或failed，不偷偷上传。 |
| 错误码 | MODEL_NOT_INSTALLED、LICENSE_EVIDENCE_MISSING、COMMERCIAL_LICENSE_REQUIRED、MODEL_ABI_UNVERIFIED、OP_UNSUPPORTED、RESOURCE_WAIT/OOM、MASK_SOURCE_CHANGED、TRACK_LOST、RECONSTRUCTION_UNSUITABLE、HDR_AI_COLOR_UNSUPPORTED、PHONEME_UNSUPPORTED、VOICE_RIGHTS_REVOKED、REFERENCE_NO_SPEECH、CHECKPOINT_STALE、REVISION_CONFLICT；每错误给本地重试/改参数/补资料选项，不自动变收费云任务。 |
| 事务与撤销 | 结果ready candidate→readSet/锁/epoch复核→attachArtifacts＋既有白名单EditCommand；LLM不写DB。图片mask用既有静态mask/raster layer；视频MaskTrack不能塞进Core静态mask参数，先在派生渲染图烘焙成video Asset，保Track侧车供重编辑。撤销恢复原引用/图层/音轨，不删除原件。 |
| 保存归档 | 保存当前Project revision与已接受派生引用；私有Job、typed checkpoint、VoiceStore、下载临时、凭据不混进工程包。可选“保留AI制作依据”注册RefWalker闭包，写extensions/ondevice/图/Mask/Track/Dialogue/映射/许可与hash清单。模型默认referencesOnly；用户明确选择才嵌入，组件再分发许可受限/缺失按1C保留风险不阻断，沿现有Manifest字段不扩enum。私有克隆参考/embedding默认不导出；删消息/源/授权后按10A删除overlay，旧归档不可复活已删正文。 |

```text
-- ONDEVICE_SQL_BEGIN
-- additive workspace migration; requires document_lifecycle/1; runner用backup+BEGIN/rollback。
INSERT INTO workspace_features VALUES('ondevice_pipeline','1.0.0','ondevice-pipeline/1');
CREATE TABLE ondevice_jobs(
 ns TEXT NOT NULL,id TEXT NOT NULL,project_id TEXT NOT NULL,base_revision INTEGER NOT NULL CHECK(base_revision>=0),
 descriptor_hash TEXT NOT NULL,graph_hash TEXT NOT NULL,source_set_hash TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('queued','waitingModel','waitingResource','preparing','running','checkpointing','suspended','waitingCorrection','completedCandidate','cancelRequested','cancelled','failed','invalidated')),
 record_version INTEGER NOT NULL CHECK(record_version>=0),cancel_epoch INTEGER NOT NULL CHECK(cancel_epoch>=0),
 privacy_epoch INTEGER NOT NULL CHECK(privacy_epoch>=0),rights_epoch INTEGER NOT NULL CHECK(rights_epoch>=0),
 owner_fence INTEGER NOT NULL CHECK(owner_fence>=0),last_checkpoint_hash TEXT,last_committed_chunk INTEGER NOT NULL CHECK(last_committed_chunk>=-1),
 PRIMARY KEY(ns,id),FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id));
CREATE TRIGGER ondevice_descriptor_immutable BEFORE UPDATE OF ns,id,project_id,base_revision,descriptor_hash,graph_hash,source_set_hash ON ondevice_jobs
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_JOB_DESCRIPTOR'); END;
CREATE TABLE ondevice_chunks(
 ns TEXT NOT NULL,job_id TEXT NOT NULL,ordinal INTEGER NOT NULL CHECK(ordinal>=0),
 payload_hash TEXT NOT NULL,range_json TEXT NOT NULL,commit_epoch INTEGER NOT NULL CHECK(commit_epoch>=0),
 PRIMARY KEY(ns,job_id,ordinal),FOREIGN KEY(ns,job_id) REFERENCES ondevice_jobs(ns,id));
CREATE TRIGGER ondevice_chunk_no_update BEFORE UPDATE ON ondevice_chunks
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_CHUNK'); END;
CREATE TRIGGER ondevice_chunk_no_replace BEFORE INSERT ON ondevice_chunks
 WHEN EXISTS(SELECT 1 FROM ondevice_chunks WHERE ns=NEW.ns AND job_id=NEW.job_id AND ordinal=NEW.ordinal)
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_CHUNK'); END;
CREATE TABLE ondevice_checkpoints(
 ns TEXT NOT NULL,job_id TEXT NOT NULL,ordinal INTEGER NOT NULL CHECK(ordinal>=0),
 checkpoint_hash TEXT NOT NULL,source_set_hash TEXT NOT NULL,graph_hash TEXT NOT NULL,pack_set_hash TEXT NOT NULL,
 state_abi TEXT,rights_epoch INTEGER NOT NULL,privacy_epoch INTEGER NOT NULL,correction_epoch INTEGER NOT NULL,
 PRIMARY KEY(ns,job_id,ordinal),FOREIGN KEY(ns,job_id) REFERENCES ondevice_jobs(ns,id));
CREATE TRIGGER ondevice_checkpoint_no_update BEFORE UPDATE ON ondevice_checkpoints
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_CHECKPOINT'); END;
CREATE TRIGGER ondevice_checkpoint_no_replace BEFORE INSERT ON ondevice_checkpoints
 WHEN EXISTS(SELECT 1 FROM ondevice_checkpoints WHERE ns=NEW.ns AND job_id=NEW.job_id AND ordinal=NEW.ordinal)
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_CHECKPOINT'); END;
CREATE TRIGGER ondevice_chunk_no_raw_delete BEFORE DELETE ON ondevice_chunks
 BEGIN SELECT RAISE(ABORT,'USE_LOCAL_RETENTION_SERVICE'); END;
CREATE TRIGGER ondevice_checkpoint_no_raw_delete BEFORE DELETE ON ondevice_checkpoints
 BEGIN SELECT RAISE(ABORT,'USE_LOCAL_RETENTION_SERVICE'); END;
-- ONDEVICE_SQL_END
// DTO是read model；job state/recordVersion/epoch只有工作区row是权威。
// ChunkWriter事务WHERE ns/id/recordVersion/cancelEpoch/privacyEpoch/rightsEpoch/ownerFence
// 全匹配且state=running/checkpointing、ordinal=lastCommittedChunk+1才插入并推进。
// checkpoint与job.last_checkpoint_hash在同事务更新；SQLite FK本身不验证hash或区间。
// 幂等重放先读相同键/hash；不得REPLACE已提交checkpoint/chunk。
// RetentionService清派生正文/孤儿CAS须先计算可达性/epoch；删除最小元数据用专门受审迁移，普通API无raw delete。
// Private VoiceStore独立加密，不能假称与workspace/session DB跨库单事务；用outbox/receipt。

```

```text
// 合成案例1：照片去路人（无实际私有照片）
source image A/hashA/upright1920x1080 → 正点/框 → maskM1 MobileSAM候选
→ 人工负点+发丝边缘画笔M2/manualRevision1/锁tile
→ removeRegion(dilate3px,feather2px) → ROI+LaMa本地job J1
→ output新layerCandidate C1(sourceA,M2,packHash,ROI,observed/inferred map)
用户在等待期间改标题，Project R8→R9；C1只写新图层，不触碰标题。
接受前重读R9/锁/epoch，diff接受→R10；撤销回旧层引用，原图A仍在。
若修改source crop/旋转，MASK_SOURCE_CHANGED需重映射确认；取消J1后晚到C1隔离。
保存R10、归档派生图/Mask/模型引用，不自动包权重或私有Session。

// 合成案例2：10秒视频移除站立路人
source VFR A＋PTS map → 当前源帧M1 → flowRefine轻追或桌面SAM2 memory
→ t=4.2s遮挡标lost、暂停自动补全 → 用户校正M2并锁关键帧
→ correctionEpoch2，仅向前后到相邻anchor/切镜重追，M2不被重算
→ 静态背景重建覆盖图，剩余洞单anchor LaMa → 每帧warp/composite → C2
若视差/动态背景失败RECONSTRUCTION_UNSUITABLE；ProPainter缺商业授权仅显示风险可继续切换；若实际模型/ABI/资源能力未就绪仍不可执行。
用户2倍速：TimeMap采源PTS和同帧mask，不用输出帧序号。C2接受只替视频源，保trim/字幕/原音。
OS中断只保已提交chunk；恢复比对源/pack/epoch，未提交尾块重算，无重复帧入库。

```

```text
// 合成案例3：对白带背景音乐/噪声→人声/字幕
原stereo48k → 用户试听分离样本 → Demucs44.1k/四stem候选
→ 选择vocals → 可选RNNoise48k mono对话候选（保原stereo独立）
→ 与原音ASR短样本比较，用户选较清晰输入 → Whisper base16k分窗
→ source/delay/TimeMap映射CaptionProposal，speakerId=null
→ 用户手改cue12并锁 → 后续重识别只diff未锁cue，保护cue12 text与音量键。
选择stem只新增音轨/静音提案，不能覆盖原音；原音混合残差报告不伪称模型无损。
checkpoint后source重链接版本变化→CHECKPOINT_STALE，不拿旧语音写新素材字幕。

// 合成案例4：角色台词朗读/授权克隆
Character Lan@1/VoiceProfileHash冻结；选择预置Kokoro或有授权的CosyVoice2私有reference。
克隆参考先VAD净时长/转写确认/rights scope检查，参考和embedding只进加密VoiceStore。
DialoguePlan L1“是你的吗？” → 句子tokens/读音确认 → 本地TTS C3实际sampleCount
→ 24k无损候选→48k独立音轨；用户试听后接受，字幕仍为手工“是你的吗？”
台词改“这是你的吗？”→L2，仅该句音频/对齐与可选口型依赖失效；视觉镜头/手工字幕不自动改。
若锁定对白clip时长不容新句，提示缩文/允许改速/延长，不偷偷拉伸。
撤销voice授权epoch+1→阻断新任务、失效embedding/cache；已接受音频按授权范围提示导出限制，
不擅自删除用户源文件。跨App要重新授予私有voice访问；归档默认排除reference/embedding。

```

OS离线朗读不是开源权重包：VoiceBinding.engineRef显式modelPack/nativeVoice两类，NativeVoiceDescriptor记录OS/engine/voice/language、installed/requiresNetwork及离线验证hash，不虚构sourceRevision或权重许可。Android检查voice网络需求及是否安装；iOS/其他平台须选已下载且通过该OS离线验证的voice，无法确认则OFFLINE_VOICE_UNAVAILABLE，不触发隐式下载/网络合成。OS输出同样保存实际sample layout与native descriptor hash，切voice产生新候选。

模型包路径/外部数据：只接受规范POSIX相对路径与受限字符，无空段/点段/父段/反斜杠/冒号/NUL、Windows保留名/尾点、大小写碰撞；拒绝symlink/hardlink、超文件数/实际展开字节上限。ONNX external_data只准manifest中已校验的相对文件，不允许越目录/URL；custom-op domain只允许随App发布的白名单实现。签名未知/未过conformance的模型不能直接进入生产worker；手机无独立进程可杀时尤其不能任意运行用户上传计算图。

ModelPack只下载模型/词典等数据；role=runtime若出现仅作已随App签名发布模块的hash/SBOM引用，不允许从包中动态装可执行库。缺FFT/custom op等模块应APP_UPDATE_REQUIRED，不能靠外部模型包注入代码绕过商店/沙箱。sourceRevision是实际开源上游commit，模型release名称与转换器revision另记构建证据；production gate必须有可信conformance/calibration记录，合成fixture的hash不构成放行。

静态图片candidate.contentRange使用[0,1秒)名义内容域以满足统一DTO，不决定照片在Sequence里的展示时长；实际Clip长度仍由NLE。ASR的windowStartSample是相对所选range的16k输入样本偏移，j是窗口内样本，长音频不能每窗从rangeStart重复计时。导出SRT/VTT前只在最后一步舍入到毫秒，语义对齐仍用有理数/源样本。

结构校验还须分层执行：ModelPack须覆盖code/weights/runtime及所带词典授权、路径无穿越、tensor shape仅已注册符号/整数且尺寸乘积不溢出；签名不等于许可。Mask prompt的kind与point/box/stroke恰一匹配，矩阵可逆且全部点在源crop内。Track帧按(归一PTS,decodeIndex)唯一且在选区，lockedKeyframeId须解析到对应Mask，lost不许当有效透明帧。Pipeline引用同namespace、DAG无环、op/params/模型能力白名单，不能靠parameters字典偷偷执行代码或开网。Dialogue line/voice binding/rights引用真实存在，Unicode scalar offsets与scriptHash吻合；tts和clone前置不同，privateReferenceId字符串本身不代表授权。

本轮验证是几何/PTS/OLA/事务/许可/依赖/中断的合成设计执行，路径[box-local audit path]；历史三轮审查另存review-a/b/c.md，不混进实施规则。模型质量、MobileSAM完整手机导出、LaMa FFT/权重许可、SAM2状态移植、手机Demucs/克隆资源、Kokoro无GPL frontend、真机后台/网络/磁盘故障均未实测；这些放行门禁不等于接口缺失，也不能因此冒称已实现。

- [MobileSAM：代码、权重来源与decoder导出](https://github.com/ChaoningZhang/MobileSAM)
- [SAM2：checkpoint许可和video predictor](https://github.com/facebookresearch/sam2)
- [SAM3：独立SAM License](https://github.com/facebookresearch/sam3/blob/main/LICENSE)
- [BiRefNet官方模型卡：MIT与预处理](https://huggingface.co/ZhengPeng7/BiRefNet)
- [LaMa官方实现与项目Apache许可](https://github.com/advimman/lama)
- [ProPainter：时序传播与非商用许可](https://github.com/sczhou/ProPainter)
- [E2FGVI：HQ checkpoint与NC许可](https://github.com/MCG-NKU/E2FGVI)
- [Demucs：模型、7.8秒限制与音频参数](https://github.com/facebookresearch/demucs)
- [RNNoise C API](https://github.com/xiph/rnnoise/blob/main/include/rnnoise.h)
- [DeepFilterNet：代码/权重双许可](https://github.com/Rikorose/DeepFilterNet)
- [Real-ESRGAN官方ncnn路线](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan)
- [SCUNet官方模型与实现](https://github.com/cszn/SCUNet)
- [nlmeans源码LGPL边界](https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/vf_nlmeans.c)
- [hqdn3d源码GPL边界](https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/vf_hqdn3d.c)
- [OpenCV inpaint的独立notice](https://github.com/opencv/opencv/blob/4.x/modules/photo/src/inpaint.cpp)
- [Whisper.cpp本地推理](https://github.com/ggml-org/whisper.cpp)
- [Kokoro官方权重与24k输出](https://huggingface.co/hexgrad/Kokoro-82M)
- [Sherpa Kokoro：词典/音素/模型包实际依赖](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html)
- [CosyVoice2官方模型卡](https://huggingface.co/FunAudioLLM/CosyVoice2-0.5B)
- [OpenVoiceV2官方模型卡](https://huggingface.co/myshell-ai/OpenVoiceV2)
- [F5-TTS：代码MIT、权重NC](https://github.com/SWivid/F5-TTS)
- [Piper当前engine与voice授权区别](https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/LICENSING.md)
