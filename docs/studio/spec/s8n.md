## 8N · 垂类完整Schema、SQLite事务与验收门禁

用户手编到新revision后，归档由WorkflowLinkResolver读取该R的权威Clip，沿同工程祖先寻找最近工作流链接，重核clipId/sourceVersion并生成新的派生链接：projectRevision/currentContentHash取归档R，acceptedCommandId=null，原接受命令保留在祖先链接中；不存在的Clip映射移除并报告，已改source的映射标needsRebase，不能把旧候选重新应用。若同一R已有冻结链接，不篡改旧记录，归档额外mapping工件表达对账结果并列checksum。只读旧链接不能伪称与当前NLE完全同步。

以下Schema为可提取校验的设计数据，Draft2020-12。对象一律required=全部声明字段、additionalProperties=false；只有variables是有限标量字典，仍需模板键白名单。nullable显式union；default只是注解，不自动补值。版本与hash/64位时间沿既有合同：JSON整数64用十进制字符串，语义层再查有符号64位上限/有理数约分/正时长/区间/跨引用；小数仅归一crop和软意图，不能作帧时钟。JSON Schema不自动验证资产存在、授权真伪、SKU事实有效、依赖DAG、时段或provider支持。

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/vertical/VerticalBrief-1.0.0.json",
  "$ref": "#/$defs/VerticalBrief",
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
    "Semver": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
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
          "$ref": "#/$defs/Semver"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "AssetRef": {
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
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Crop": {
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
          "maximum": 1
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        }
      }
    },
    "SourceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "role",
        "ordinal",
        "asset",
        "range",
        "crop",
        "audioUse",
        "subjectIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "productFront",
            "productDetail",
            "firstFrame",
            "lastFrame",
            "sourceVideo",
            "motionVideo",
            "referenceImage",
            "referenceVideo",
            "montage",
            "script",
            "voice",
            "music",
            "mask",
            "contextImage"
          ]
        },
        "ordinal": {
          "type": "integer",
          "minimum": 0,
          "maximum": 999
        },
        "asset": {
          "$ref": "#/$defs/AssetRef"
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
        "crop": {
          "anyOf": [
            {
              "$ref": "#/$defs/Crop"
            },
            {
              "type": "null"
            }
          ]
        },
        "audioUse": {
          "enum": [
            "strip",
            "use",
            "voiceRef"
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        }
      }
    },
    "ProductFact": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "kind",
        "text",
        "sourceEvidenceHashes",
        "confirmed",
        "confirmationRef",
        "expiresAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "price",
            "specification",
            "feature",
            "offer",
            "claim",
            "cta"
          ]
        },
        "text": {
          "type": "string",
          "maxLength": 2000
        },
        "sourceEvidenceHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "confirmed": {
          "type": "boolean"
        },
        "confirmationRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "expiresAt": {
          "anyOf": [
            {
              "$ref": "#/$defs/Timestamp"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ProductIdentity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "name",
        "shape",
        "material",
        "color",
        "dimensionsText",
        "packaging",
        "logoAssetRef",
        "referenceBindingIds",
        "factIds",
        "forbiddenDrift"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "maxLength": 200
        },
        "shape": {
          "type": "string",
          "maxLength": 1000
        },
        "material": {
          "type": "string",
          "maxLength": 1000
        },
        "color": {
          "type": "string",
          "maxLength": 200
        },
        "dimensionsText": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 500
            },
            {
              "type": "null"
            }
          ]
        },
        "packaging": {
          "type": "string",
          "maxLength": 1000
        },
        "logoAssetRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/AssetRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "forbiddenDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 500
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "CharacterPin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "libraryId",
        "assetId",
        "version",
        "hash",
        "lookId"
      ],
      "properties": {
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
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
    "Subject": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "characterPin",
        "portraitConsentRef",
        "guardianConsentRef",
        "rightsEpoch"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "fictionalHuman",
            "realAdult",
            "realMinor",
            "animal",
            "product"
          ]
        },
        "characterPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/CharacterPin"
            },
            {
              "type": "null"
            }
          ]
        },
        "portraitConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "guardianConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "Budget": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "currency",
        "maxMicros"
      ],
      "properties": {
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$"
        },
        "maxMicros": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "VerticalBrief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "purpose",
        "inputModes",
        "targetDuration",
        "aspect",
        "allowNewGeneration",
        "productId",
        "scriptBindingId",
        "subjectIds",
        "sourceBindings",
        "factIds",
        "recipeRefs",
        "voiceMode",
        "desiredOutcome",
        "userConstraints",
        "maxGeneratedSeconds",
        "budget",
        "lockedFieldRefs"
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
        "purpose": {
          "enum": [
            "marketing",
            "showcase",
            "story",
            "social",
            "tutorial",
            "musicVisual"
          ]
        },
        "inputModes": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "script",
              "mediaMontage",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1",
            "4:3",
            "3:4"
          ]
        },
        "allowNewGeneration": {
          "type": "boolean",
          "default": false
        },
        "productId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "scriptBindingId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "sourceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SourceBinding"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "recipeRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "voiceMode": {
          "enum": [
            "none",
            "captions",
            "uploadedAudio",
            "nativeTrial"
          ]
        },
        "desiredOutcome": {
          "type": "string",
          "maxLength": 2000
        },
        "userConstraints": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 0,
          "maxItems": 64
        },
        "maxGeneratedSeconds": {
          "$ref": "#/$defs/Time"
        },
        "budget": {
          "$ref": "#/$defs/Budget"
        },
        "lockedFieldRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "Override": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "baseTemplateHash",
        "text",
        "reviewState",
        "reviewRef"
      ],
      "properties": {
        "baseTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "reviewState": {
          "enum": [
            "unreviewed",
            "confirmed"
          ]
        },
        "reviewRef": {
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
    "Variables": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "maxProperties": 64,
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000,
            "maximum": 1000000
          },
          {
            "type": "boolean"
          }
        ]
      }
    },
    "ShotExecution": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "route",
        "profileRef",
        "sourceBindingIds",
        "subjectIds",
        "recipeRef",
        "templateRef",
        "variables",
        "factIds",
        "skillRefs",
        "targetRange",
        "providerDurationSeconds",
        "candidateCount",
        "promptOverride",
        "outputContract",
        "lockedPaths"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "route": {
          "enum": [
            "renderExisting",
            "t2v",
            "i2v",
            "firstLast",
            "nativeContinue",
            "tailFrameBridge",
            "referenceSynthesis",
            "motionTransfer",
            "videoRestyle"
          ]
        },
        "profileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "recipeRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "variables": {
          "$ref": "#/$defs/Variables"
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "targetRange": {
          "$ref": "#/$defs/Range"
        },
        "providerDurationSeconds": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 2,
              "maximum": 30
            },
            {
              "type": "null"
            }
          ]
        },
        "candidateCount": {
          "type": "integer",
          "minimum": 1,
          "maximum": 4
        },
        "promptOverride": {
          "anyOf": [
            {
              "$ref": "#/$defs/Override"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputContract": {
          "enum": [
            "newClip",
            "inputPlusContinuation",
            "existingAssets",
            "approxContinuation",
            "motionRemap"
          ]
        },
        "lockedPaths": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "SlotSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "role",
        "mediaKinds",
        "min",
        "max",
        "subjectMin",
        "subjectMax"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "$ref": "#/$defs/Id"
        },
        "mediaKinds": {
          "type": "array",
          "items": {
            "enum": [
              "image",
              "video",
              "audio",
              "text",
              "mask"
            ]
          },
          "minItems": 1,
          "maxItems": 5
        },
        "min": {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000
        },
        "max": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        },
        "subjectMin": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        },
        "subjectMax": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        }
      }
    },
    "ParameterSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "type",
        "required",
        "enumValues",
        "min",
        "max",
        "defaultValue"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "string",
            "number",
            "boolean",
            "enum"
          ]
        },
        "required": {
          "type": "boolean"
        },
        "enumValues": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 64
        },
        "min": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "max": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "defaultValue": {
          "anyOf": [
            {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 2000
                },
                {
                  "type": "number",
                  "minimum": -1000000,
                  "maximum": 1000000
                },
                {
                  "type": "boolean"
                }
              ]
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "RecipeStep": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "phase",
        "skillRef",
        "promptProgramRef",
        "dependsOn"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "phase": {
          "enum": [
            "preflight",
            "analyze",
            "plan",
            "confirm",
            "compile",
            "generate",
            "qa",
            "edit",
            "deliver"
          ]
        },
        "skillRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "promptProgramRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "PlayRecipe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "kind",
        "slotSpecs",
        "parameterSpecs",
        "allowedRoutes",
        "requiredGates",
        "steps",
        "skillRefs",
        "qaChecks",
        "example",
        "status",
        "replacementRef",
        "requiresExplicitUpgrade",
        "licenseRef"
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
          "$ref": "#/$defs/Semver"
        },
        "kind": {
          "enum": [
            "hug",
            "miniature",
            "animalHumanized",
            "babyDance"
          ]
        },
        "slotSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SlotSpec"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "parameterSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterSpec"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "allowedRoutes": {
          "type": "array",
          "items": {
            "enum": [
              "i2v",
              "referenceSynthesis",
              "motionTransfer",
              "renderExisting"
            ]
          },
          "minItems": 1,
          "maxItems": 4
        },
        "requiredGates": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/RecipeStep"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "qaChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 1,
          "maxItems": 32
        },
        "example": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "synthetic",
            "coverHash",
            "exampleInputHashes",
            "licenseRef"
          ],
          "properties": {
            "synthetic": {
              "const": true
            },
            "coverHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "exampleInputHashes": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Hash"
              },
              "minItems": 0,
              "maxItems": 16
            },
            "licenseRef": {
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
        "status": {
          "enum": [
            "active",
            "deprecated",
            "withdrawn"
          ]
        },
        "replacementRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "requiresExplicitUpgrade": {
          "const": true
        },
        "licenseRef": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Token": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "text"
          ],
          "properties": {
            "kind": {
              "const": "literal"
            },
            "text": {
              "type": "string",
              "maxLength": 10000
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "key"
          ],
          "properties": {
            "kind": {
              "const": "slot"
            },
            "key": {
              "$ref": "#/$defs/Id"
            }
          }
        }
      ]
    },
    "ProgramVariable": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "required",
        "maxChars",
        "source"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "required": {
          "type": "boolean"
        },
        "maxChars": {
          "type": "integer",
          "minimum": 1,
          "maximum": 10000
        },
        "source": {
          "enum": [
            "user",
            "fact",
            "analysis",
            "subject",
            "skill"
          ]
        }
      }
    },
    "ParameterBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "slot",
        "providerField",
        "handling"
      ],
      "properties": {
        "slot": {
          "$ref": "#/$defs/Id"
        },
        "providerField": {
          "$ref": "#/$defs/Id"
        },
        "handling": {
          "enum": [
            "hard",
            "soft",
            "unsupported"
          ]
        }
      }
    },
    "PromptProgram": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "routeModes",
        "variables",
        "positive",
        "negative",
        "parameterBindings",
        "outputScope"
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
          "$ref": "#/$defs/Semver"
        },
        "routeModes": {
          "type": "array",
          "items": {
            "enum": [
              "renderExisting",
              "t2v",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "variables": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProgramVariable"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "positive": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 1,
          "maxItems": 128
        },
        "negative": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "parameterBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterBinding"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputScope": {
          "enum": [
            "planning",
            "singleShot",
            "editPlan"
          ]
        }
      }
    },
    "WorkflowSnapshot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "brief",
        "products",
        "facts",
        "subjects",
        "shots",
        "recipePins",
        "templatePins",
        "analysisArtifactHashes",
        "stageRefs",
        "editPlanHash",
        "createdAt",
        "originProject",
        "templateCompilerVersion"
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
        "brief": {
          "$ref": "#/$defs/VerticalBrief"
        },
        "products": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductIdentity"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "facts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductFact"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "subjects": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Subject"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "shots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ShotExecution"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "recipePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "templatePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "analysisArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "stageRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "editPlanHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "originProject": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "projectId",
            "revision"
          ],
          "properties": {
            "projectId": {
              "$ref": "#/$defs/Id"
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "templateCompilerVersion": {
          "$ref": "#/$defs/Semver"
        }
      }
    },
    "RunError": {
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
    "WorkflowRun": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "workflowSnapshotHash",
        "projectId",
        "baseRevision",
        "state",
        "recordVersion",
        "activeNodeIds",
        "cancelEpoch",
        "error",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "state": {
          "enum": [
            "draft",
            "preflighting",
            "analyzing",
            "planning",
            "awaitingPlan",
            "compiling",
            "awaitingApproval",
            "readyToSubmit",
            "generating",
            "awaitingQA",
            "readyToApply",
            "applying",
            "applied",
            "delivering",
            "completed",
            "needsRebase",
            "blocked",
            "failed",
            "cancelRequested",
            "cancelled"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "activeNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "error": {
          "anyOf": [
            {
              "$ref": "#/$defs/RunError"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "updatedAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "ClipBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "clipId",
        "shotPlanId",
        "candidateId",
        "sourceVersion"
      ],
      "properties": {
        "clipId": {
          "$ref": "#/$defs/Id"
        },
        "shotPlanId": {
          "$ref": "#/$defs/Id"
        },
        "candidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "ProjectWorkflowLink": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "namespace",
        "projectId",
        "projectRevision",
        "projectContentHash",
        "workflowSnapshotHash",
        "acceptedCommandId",
        "originArchiveId",
        "clipBindings"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "projectRevision": {
          "$ref": "#/$defs/U64"
        },
        "projectContentHash": {
          "$ref": "#/$defs/Hash"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "acceptedCommandId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "originArchiveId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "clipBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ClipBinding"
          },
          "minItems": 0,
          "maxItems": 10000
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/vertical/ShotExecution-1.0.0.json",
  "$ref": "#/$defs/ShotExecution",
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
    "Semver": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
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
          "$ref": "#/$defs/Semver"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "AssetRef": {
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
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Crop": {
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
          "maximum": 1
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        }
      }
    },
    "SourceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "role",
        "ordinal",
        "asset",
        "range",
        "crop",
        "audioUse",
        "subjectIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "productFront",
            "productDetail",
            "firstFrame",
            "lastFrame",
            "sourceVideo",
            "motionVideo",
            "referenceImage",
            "referenceVideo",
            "montage",
            "script",
            "voice",
            "music",
            "mask",
            "contextImage"
          ]
        },
        "ordinal": {
          "type": "integer",
          "minimum": 0,
          "maximum": 999
        },
        "asset": {
          "$ref": "#/$defs/AssetRef"
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
        "crop": {
          "anyOf": [
            {
              "$ref": "#/$defs/Crop"
            },
            {
              "type": "null"
            }
          ]
        },
        "audioUse": {
          "enum": [
            "strip",
            "use",
            "voiceRef"
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        }
      }
    },
    "ProductFact": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "kind",
        "text",
        "sourceEvidenceHashes",
        "confirmed",
        "confirmationRef",
        "expiresAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "price",
            "specification",
            "feature",
            "offer",
            "claim",
            "cta"
          ]
        },
        "text": {
          "type": "string",
          "maxLength": 2000
        },
        "sourceEvidenceHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "confirmed": {
          "type": "boolean"
        },
        "confirmationRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "expiresAt": {
          "anyOf": [
            {
              "$ref": "#/$defs/Timestamp"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ProductIdentity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "name",
        "shape",
        "material",
        "color",
        "dimensionsText",
        "packaging",
        "logoAssetRef",
        "referenceBindingIds",
        "factIds",
        "forbiddenDrift"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "maxLength": 200
        },
        "shape": {
          "type": "string",
          "maxLength": 1000
        },
        "material": {
          "type": "string",
          "maxLength": 1000
        },
        "color": {
          "type": "string",
          "maxLength": 200
        },
        "dimensionsText": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 500
            },
            {
              "type": "null"
            }
          ]
        },
        "packaging": {
          "type": "string",
          "maxLength": 1000
        },
        "logoAssetRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/AssetRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "forbiddenDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 500
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "CharacterPin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "libraryId",
        "assetId",
        "version",
        "hash",
        "lookId"
      ],
      "properties": {
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
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
    "Subject": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "characterPin",
        "portraitConsentRef",
        "guardianConsentRef",
        "rightsEpoch"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "fictionalHuman",
            "realAdult",
            "realMinor",
            "animal",
            "product"
          ]
        },
        "characterPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/CharacterPin"
            },
            {
              "type": "null"
            }
          ]
        },
        "portraitConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "guardianConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "Budget": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "currency",
        "maxMicros"
      ],
      "properties": {
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$"
        },
        "maxMicros": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "VerticalBrief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "purpose",
        "inputModes",
        "targetDuration",
        "aspect",
        "allowNewGeneration",
        "productId",
        "scriptBindingId",
        "subjectIds",
        "sourceBindings",
        "factIds",
        "recipeRefs",
        "voiceMode",
        "desiredOutcome",
        "userConstraints",
        "maxGeneratedSeconds",
        "budget",
        "lockedFieldRefs"
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
        "purpose": {
          "enum": [
            "marketing",
            "showcase",
            "story",
            "social",
            "tutorial",
            "musicVisual"
          ]
        },
        "inputModes": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "script",
              "mediaMontage",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1",
            "4:3",
            "3:4"
          ]
        },
        "allowNewGeneration": {
          "type": "boolean",
          "default": false
        },
        "productId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "scriptBindingId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "sourceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SourceBinding"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "recipeRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "voiceMode": {
          "enum": [
            "none",
            "captions",
            "uploadedAudio",
            "nativeTrial"
          ]
        },
        "desiredOutcome": {
          "type": "string",
          "maxLength": 2000
        },
        "userConstraints": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 0,
          "maxItems": 64
        },
        "maxGeneratedSeconds": {
          "$ref": "#/$defs/Time"
        },
        "budget": {
          "$ref": "#/$defs/Budget"
        },
        "lockedFieldRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "Override": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "baseTemplateHash",
        "text",
        "reviewState",
        "reviewRef"
      ],
      "properties": {
        "baseTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "reviewState": {
          "enum": [
            "unreviewed",
            "confirmed"
          ]
        },
        "reviewRef": {
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
    "Variables": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "maxProperties": 64,
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000,
            "maximum": 1000000
          },
          {
            "type": "boolean"
          }
        ]
      }
    },
    "ShotExecution": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "route",
        "profileRef",
        "sourceBindingIds",
        "subjectIds",
        "recipeRef",
        "templateRef",
        "variables",
        "factIds",
        "skillRefs",
        "targetRange",
        "providerDurationSeconds",
        "candidateCount",
        "promptOverride",
        "outputContract",
        "lockedPaths"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "route": {
          "enum": [
            "renderExisting",
            "t2v",
            "i2v",
            "firstLast",
            "nativeContinue",
            "tailFrameBridge",
            "referenceSynthesis",
            "motionTransfer",
            "videoRestyle"
          ]
        },
        "profileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "recipeRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "variables": {
          "$ref": "#/$defs/Variables"
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "targetRange": {
          "$ref": "#/$defs/Range"
        },
        "providerDurationSeconds": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 2,
              "maximum": 30
            },
            {
              "type": "null"
            }
          ]
        },
        "candidateCount": {
          "type": "integer",
          "minimum": 1,
          "maximum": 4
        },
        "promptOverride": {
          "anyOf": [
            {
              "$ref": "#/$defs/Override"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputContract": {
          "enum": [
            "newClip",
            "inputPlusContinuation",
            "existingAssets",
            "approxContinuation",
            "motionRemap"
          ]
        },
        "lockedPaths": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "SlotSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "role",
        "mediaKinds",
        "min",
        "max",
        "subjectMin",
        "subjectMax"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "$ref": "#/$defs/Id"
        },
        "mediaKinds": {
          "type": "array",
          "items": {
            "enum": [
              "image",
              "video",
              "audio",
              "text",
              "mask"
            ]
          },
          "minItems": 1,
          "maxItems": 5
        },
        "min": {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000
        },
        "max": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        },
        "subjectMin": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        },
        "subjectMax": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        }
      }
    },
    "ParameterSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "type",
        "required",
        "enumValues",
        "min",
        "max",
        "defaultValue"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "string",
            "number",
            "boolean",
            "enum"
          ]
        },
        "required": {
          "type": "boolean"
        },
        "enumValues": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 64
        },
        "min": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "max": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "defaultValue": {
          "anyOf": [
            {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 2000
                },
                {
                  "type": "number",
                  "minimum": -1000000,
                  "maximum": 1000000
                },
                {
                  "type": "boolean"
                }
              ]
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "RecipeStep": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "phase",
        "skillRef",
        "promptProgramRef",
        "dependsOn"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "phase": {
          "enum": [
            "preflight",
            "analyze",
            "plan",
            "confirm",
            "compile",
            "generate",
            "qa",
            "edit",
            "deliver"
          ]
        },
        "skillRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "promptProgramRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "PlayRecipe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "kind",
        "slotSpecs",
        "parameterSpecs",
        "allowedRoutes",
        "requiredGates",
        "steps",
        "skillRefs",
        "qaChecks",
        "example",
        "status",
        "replacementRef",
        "requiresExplicitUpgrade",
        "licenseRef"
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
          "$ref": "#/$defs/Semver"
        },
        "kind": {
          "enum": [
            "hug",
            "miniature",
            "animalHumanized",
            "babyDance"
          ]
        },
        "slotSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SlotSpec"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "parameterSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterSpec"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "allowedRoutes": {
          "type": "array",
          "items": {
            "enum": [
              "i2v",
              "referenceSynthesis",
              "motionTransfer",
              "renderExisting"
            ]
          },
          "minItems": 1,
          "maxItems": 4
        },
        "requiredGates": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/RecipeStep"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "qaChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 1,
          "maxItems": 32
        },
        "example": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "synthetic",
            "coverHash",
            "exampleInputHashes",
            "licenseRef"
          ],
          "properties": {
            "synthetic": {
              "const": true
            },
            "coverHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "exampleInputHashes": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Hash"
              },
              "minItems": 0,
              "maxItems": 16
            },
            "licenseRef": {
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
        "status": {
          "enum": [
            "active",
            "deprecated",
            "withdrawn"
          ]
        },
        "replacementRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "requiresExplicitUpgrade": {
          "const": true
        },
        "licenseRef": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Token": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "text"
          ],
          "properties": {
            "kind": {
              "const": "literal"
            },
            "text": {
              "type": "string",
              "maxLength": 10000
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "key"
          ],
          "properties": {
            "kind": {
              "const": "slot"
            },
            "key": {
              "$ref": "#/$defs/Id"
            }
          }
        }
      ]
    },
    "ProgramVariable": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "required",
        "maxChars",
        "source"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "required": {
          "type": "boolean"
        },
        "maxChars": {
          "type": "integer",
          "minimum": 1,
          "maximum": 10000
        },
        "source": {
          "enum": [
            "user",
            "fact",
            "analysis",
            "subject",
            "skill"
          ]
        }
      }
    },
    "ParameterBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "slot",
        "providerField",
        "handling"
      ],
      "properties": {
        "slot": {
          "$ref": "#/$defs/Id"
        },
        "providerField": {
          "$ref": "#/$defs/Id"
        },
        "handling": {
          "enum": [
            "hard",
            "soft",
            "unsupported"
          ]
        }
      }
    },
    "PromptProgram": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "routeModes",
        "variables",
        "positive",
        "negative",
        "parameterBindings",
        "outputScope"
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
          "$ref": "#/$defs/Semver"
        },
        "routeModes": {
          "type": "array",
          "items": {
            "enum": [
              "renderExisting",
              "t2v",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "variables": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProgramVariable"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "positive": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 1,
          "maxItems": 128
        },
        "negative": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "parameterBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterBinding"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputScope": {
          "enum": [
            "planning",
            "singleShot",
            "editPlan"
          ]
        }
      }
    },
    "WorkflowSnapshot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "brief",
        "products",
        "facts",
        "subjects",
        "shots",
        "recipePins",
        "templatePins",
        "analysisArtifactHashes",
        "stageRefs",
        "editPlanHash",
        "createdAt",
        "originProject",
        "templateCompilerVersion"
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
        "brief": {
          "$ref": "#/$defs/VerticalBrief"
        },
        "products": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductIdentity"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "facts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductFact"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "subjects": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Subject"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "shots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ShotExecution"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "recipePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "templatePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "analysisArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "stageRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "editPlanHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "originProject": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "projectId",
            "revision"
          ],
          "properties": {
            "projectId": {
              "$ref": "#/$defs/Id"
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "templateCompilerVersion": {
          "$ref": "#/$defs/Semver"
        }
      }
    },
    "RunError": {
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
    "WorkflowRun": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "workflowSnapshotHash",
        "projectId",
        "baseRevision",
        "state",
        "recordVersion",
        "activeNodeIds",
        "cancelEpoch",
        "error",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "state": {
          "enum": [
            "draft",
            "preflighting",
            "analyzing",
            "planning",
            "awaitingPlan",
            "compiling",
            "awaitingApproval",
            "readyToSubmit",
            "generating",
            "awaitingQA",
            "readyToApply",
            "applying",
            "applied",
            "delivering",
            "completed",
            "needsRebase",
            "blocked",
            "failed",
            "cancelRequested",
            "cancelled"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "activeNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "error": {
          "anyOf": [
            {
              "$ref": "#/$defs/RunError"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "updatedAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "ClipBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "clipId",
        "shotPlanId",
        "candidateId",
        "sourceVersion"
      ],
      "properties": {
        "clipId": {
          "$ref": "#/$defs/Id"
        },
        "shotPlanId": {
          "$ref": "#/$defs/Id"
        },
        "candidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "ProjectWorkflowLink": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "namespace",
        "projectId",
        "projectRevision",
        "projectContentHash",
        "workflowSnapshotHash",
        "acceptedCommandId",
        "originArchiveId",
        "clipBindings"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "projectRevision": {
          "$ref": "#/$defs/U64"
        },
        "projectContentHash": {
          "$ref": "#/$defs/Hash"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "acceptedCommandId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "originArchiveId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "clipBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ClipBinding"
          },
          "minItems": 0,
          "maxItems": 10000
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/vertical/PlayRecipe-1.0.0.json",
  "$ref": "#/$defs/PlayRecipe",
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
    "Semver": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
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
          "$ref": "#/$defs/Semver"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "AssetRef": {
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
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Crop": {
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
          "maximum": 1
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        }
      }
    },
    "SourceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "role",
        "ordinal",
        "asset",
        "range",
        "crop",
        "audioUse",
        "subjectIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "productFront",
            "productDetail",
            "firstFrame",
            "lastFrame",
            "sourceVideo",
            "motionVideo",
            "referenceImage",
            "referenceVideo",
            "montage",
            "script",
            "voice",
            "music",
            "mask",
            "contextImage"
          ]
        },
        "ordinal": {
          "type": "integer",
          "minimum": 0,
          "maximum": 999
        },
        "asset": {
          "$ref": "#/$defs/AssetRef"
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
        "crop": {
          "anyOf": [
            {
              "$ref": "#/$defs/Crop"
            },
            {
              "type": "null"
            }
          ]
        },
        "audioUse": {
          "enum": [
            "strip",
            "use",
            "voiceRef"
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        }
      }
    },
    "ProductFact": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "kind",
        "text",
        "sourceEvidenceHashes",
        "confirmed",
        "confirmationRef",
        "expiresAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "price",
            "specification",
            "feature",
            "offer",
            "claim",
            "cta"
          ]
        },
        "text": {
          "type": "string",
          "maxLength": 2000
        },
        "sourceEvidenceHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "confirmed": {
          "type": "boolean"
        },
        "confirmationRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "expiresAt": {
          "anyOf": [
            {
              "$ref": "#/$defs/Timestamp"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ProductIdentity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "name",
        "shape",
        "material",
        "color",
        "dimensionsText",
        "packaging",
        "logoAssetRef",
        "referenceBindingIds",
        "factIds",
        "forbiddenDrift"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "maxLength": 200
        },
        "shape": {
          "type": "string",
          "maxLength": 1000
        },
        "material": {
          "type": "string",
          "maxLength": 1000
        },
        "color": {
          "type": "string",
          "maxLength": 200
        },
        "dimensionsText": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 500
            },
            {
              "type": "null"
            }
          ]
        },
        "packaging": {
          "type": "string",
          "maxLength": 1000
        },
        "logoAssetRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/AssetRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "forbiddenDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 500
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "CharacterPin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "libraryId",
        "assetId",
        "version",
        "hash",
        "lookId"
      ],
      "properties": {
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
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
    "Subject": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "characterPin",
        "portraitConsentRef",
        "guardianConsentRef",
        "rightsEpoch"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "fictionalHuman",
            "realAdult",
            "realMinor",
            "animal",
            "product"
          ]
        },
        "characterPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/CharacterPin"
            },
            {
              "type": "null"
            }
          ]
        },
        "portraitConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "guardianConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "Budget": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "currency",
        "maxMicros"
      ],
      "properties": {
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$"
        },
        "maxMicros": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "VerticalBrief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "purpose",
        "inputModes",
        "targetDuration",
        "aspect",
        "allowNewGeneration",
        "productId",
        "scriptBindingId",
        "subjectIds",
        "sourceBindings",
        "factIds",
        "recipeRefs",
        "voiceMode",
        "desiredOutcome",
        "userConstraints",
        "maxGeneratedSeconds",
        "budget",
        "lockedFieldRefs"
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
        "purpose": {
          "enum": [
            "marketing",
            "showcase",
            "story",
            "social",
            "tutorial",
            "musicVisual"
          ]
        },
        "inputModes": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "script",
              "mediaMontage",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1",
            "4:3",
            "3:4"
          ]
        },
        "allowNewGeneration": {
          "type": "boolean",
          "default": false
        },
        "productId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "scriptBindingId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "sourceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SourceBinding"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "recipeRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "voiceMode": {
          "enum": [
            "none",
            "captions",
            "uploadedAudio",
            "nativeTrial"
          ]
        },
        "desiredOutcome": {
          "type": "string",
          "maxLength": 2000
        },
        "userConstraints": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 0,
          "maxItems": 64
        },
        "maxGeneratedSeconds": {
          "$ref": "#/$defs/Time"
        },
        "budget": {
          "$ref": "#/$defs/Budget"
        },
        "lockedFieldRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "Override": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "baseTemplateHash",
        "text",
        "reviewState",
        "reviewRef"
      ],
      "properties": {
        "baseTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "reviewState": {
          "enum": [
            "unreviewed",
            "confirmed"
          ]
        },
        "reviewRef": {
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
    "Variables": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "maxProperties": 64,
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000,
            "maximum": 1000000
          },
          {
            "type": "boolean"
          }
        ]
      }
    },
    "ShotExecution": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "route",
        "profileRef",
        "sourceBindingIds",
        "subjectIds",
        "recipeRef",
        "templateRef",
        "variables",
        "factIds",
        "skillRefs",
        "targetRange",
        "providerDurationSeconds",
        "candidateCount",
        "promptOverride",
        "outputContract",
        "lockedPaths"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "route": {
          "enum": [
            "renderExisting",
            "t2v",
            "i2v",
            "firstLast",
            "nativeContinue",
            "tailFrameBridge",
            "referenceSynthesis",
            "motionTransfer",
            "videoRestyle"
          ]
        },
        "profileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "recipeRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "variables": {
          "$ref": "#/$defs/Variables"
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "targetRange": {
          "$ref": "#/$defs/Range"
        },
        "providerDurationSeconds": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 2,
              "maximum": 30
            },
            {
              "type": "null"
            }
          ]
        },
        "candidateCount": {
          "type": "integer",
          "minimum": 1,
          "maximum": 4
        },
        "promptOverride": {
          "anyOf": [
            {
              "$ref": "#/$defs/Override"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputContract": {
          "enum": [
            "newClip",
            "inputPlusContinuation",
            "existingAssets",
            "approxContinuation",
            "motionRemap"
          ]
        },
        "lockedPaths": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "SlotSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "role",
        "mediaKinds",
        "min",
        "max",
        "subjectMin",
        "subjectMax"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "$ref": "#/$defs/Id"
        },
        "mediaKinds": {
          "type": "array",
          "items": {
            "enum": [
              "image",
              "video",
              "audio",
              "text",
              "mask"
            ]
          },
          "minItems": 1,
          "maxItems": 5
        },
        "min": {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000
        },
        "max": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        },
        "subjectMin": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        },
        "subjectMax": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        }
      }
    },
    "ParameterSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "type",
        "required",
        "enumValues",
        "min",
        "max",
        "defaultValue"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "string",
            "number",
            "boolean",
            "enum"
          ]
        },
        "required": {
          "type": "boolean"
        },
        "enumValues": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 64
        },
        "min": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "max": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "defaultValue": {
          "anyOf": [
            {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 2000
                },
                {
                  "type": "number",
                  "minimum": -1000000,
                  "maximum": 1000000
                },
                {
                  "type": "boolean"
                }
              ]
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "RecipeStep": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "phase",
        "skillRef",
        "promptProgramRef",
        "dependsOn"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "phase": {
          "enum": [
            "preflight",
            "analyze",
            "plan",
            "confirm",
            "compile",
            "generate",
            "qa",
            "edit",
            "deliver"
          ]
        },
        "skillRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "promptProgramRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "PlayRecipe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "kind",
        "slotSpecs",
        "parameterSpecs",
        "allowedRoutes",
        "requiredGates",
        "steps",
        "skillRefs",
        "qaChecks",
        "example",
        "status",
        "replacementRef",
        "requiresExplicitUpgrade",
        "licenseRef"
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
          "$ref": "#/$defs/Semver"
        },
        "kind": {
          "enum": [
            "hug",
            "miniature",
            "animalHumanized",
            "babyDance"
          ]
        },
        "slotSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SlotSpec"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "parameterSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterSpec"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "allowedRoutes": {
          "type": "array",
          "items": {
            "enum": [
              "i2v",
              "referenceSynthesis",
              "motionTransfer",
              "renderExisting"
            ]
          },
          "minItems": 1,
          "maxItems": 4
        },
        "requiredGates": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/RecipeStep"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "qaChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 1,
          "maxItems": 32
        },
        "example": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "synthetic",
            "coverHash",
            "exampleInputHashes",
            "licenseRef"
          ],
          "properties": {
            "synthetic": {
              "const": true
            },
            "coverHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "exampleInputHashes": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Hash"
              },
              "minItems": 0,
              "maxItems": 16
            },
            "licenseRef": {
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
        "status": {
          "enum": [
            "active",
            "deprecated",
            "withdrawn"
          ]
        },
        "replacementRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "requiresExplicitUpgrade": {
          "const": true
        },
        "licenseRef": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Token": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "text"
          ],
          "properties": {
            "kind": {
              "const": "literal"
            },
            "text": {
              "type": "string",
              "maxLength": 10000
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "key"
          ],
          "properties": {
            "kind": {
              "const": "slot"
            },
            "key": {
              "$ref": "#/$defs/Id"
            }
          }
        }
      ]
    },
    "ProgramVariable": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "required",
        "maxChars",
        "source"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "required": {
          "type": "boolean"
        },
        "maxChars": {
          "type": "integer",
          "minimum": 1,
          "maximum": 10000
        },
        "source": {
          "enum": [
            "user",
            "fact",
            "analysis",
            "subject",
            "skill"
          ]
        }
      }
    },
    "ParameterBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "slot",
        "providerField",
        "handling"
      ],
      "properties": {
        "slot": {
          "$ref": "#/$defs/Id"
        },
        "providerField": {
          "$ref": "#/$defs/Id"
        },
        "handling": {
          "enum": [
            "hard",
            "soft",
            "unsupported"
          ]
        }
      }
    },
    "PromptProgram": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "routeModes",
        "variables",
        "positive",
        "negative",
        "parameterBindings",
        "outputScope"
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
          "$ref": "#/$defs/Semver"
        },
        "routeModes": {
          "type": "array",
          "items": {
            "enum": [
              "renderExisting",
              "t2v",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "variables": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProgramVariable"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "positive": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 1,
          "maxItems": 128
        },
        "negative": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "parameterBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterBinding"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputScope": {
          "enum": [
            "planning",
            "singleShot",
            "editPlan"
          ]
        }
      }
    },
    "WorkflowSnapshot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "brief",
        "products",
        "facts",
        "subjects",
        "shots",
        "recipePins",
        "templatePins",
        "analysisArtifactHashes",
        "stageRefs",
        "editPlanHash",
        "createdAt",
        "originProject",
        "templateCompilerVersion"
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
        "brief": {
          "$ref": "#/$defs/VerticalBrief"
        },
        "products": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductIdentity"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "facts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductFact"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "subjects": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Subject"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "shots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ShotExecution"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "recipePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "templatePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "analysisArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "stageRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "editPlanHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "originProject": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "projectId",
            "revision"
          ],
          "properties": {
            "projectId": {
              "$ref": "#/$defs/Id"
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "templateCompilerVersion": {
          "$ref": "#/$defs/Semver"
        }
      }
    },
    "RunError": {
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
    "WorkflowRun": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "workflowSnapshotHash",
        "projectId",
        "baseRevision",
        "state",
        "recordVersion",
        "activeNodeIds",
        "cancelEpoch",
        "error",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "state": {
          "enum": [
            "draft",
            "preflighting",
            "analyzing",
            "planning",
            "awaitingPlan",
            "compiling",
            "awaitingApproval",
            "readyToSubmit",
            "generating",
            "awaitingQA",
            "readyToApply",
            "applying",
            "applied",
            "delivering",
            "completed",
            "needsRebase",
            "blocked",
            "failed",
            "cancelRequested",
            "cancelled"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "activeNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "error": {
          "anyOf": [
            {
              "$ref": "#/$defs/RunError"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "updatedAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "ClipBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "clipId",
        "shotPlanId",
        "candidateId",
        "sourceVersion"
      ],
      "properties": {
        "clipId": {
          "$ref": "#/$defs/Id"
        },
        "shotPlanId": {
          "$ref": "#/$defs/Id"
        },
        "candidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "ProjectWorkflowLink": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "namespace",
        "projectId",
        "projectRevision",
        "projectContentHash",
        "workflowSnapshotHash",
        "acceptedCommandId",
        "originArchiveId",
        "clipBindings"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "projectRevision": {
          "$ref": "#/$defs/U64"
        },
        "projectContentHash": {
          "$ref": "#/$defs/Hash"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "acceptedCommandId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "originArchiveId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "clipBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ClipBinding"
          },
          "minItems": 0,
          "maxItems": 10000
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/vertical/PromptProgram-1.0.0.json",
  "$ref": "#/$defs/PromptProgram",
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
    "Semver": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
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
          "$ref": "#/$defs/Semver"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "AssetRef": {
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
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Crop": {
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
          "maximum": 1
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        }
      }
    },
    "SourceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "role",
        "ordinal",
        "asset",
        "range",
        "crop",
        "audioUse",
        "subjectIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "productFront",
            "productDetail",
            "firstFrame",
            "lastFrame",
            "sourceVideo",
            "motionVideo",
            "referenceImage",
            "referenceVideo",
            "montage",
            "script",
            "voice",
            "music",
            "mask",
            "contextImage"
          ]
        },
        "ordinal": {
          "type": "integer",
          "minimum": 0,
          "maximum": 999
        },
        "asset": {
          "$ref": "#/$defs/AssetRef"
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
        "crop": {
          "anyOf": [
            {
              "$ref": "#/$defs/Crop"
            },
            {
              "type": "null"
            }
          ]
        },
        "audioUse": {
          "enum": [
            "strip",
            "use",
            "voiceRef"
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        }
      }
    },
    "ProductFact": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "kind",
        "text",
        "sourceEvidenceHashes",
        "confirmed",
        "confirmationRef",
        "expiresAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "price",
            "specification",
            "feature",
            "offer",
            "claim",
            "cta"
          ]
        },
        "text": {
          "type": "string",
          "maxLength": 2000
        },
        "sourceEvidenceHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "confirmed": {
          "type": "boolean"
        },
        "confirmationRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "expiresAt": {
          "anyOf": [
            {
              "$ref": "#/$defs/Timestamp"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ProductIdentity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "name",
        "shape",
        "material",
        "color",
        "dimensionsText",
        "packaging",
        "logoAssetRef",
        "referenceBindingIds",
        "factIds",
        "forbiddenDrift"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "maxLength": 200
        },
        "shape": {
          "type": "string",
          "maxLength": 1000
        },
        "material": {
          "type": "string",
          "maxLength": 1000
        },
        "color": {
          "type": "string",
          "maxLength": 200
        },
        "dimensionsText": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 500
            },
            {
              "type": "null"
            }
          ]
        },
        "packaging": {
          "type": "string",
          "maxLength": 1000
        },
        "logoAssetRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/AssetRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "forbiddenDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 500
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "CharacterPin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "libraryId",
        "assetId",
        "version",
        "hash",
        "lookId"
      ],
      "properties": {
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
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
    "Subject": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "characterPin",
        "portraitConsentRef",
        "guardianConsentRef",
        "rightsEpoch"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "fictionalHuman",
            "realAdult",
            "realMinor",
            "animal",
            "product"
          ]
        },
        "characterPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/CharacterPin"
            },
            {
              "type": "null"
            }
          ]
        },
        "portraitConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "guardianConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "Budget": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "currency",
        "maxMicros"
      ],
      "properties": {
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$"
        },
        "maxMicros": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "VerticalBrief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "purpose",
        "inputModes",
        "targetDuration",
        "aspect",
        "allowNewGeneration",
        "productId",
        "scriptBindingId",
        "subjectIds",
        "sourceBindings",
        "factIds",
        "recipeRefs",
        "voiceMode",
        "desiredOutcome",
        "userConstraints",
        "maxGeneratedSeconds",
        "budget",
        "lockedFieldRefs"
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
        "purpose": {
          "enum": [
            "marketing",
            "showcase",
            "story",
            "social",
            "tutorial",
            "musicVisual"
          ]
        },
        "inputModes": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "script",
              "mediaMontage",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1",
            "4:3",
            "3:4"
          ]
        },
        "allowNewGeneration": {
          "type": "boolean",
          "default": false
        },
        "productId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "scriptBindingId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "sourceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SourceBinding"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "recipeRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "voiceMode": {
          "enum": [
            "none",
            "captions",
            "uploadedAudio",
            "nativeTrial"
          ]
        },
        "desiredOutcome": {
          "type": "string",
          "maxLength": 2000
        },
        "userConstraints": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 0,
          "maxItems": 64
        },
        "maxGeneratedSeconds": {
          "$ref": "#/$defs/Time"
        },
        "budget": {
          "$ref": "#/$defs/Budget"
        },
        "lockedFieldRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "Override": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "baseTemplateHash",
        "text",
        "reviewState",
        "reviewRef"
      ],
      "properties": {
        "baseTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "reviewState": {
          "enum": [
            "unreviewed",
            "confirmed"
          ]
        },
        "reviewRef": {
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
    "Variables": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "maxProperties": 64,
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000,
            "maximum": 1000000
          },
          {
            "type": "boolean"
          }
        ]
      }
    },
    "ShotExecution": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "route",
        "profileRef",
        "sourceBindingIds",
        "subjectIds",
        "recipeRef",
        "templateRef",
        "variables",
        "factIds",
        "skillRefs",
        "targetRange",
        "providerDurationSeconds",
        "candidateCount",
        "promptOverride",
        "outputContract",
        "lockedPaths"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "route": {
          "enum": [
            "renderExisting",
            "t2v",
            "i2v",
            "firstLast",
            "nativeContinue",
            "tailFrameBridge",
            "referenceSynthesis",
            "motionTransfer",
            "videoRestyle"
          ]
        },
        "profileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "recipeRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "variables": {
          "$ref": "#/$defs/Variables"
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "targetRange": {
          "$ref": "#/$defs/Range"
        },
        "providerDurationSeconds": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 2,
              "maximum": 30
            },
            {
              "type": "null"
            }
          ]
        },
        "candidateCount": {
          "type": "integer",
          "minimum": 1,
          "maximum": 4
        },
        "promptOverride": {
          "anyOf": [
            {
              "$ref": "#/$defs/Override"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputContract": {
          "enum": [
            "newClip",
            "inputPlusContinuation",
            "existingAssets",
            "approxContinuation",
            "motionRemap"
          ]
        },
        "lockedPaths": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "SlotSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "role",
        "mediaKinds",
        "min",
        "max",
        "subjectMin",
        "subjectMax"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "$ref": "#/$defs/Id"
        },
        "mediaKinds": {
          "type": "array",
          "items": {
            "enum": [
              "image",
              "video",
              "audio",
              "text",
              "mask"
            ]
          },
          "minItems": 1,
          "maxItems": 5
        },
        "min": {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000
        },
        "max": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        },
        "subjectMin": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        },
        "subjectMax": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        }
      }
    },
    "ParameterSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "type",
        "required",
        "enumValues",
        "min",
        "max",
        "defaultValue"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "string",
            "number",
            "boolean",
            "enum"
          ]
        },
        "required": {
          "type": "boolean"
        },
        "enumValues": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 64
        },
        "min": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "max": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "defaultValue": {
          "anyOf": [
            {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 2000
                },
                {
                  "type": "number",
                  "minimum": -1000000,
                  "maximum": 1000000
                },
                {
                  "type": "boolean"
                }
              ]
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "RecipeStep": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "phase",
        "skillRef",
        "promptProgramRef",
        "dependsOn"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "phase": {
          "enum": [
            "preflight",
            "analyze",
            "plan",
            "confirm",
            "compile",
            "generate",
            "qa",
            "edit",
            "deliver"
          ]
        },
        "skillRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "promptProgramRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "PlayRecipe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "kind",
        "slotSpecs",
        "parameterSpecs",
        "allowedRoutes",
        "requiredGates",
        "steps",
        "skillRefs",
        "qaChecks",
        "example",
        "status",
        "replacementRef",
        "requiresExplicitUpgrade",
        "licenseRef"
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
          "$ref": "#/$defs/Semver"
        },
        "kind": {
          "enum": [
            "hug",
            "miniature",
            "animalHumanized",
            "babyDance"
          ]
        },
        "slotSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SlotSpec"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "parameterSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterSpec"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "allowedRoutes": {
          "type": "array",
          "items": {
            "enum": [
              "i2v",
              "referenceSynthesis",
              "motionTransfer",
              "renderExisting"
            ]
          },
          "minItems": 1,
          "maxItems": 4
        },
        "requiredGates": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/RecipeStep"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "qaChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 1,
          "maxItems": 32
        },
        "example": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "synthetic",
            "coverHash",
            "exampleInputHashes",
            "licenseRef"
          ],
          "properties": {
            "synthetic": {
              "const": true
            },
            "coverHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "exampleInputHashes": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Hash"
              },
              "minItems": 0,
              "maxItems": 16
            },
            "licenseRef": {
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
        "status": {
          "enum": [
            "active",
            "deprecated",
            "withdrawn"
          ]
        },
        "replacementRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "requiresExplicitUpgrade": {
          "const": true
        },
        "licenseRef": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Token": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "text"
          ],
          "properties": {
            "kind": {
              "const": "literal"
            },
            "text": {
              "type": "string",
              "maxLength": 10000
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "key"
          ],
          "properties": {
            "kind": {
              "const": "slot"
            },
            "key": {
              "$ref": "#/$defs/Id"
            }
          }
        }
      ]
    },
    "ProgramVariable": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "required",
        "maxChars",
        "source"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "required": {
          "type": "boolean"
        },
        "maxChars": {
          "type": "integer",
          "minimum": 1,
          "maximum": 10000
        },
        "source": {
          "enum": [
            "user",
            "fact",
            "analysis",
            "subject",
            "skill"
          ]
        }
      }
    },
    "ParameterBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "slot",
        "providerField",
        "handling"
      ],
      "properties": {
        "slot": {
          "$ref": "#/$defs/Id"
        },
        "providerField": {
          "$ref": "#/$defs/Id"
        },
        "handling": {
          "enum": [
            "hard",
            "soft",
            "unsupported"
          ]
        }
      }
    },
    "PromptProgram": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "routeModes",
        "variables",
        "positive",
        "negative",
        "parameterBindings",
        "outputScope"
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
          "$ref": "#/$defs/Semver"
        },
        "routeModes": {
          "type": "array",
          "items": {
            "enum": [
              "renderExisting",
              "t2v",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "variables": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProgramVariable"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "positive": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 1,
          "maxItems": 128
        },
        "negative": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "parameterBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterBinding"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputScope": {
          "enum": [
            "planning",
            "singleShot",
            "editPlan"
          ]
        }
      }
    },
    "WorkflowSnapshot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "brief",
        "products",
        "facts",
        "subjects",
        "shots",
        "recipePins",
        "templatePins",
        "analysisArtifactHashes",
        "stageRefs",
        "editPlanHash",
        "createdAt",
        "originProject",
        "templateCompilerVersion"
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
        "brief": {
          "$ref": "#/$defs/VerticalBrief"
        },
        "products": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductIdentity"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "facts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductFact"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "subjects": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Subject"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "shots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ShotExecution"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "recipePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "templatePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "analysisArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "stageRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "editPlanHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "originProject": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "projectId",
            "revision"
          ],
          "properties": {
            "projectId": {
              "$ref": "#/$defs/Id"
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "templateCompilerVersion": {
          "$ref": "#/$defs/Semver"
        }
      }
    },
    "RunError": {
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
    "WorkflowRun": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "workflowSnapshotHash",
        "projectId",
        "baseRevision",
        "state",
        "recordVersion",
        "activeNodeIds",
        "cancelEpoch",
        "error",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "state": {
          "enum": [
            "draft",
            "preflighting",
            "analyzing",
            "planning",
            "awaitingPlan",
            "compiling",
            "awaitingApproval",
            "readyToSubmit",
            "generating",
            "awaitingQA",
            "readyToApply",
            "applying",
            "applied",
            "delivering",
            "completed",
            "needsRebase",
            "blocked",
            "failed",
            "cancelRequested",
            "cancelled"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "activeNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "error": {
          "anyOf": [
            {
              "$ref": "#/$defs/RunError"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "updatedAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "ClipBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "clipId",
        "shotPlanId",
        "candidateId",
        "sourceVersion"
      ],
      "properties": {
        "clipId": {
          "$ref": "#/$defs/Id"
        },
        "shotPlanId": {
          "$ref": "#/$defs/Id"
        },
        "candidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "ProjectWorkflowLink": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "namespace",
        "projectId",
        "projectRevision",
        "projectContentHash",
        "workflowSnapshotHash",
        "acceptedCommandId",
        "originArchiveId",
        "clipBindings"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "projectRevision": {
          "$ref": "#/$defs/U64"
        },
        "projectContentHash": {
          "$ref": "#/$defs/Hash"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "acceptedCommandId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "originArchiveId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "clipBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ClipBinding"
          },
          "minItems": 0,
          "maxItems": 10000
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/vertical/WorkflowSnapshot-1.0.0.json",
  "$ref": "#/$defs/WorkflowSnapshot",
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
    "Semver": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
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
          "$ref": "#/$defs/Semver"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "AssetRef": {
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
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Crop": {
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
          "maximum": 1
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        }
      }
    },
    "SourceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "role",
        "ordinal",
        "asset",
        "range",
        "crop",
        "audioUse",
        "subjectIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "productFront",
            "productDetail",
            "firstFrame",
            "lastFrame",
            "sourceVideo",
            "motionVideo",
            "referenceImage",
            "referenceVideo",
            "montage",
            "script",
            "voice",
            "music",
            "mask",
            "contextImage"
          ]
        },
        "ordinal": {
          "type": "integer",
          "minimum": 0,
          "maximum": 999
        },
        "asset": {
          "$ref": "#/$defs/AssetRef"
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
        "crop": {
          "anyOf": [
            {
              "$ref": "#/$defs/Crop"
            },
            {
              "type": "null"
            }
          ]
        },
        "audioUse": {
          "enum": [
            "strip",
            "use",
            "voiceRef"
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        }
      }
    },
    "ProductFact": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "kind",
        "text",
        "sourceEvidenceHashes",
        "confirmed",
        "confirmationRef",
        "expiresAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "price",
            "specification",
            "feature",
            "offer",
            "claim",
            "cta"
          ]
        },
        "text": {
          "type": "string",
          "maxLength": 2000
        },
        "sourceEvidenceHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "confirmed": {
          "type": "boolean"
        },
        "confirmationRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "expiresAt": {
          "anyOf": [
            {
              "$ref": "#/$defs/Timestamp"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ProductIdentity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "name",
        "shape",
        "material",
        "color",
        "dimensionsText",
        "packaging",
        "logoAssetRef",
        "referenceBindingIds",
        "factIds",
        "forbiddenDrift"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "maxLength": 200
        },
        "shape": {
          "type": "string",
          "maxLength": 1000
        },
        "material": {
          "type": "string",
          "maxLength": 1000
        },
        "color": {
          "type": "string",
          "maxLength": 200
        },
        "dimensionsText": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 500
            },
            {
              "type": "null"
            }
          ]
        },
        "packaging": {
          "type": "string",
          "maxLength": 1000
        },
        "logoAssetRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/AssetRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "forbiddenDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 500
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "CharacterPin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "libraryId",
        "assetId",
        "version",
        "hash",
        "lookId"
      ],
      "properties": {
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
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
    "Subject": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "characterPin",
        "portraitConsentRef",
        "guardianConsentRef",
        "rightsEpoch"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "fictionalHuman",
            "realAdult",
            "realMinor",
            "animal",
            "product"
          ]
        },
        "characterPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/CharacterPin"
            },
            {
              "type": "null"
            }
          ]
        },
        "portraitConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "guardianConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "Budget": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "currency",
        "maxMicros"
      ],
      "properties": {
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$"
        },
        "maxMicros": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "VerticalBrief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "purpose",
        "inputModes",
        "targetDuration",
        "aspect",
        "allowNewGeneration",
        "productId",
        "scriptBindingId",
        "subjectIds",
        "sourceBindings",
        "factIds",
        "recipeRefs",
        "voiceMode",
        "desiredOutcome",
        "userConstraints",
        "maxGeneratedSeconds",
        "budget",
        "lockedFieldRefs"
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
        "purpose": {
          "enum": [
            "marketing",
            "showcase",
            "story",
            "social",
            "tutorial",
            "musicVisual"
          ]
        },
        "inputModes": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "script",
              "mediaMontage",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1",
            "4:3",
            "3:4"
          ]
        },
        "allowNewGeneration": {
          "type": "boolean",
          "default": false
        },
        "productId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "scriptBindingId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "sourceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SourceBinding"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "recipeRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "voiceMode": {
          "enum": [
            "none",
            "captions",
            "uploadedAudio",
            "nativeTrial"
          ]
        },
        "desiredOutcome": {
          "type": "string",
          "maxLength": 2000
        },
        "userConstraints": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 0,
          "maxItems": 64
        },
        "maxGeneratedSeconds": {
          "$ref": "#/$defs/Time"
        },
        "budget": {
          "$ref": "#/$defs/Budget"
        },
        "lockedFieldRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "Override": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "baseTemplateHash",
        "text",
        "reviewState",
        "reviewRef"
      ],
      "properties": {
        "baseTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "reviewState": {
          "enum": [
            "unreviewed",
            "confirmed"
          ]
        },
        "reviewRef": {
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
    "Variables": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "maxProperties": 64,
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000,
            "maximum": 1000000
          },
          {
            "type": "boolean"
          }
        ]
      }
    },
    "ShotExecution": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "route",
        "profileRef",
        "sourceBindingIds",
        "subjectIds",
        "recipeRef",
        "templateRef",
        "variables",
        "factIds",
        "skillRefs",
        "targetRange",
        "providerDurationSeconds",
        "candidateCount",
        "promptOverride",
        "outputContract",
        "lockedPaths"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "route": {
          "enum": [
            "renderExisting",
            "t2v",
            "i2v",
            "firstLast",
            "nativeContinue",
            "tailFrameBridge",
            "referenceSynthesis",
            "motionTransfer",
            "videoRestyle"
          ]
        },
        "profileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "recipeRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "variables": {
          "$ref": "#/$defs/Variables"
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "targetRange": {
          "$ref": "#/$defs/Range"
        },
        "providerDurationSeconds": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 2,
              "maximum": 30
            },
            {
              "type": "null"
            }
          ]
        },
        "candidateCount": {
          "type": "integer",
          "minimum": 1,
          "maximum": 4
        },
        "promptOverride": {
          "anyOf": [
            {
              "$ref": "#/$defs/Override"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputContract": {
          "enum": [
            "newClip",
            "inputPlusContinuation",
            "existingAssets",
            "approxContinuation",
            "motionRemap"
          ]
        },
        "lockedPaths": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "SlotSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "role",
        "mediaKinds",
        "min",
        "max",
        "subjectMin",
        "subjectMax"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "$ref": "#/$defs/Id"
        },
        "mediaKinds": {
          "type": "array",
          "items": {
            "enum": [
              "image",
              "video",
              "audio",
              "text",
              "mask"
            ]
          },
          "minItems": 1,
          "maxItems": 5
        },
        "min": {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000
        },
        "max": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        },
        "subjectMin": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        },
        "subjectMax": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        }
      }
    },
    "ParameterSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "type",
        "required",
        "enumValues",
        "min",
        "max",
        "defaultValue"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "string",
            "number",
            "boolean",
            "enum"
          ]
        },
        "required": {
          "type": "boolean"
        },
        "enumValues": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 64
        },
        "min": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "max": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "defaultValue": {
          "anyOf": [
            {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 2000
                },
                {
                  "type": "number",
                  "minimum": -1000000,
                  "maximum": 1000000
                },
                {
                  "type": "boolean"
                }
              ]
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "RecipeStep": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "phase",
        "skillRef",
        "promptProgramRef",
        "dependsOn"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "phase": {
          "enum": [
            "preflight",
            "analyze",
            "plan",
            "confirm",
            "compile",
            "generate",
            "qa",
            "edit",
            "deliver"
          ]
        },
        "skillRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "promptProgramRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "PlayRecipe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "kind",
        "slotSpecs",
        "parameterSpecs",
        "allowedRoutes",
        "requiredGates",
        "steps",
        "skillRefs",
        "qaChecks",
        "example",
        "status",
        "replacementRef",
        "requiresExplicitUpgrade",
        "licenseRef"
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
          "$ref": "#/$defs/Semver"
        },
        "kind": {
          "enum": [
            "hug",
            "miniature",
            "animalHumanized",
            "babyDance"
          ]
        },
        "slotSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SlotSpec"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "parameterSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterSpec"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "allowedRoutes": {
          "type": "array",
          "items": {
            "enum": [
              "i2v",
              "referenceSynthesis",
              "motionTransfer",
              "renderExisting"
            ]
          },
          "minItems": 1,
          "maxItems": 4
        },
        "requiredGates": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/RecipeStep"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "qaChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 1,
          "maxItems": 32
        },
        "example": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "synthetic",
            "coverHash",
            "exampleInputHashes",
            "licenseRef"
          ],
          "properties": {
            "synthetic": {
              "const": true
            },
            "coverHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "exampleInputHashes": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Hash"
              },
              "minItems": 0,
              "maxItems": 16
            },
            "licenseRef": {
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
        "status": {
          "enum": [
            "active",
            "deprecated",
            "withdrawn"
          ]
        },
        "replacementRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "requiresExplicitUpgrade": {
          "const": true
        },
        "licenseRef": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Token": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "text"
          ],
          "properties": {
            "kind": {
              "const": "literal"
            },
            "text": {
              "type": "string",
              "maxLength": 10000
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "key"
          ],
          "properties": {
            "kind": {
              "const": "slot"
            },
            "key": {
              "$ref": "#/$defs/Id"
            }
          }
        }
      ]
    },
    "ProgramVariable": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "required",
        "maxChars",
        "source"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "required": {
          "type": "boolean"
        },
        "maxChars": {
          "type": "integer",
          "minimum": 1,
          "maximum": 10000
        },
        "source": {
          "enum": [
            "user",
            "fact",
            "analysis",
            "subject",
            "skill"
          ]
        }
      }
    },
    "ParameterBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "slot",
        "providerField",
        "handling"
      ],
      "properties": {
        "slot": {
          "$ref": "#/$defs/Id"
        },
        "providerField": {
          "$ref": "#/$defs/Id"
        },
        "handling": {
          "enum": [
            "hard",
            "soft",
            "unsupported"
          ]
        }
      }
    },
    "PromptProgram": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "routeModes",
        "variables",
        "positive",
        "negative",
        "parameterBindings",
        "outputScope"
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
          "$ref": "#/$defs/Semver"
        },
        "routeModes": {
          "type": "array",
          "items": {
            "enum": [
              "renderExisting",
              "t2v",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "variables": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProgramVariable"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "positive": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 1,
          "maxItems": 128
        },
        "negative": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "parameterBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterBinding"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputScope": {
          "enum": [
            "planning",
            "singleShot",
            "editPlan"
          ]
        }
      }
    },
    "WorkflowSnapshot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "brief",
        "products",
        "facts",
        "subjects",
        "shots",
        "recipePins",
        "templatePins",
        "analysisArtifactHashes",
        "stageRefs",
        "editPlanHash",
        "createdAt",
        "originProject",
        "templateCompilerVersion"
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
        "brief": {
          "$ref": "#/$defs/VerticalBrief"
        },
        "products": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductIdentity"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "facts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductFact"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "subjects": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Subject"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "shots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ShotExecution"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "recipePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "templatePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "analysisArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "stageRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "editPlanHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "originProject": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "projectId",
            "revision"
          ],
          "properties": {
            "projectId": {
              "$ref": "#/$defs/Id"
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "templateCompilerVersion": {
          "$ref": "#/$defs/Semver"
        }
      }
    },
    "RunError": {
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
    "WorkflowRun": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "workflowSnapshotHash",
        "projectId",
        "baseRevision",
        "state",
        "recordVersion",
        "activeNodeIds",
        "cancelEpoch",
        "error",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "state": {
          "enum": [
            "draft",
            "preflighting",
            "analyzing",
            "planning",
            "awaitingPlan",
            "compiling",
            "awaitingApproval",
            "readyToSubmit",
            "generating",
            "awaitingQA",
            "readyToApply",
            "applying",
            "applied",
            "delivering",
            "completed",
            "needsRebase",
            "blocked",
            "failed",
            "cancelRequested",
            "cancelled"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "activeNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "error": {
          "anyOf": [
            {
              "$ref": "#/$defs/RunError"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "updatedAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "ClipBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "clipId",
        "shotPlanId",
        "candidateId",
        "sourceVersion"
      ],
      "properties": {
        "clipId": {
          "$ref": "#/$defs/Id"
        },
        "shotPlanId": {
          "$ref": "#/$defs/Id"
        },
        "candidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "ProjectWorkflowLink": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "namespace",
        "projectId",
        "projectRevision",
        "projectContentHash",
        "workflowSnapshotHash",
        "acceptedCommandId",
        "originArchiveId",
        "clipBindings"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "projectRevision": {
          "$ref": "#/$defs/U64"
        },
        "projectContentHash": {
          "$ref": "#/$defs/Hash"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "acceptedCommandId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "originArchiveId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "clipBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ClipBinding"
          },
          "minItems": 0,
          "maxItems": 10000
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/vertical/WorkflowRun-1.0.0.json",
  "$ref": "#/$defs/WorkflowRun",
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
    "Semver": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
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
          "$ref": "#/$defs/Semver"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "AssetRef": {
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
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Crop": {
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
          "maximum": 1
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        }
      }
    },
    "SourceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "role",
        "ordinal",
        "asset",
        "range",
        "crop",
        "audioUse",
        "subjectIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "productFront",
            "productDetail",
            "firstFrame",
            "lastFrame",
            "sourceVideo",
            "motionVideo",
            "referenceImage",
            "referenceVideo",
            "montage",
            "script",
            "voice",
            "music",
            "mask",
            "contextImage"
          ]
        },
        "ordinal": {
          "type": "integer",
          "minimum": 0,
          "maximum": 999
        },
        "asset": {
          "$ref": "#/$defs/AssetRef"
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
        "crop": {
          "anyOf": [
            {
              "$ref": "#/$defs/Crop"
            },
            {
              "type": "null"
            }
          ]
        },
        "audioUse": {
          "enum": [
            "strip",
            "use",
            "voiceRef"
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        }
      }
    },
    "ProductFact": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "kind",
        "text",
        "sourceEvidenceHashes",
        "confirmed",
        "confirmationRef",
        "expiresAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "price",
            "specification",
            "feature",
            "offer",
            "claim",
            "cta"
          ]
        },
        "text": {
          "type": "string",
          "maxLength": 2000
        },
        "sourceEvidenceHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "confirmed": {
          "type": "boolean"
        },
        "confirmationRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "expiresAt": {
          "anyOf": [
            {
              "$ref": "#/$defs/Timestamp"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ProductIdentity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "name",
        "shape",
        "material",
        "color",
        "dimensionsText",
        "packaging",
        "logoAssetRef",
        "referenceBindingIds",
        "factIds",
        "forbiddenDrift"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "maxLength": 200
        },
        "shape": {
          "type": "string",
          "maxLength": 1000
        },
        "material": {
          "type": "string",
          "maxLength": 1000
        },
        "color": {
          "type": "string",
          "maxLength": 200
        },
        "dimensionsText": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 500
            },
            {
              "type": "null"
            }
          ]
        },
        "packaging": {
          "type": "string",
          "maxLength": 1000
        },
        "logoAssetRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/AssetRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "forbiddenDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 500
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "CharacterPin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "libraryId",
        "assetId",
        "version",
        "hash",
        "lookId"
      ],
      "properties": {
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
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
    "Subject": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "characterPin",
        "portraitConsentRef",
        "guardianConsentRef",
        "rightsEpoch"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "fictionalHuman",
            "realAdult",
            "realMinor",
            "animal",
            "product"
          ]
        },
        "characterPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/CharacterPin"
            },
            {
              "type": "null"
            }
          ]
        },
        "portraitConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "guardianConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "Budget": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "currency",
        "maxMicros"
      ],
      "properties": {
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$"
        },
        "maxMicros": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "VerticalBrief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "purpose",
        "inputModes",
        "targetDuration",
        "aspect",
        "allowNewGeneration",
        "productId",
        "scriptBindingId",
        "subjectIds",
        "sourceBindings",
        "factIds",
        "recipeRefs",
        "voiceMode",
        "desiredOutcome",
        "userConstraints",
        "maxGeneratedSeconds",
        "budget",
        "lockedFieldRefs"
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
        "purpose": {
          "enum": [
            "marketing",
            "showcase",
            "story",
            "social",
            "tutorial",
            "musicVisual"
          ]
        },
        "inputModes": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "script",
              "mediaMontage",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1",
            "4:3",
            "3:4"
          ]
        },
        "allowNewGeneration": {
          "type": "boolean",
          "default": false
        },
        "productId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "scriptBindingId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "sourceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SourceBinding"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "recipeRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "voiceMode": {
          "enum": [
            "none",
            "captions",
            "uploadedAudio",
            "nativeTrial"
          ]
        },
        "desiredOutcome": {
          "type": "string",
          "maxLength": 2000
        },
        "userConstraints": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 0,
          "maxItems": 64
        },
        "maxGeneratedSeconds": {
          "$ref": "#/$defs/Time"
        },
        "budget": {
          "$ref": "#/$defs/Budget"
        },
        "lockedFieldRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "Override": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "baseTemplateHash",
        "text",
        "reviewState",
        "reviewRef"
      ],
      "properties": {
        "baseTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "reviewState": {
          "enum": [
            "unreviewed",
            "confirmed"
          ]
        },
        "reviewRef": {
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
    "Variables": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "maxProperties": 64,
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000,
            "maximum": 1000000
          },
          {
            "type": "boolean"
          }
        ]
      }
    },
    "ShotExecution": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "route",
        "profileRef",
        "sourceBindingIds",
        "subjectIds",
        "recipeRef",
        "templateRef",
        "variables",
        "factIds",
        "skillRefs",
        "targetRange",
        "providerDurationSeconds",
        "candidateCount",
        "promptOverride",
        "outputContract",
        "lockedPaths"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "route": {
          "enum": [
            "renderExisting",
            "t2v",
            "i2v",
            "firstLast",
            "nativeContinue",
            "tailFrameBridge",
            "referenceSynthesis",
            "motionTransfer",
            "videoRestyle"
          ]
        },
        "profileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "recipeRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "variables": {
          "$ref": "#/$defs/Variables"
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "targetRange": {
          "$ref": "#/$defs/Range"
        },
        "providerDurationSeconds": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 2,
              "maximum": 30
            },
            {
              "type": "null"
            }
          ]
        },
        "candidateCount": {
          "type": "integer",
          "minimum": 1,
          "maximum": 4
        },
        "promptOverride": {
          "anyOf": [
            {
              "$ref": "#/$defs/Override"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputContract": {
          "enum": [
            "newClip",
            "inputPlusContinuation",
            "existingAssets",
            "approxContinuation",
            "motionRemap"
          ]
        },
        "lockedPaths": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "SlotSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "role",
        "mediaKinds",
        "min",
        "max",
        "subjectMin",
        "subjectMax"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "$ref": "#/$defs/Id"
        },
        "mediaKinds": {
          "type": "array",
          "items": {
            "enum": [
              "image",
              "video",
              "audio",
              "text",
              "mask"
            ]
          },
          "minItems": 1,
          "maxItems": 5
        },
        "min": {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000
        },
        "max": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        },
        "subjectMin": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        },
        "subjectMax": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        }
      }
    },
    "ParameterSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "type",
        "required",
        "enumValues",
        "min",
        "max",
        "defaultValue"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "string",
            "number",
            "boolean",
            "enum"
          ]
        },
        "required": {
          "type": "boolean"
        },
        "enumValues": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 64
        },
        "min": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "max": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "defaultValue": {
          "anyOf": [
            {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 2000
                },
                {
                  "type": "number",
                  "minimum": -1000000,
                  "maximum": 1000000
                },
                {
                  "type": "boolean"
                }
              ]
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "RecipeStep": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "phase",
        "skillRef",
        "promptProgramRef",
        "dependsOn"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "phase": {
          "enum": [
            "preflight",
            "analyze",
            "plan",
            "confirm",
            "compile",
            "generate",
            "qa",
            "edit",
            "deliver"
          ]
        },
        "skillRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "promptProgramRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "PlayRecipe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "kind",
        "slotSpecs",
        "parameterSpecs",
        "allowedRoutes",
        "requiredGates",
        "steps",
        "skillRefs",
        "qaChecks",
        "example",
        "status",
        "replacementRef",
        "requiresExplicitUpgrade",
        "licenseRef"
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
          "$ref": "#/$defs/Semver"
        },
        "kind": {
          "enum": [
            "hug",
            "miniature",
            "animalHumanized",
            "babyDance"
          ]
        },
        "slotSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SlotSpec"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "parameterSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterSpec"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "allowedRoutes": {
          "type": "array",
          "items": {
            "enum": [
              "i2v",
              "referenceSynthesis",
              "motionTransfer",
              "renderExisting"
            ]
          },
          "minItems": 1,
          "maxItems": 4
        },
        "requiredGates": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/RecipeStep"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "qaChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 1,
          "maxItems": 32
        },
        "example": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "synthetic",
            "coverHash",
            "exampleInputHashes",
            "licenseRef"
          ],
          "properties": {
            "synthetic": {
              "const": true
            },
            "coverHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "exampleInputHashes": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Hash"
              },
              "minItems": 0,
              "maxItems": 16
            },
            "licenseRef": {
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
        "status": {
          "enum": [
            "active",
            "deprecated",
            "withdrawn"
          ]
        },
        "replacementRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "requiresExplicitUpgrade": {
          "const": true
        },
        "licenseRef": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Token": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "text"
          ],
          "properties": {
            "kind": {
              "const": "literal"
            },
            "text": {
              "type": "string",
              "maxLength": 10000
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "key"
          ],
          "properties": {
            "kind": {
              "const": "slot"
            },
            "key": {
              "$ref": "#/$defs/Id"
            }
          }
        }
      ]
    },
    "ProgramVariable": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "required",
        "maxChars",
        "source"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "required": {
          "type": "boolean"
        },
        "maxChars": {
          "type": "integer",
          "minimum": 1,
          "maximum": 10000
        },
        "source": {
          "enum": [
            "user",
            "fact",
            "analysis",
            "subject",
            "skill"
          ]
        }
      }
    },
    "ParameterBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "slot",
        "providerField",
        "handling"
      ],
      "properties": {
        "slot": {
          "$ref": "#/$defs/Id"
        },
        "providerField": {
          "$ref": "#/$defs/Id"
        },
        "handling": {
          "enum": [
            "hard",
            "soft",
            "unsupported"
          ]
        }
      }
    },
    "PromptProgram": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "routeModes",
        "variables",
        "positive",
        "negative",
        "parameterBindings",
        "outputScope"
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
          "$ref": "#/$defs/Semver"
        },
        "routeModes": {
          "type": "array",
          "items": {
            "enum": [
              "renderExisting",
              "t2v",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "variables": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProgramVariable"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "positive": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 1,
          "maxItems": 128
        },
        "negative": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "parameterBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterBinding"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputScope": {
          "enum": [
            "planning",
            "singleShot",
            "editPlan"
          ]
        }
      }
    },
    "WorkflowSnapshot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "brief",
        "products",
        "facts",
        "subjects",
        "shots",
        "recipePins",
        "templatePins",
        "analysisArtifactHashes",
        "stageRefs",
        "editPlanHash",
        "createdAt",
        "originProject",
        "templateCompilerVersion"
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
        "brief": {
          "$ref": "#/$defs/VerticalBrief"
        },
        "products": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductIdentity"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "facts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductFact"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "subjects": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Subject"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "shots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ShotExecution"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "recipePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "templatePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "analysisArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "stageRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "editPlanHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "originProject": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "projectId",
            "revision"
          ],
          "properties": {
            "projectId": {
              "$ref": "#/$defs/Id"
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "templateCompilerVersion": {
          "$ref": "#/$defs/Semver"
        }
      }
    },
    "RunError": {
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
    "WorkflowRun": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "workflowSnapshotHash",
        "projectId",
        "baseRevision",
        "state",
        "recordVersion",
        "activeNodeIds",
        "cancelEpoch",
        "error",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "state": {
          "enum": [
            "draft",
            "preflighting",
            "analyzing",
            "planning",
            "awaitingPlan",
            "compiling",
            "awaitingApproval",
            "readyToSubmit",
            "generating",
            "awaitingQA",
            "readyToApply",
            "applying",
            "applied",
            "delivering",
            "completed",
            "needsRebase",
            "blocked",
            "failed",
            "cancelRequested",
            "cancelled"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "activeNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "error": {
          "anyOf": [
            {
              "$ref": "#/$defs/RunError"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "updatedAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "ClipBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "clipId",
        "shotPlanId",
        "candidateId",
        "sourceVersion"
      ],
      "properties": {
        "clipId": {
          "$ref": "#/$defs/Id"
        },
        "shotPlanId": {
          "$ref": "#/$defs/Id"
        },
        "candidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "ProjectWorkflowLink": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "namespace",
        "projectId",
        "projectRevision",
        "projectContentHash",
        "workflowSnapshotHash",
        "acceptedCommandId",
        "originArchiveId",
        "clipBindings"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "projectRevision": {
          "$ref": "#/$defs/U64"
        },
        "projectContentHash": {
          "$ref": "#/$defs/Hash"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "acceptedCommandId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "originArchiveId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "clipBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ClipBinding"
          },
          "minItems": 0,
          "maxItems": 10000
        }
      }
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://studio.invalid/schemas/vertical/ProjectWorkflowLink-1.0.0.json",
  "$ref": "#/$defs/ProjectWorkflowLink",
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
    "Semver": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
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
          "$ref": "#/$defs/Semver"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "AssetRef": {
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
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        }
      }
    },
    "Crop": {
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
          "maximum": 1
        },
        "y": {
          "type": "number",
          "minimum": 0,
          "maximum": 1
        },
        "width": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        },
        "height": {
          "type": "number",
          "minimum": 0.000001,
          "maximum": 1
        }
      }
    },
    "SourceBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "role",
        "ordinal",
        "asset",
        "range",
        "crop",
        "audioUse",
        "subjectIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "productFront",
            "productDetail",
            "firstFrame",
            "lastFrame",
            "sourceVideo",
            "motionVideo",
            "referenceImage",
            "referenceVideo",
            "montage",
            "script",
            "voice",
            "music",
            "mask",
            "contextImage"
          ]
        },
        "ordinal": {
          "type": "integer",
          "minimum": 0,
          "maximum": 999
        },
        "asset": {
          "$ref": "#/$defs/AssetRef"
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
        "crop": {
          "anyOf": [
            {
              "$ref": "#/$defs/Crop"
            },
            {
              "type": "null"
            }
          ]
        },
        "audioUse": {
          "enum": [
            "strip",
            "use",
            "voiceRef"
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        }
      }
    },
    "ProductFact": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "kind",
        "text",
        "sourceEvidenceHashes",
        "confirmed",
        "confirmationRef",
        "expiresAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "price",
            "specification",
            "feature",
            "offer",
            "claim",
            "cta"
          ]
        },
        "text": {
          "type": "string",
          "maxLength": 2000
        },
        "sourceEvidenceHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "confirmed": {
          "type": "boolean"
        },
        "confirmationRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "expiresAt": {
          "anyOf": [
            {
              "$ref": "#/$defs/Timestamp"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ProductIdentity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sku",
        "name",
        "shape",
        "material",
        "color",
        "dimensionsText",
        "packaging",
        "logoAssetRef",
        "referenceBindingIds",
        "factIds",
        "forbiddenDrift"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sku": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "maxLength": 200
        },
        "shape": {
          "type": "string",
          "maxLength": 1000
        },
        "material": {
          "type": "string",
          "maxLength": 1000
        },
        "color": {
          "type": "string",
          "maxLength": 200
        },
        "dimensionsText": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 500
            },
            {
              "type": "null"
            }
          ]
        },
        "packaging": {
          "type": "string",
          "maxLength": 1000
        },
        "logoAssetRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/AssetRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "forbiddenDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 500
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "CharacterPin": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "libraryId",
        "assetId",
        "version",
        "hash",
        "lookId"
      ],
      "properties": {
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
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
    "Subject": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "characterPin",
        "portraitConsentRef",
        "guardianConsentRef",
        "rightsEpoch"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "fictionalHuman",
            "realAdult",
            "realMinor",
            "animal",
            "product"
          ]
        },
        "characterPin": {
          "anyOf": [
            {
              "$ref": "#/$defs/CharacterPin"
            },
            {
              "type": "null"
            }
          ]
        },
        "portraitConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "guardianConsentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "rightsEpoch": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "Budget": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "currency",
        "maxMicros"
      ],
      "properties": {
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$"
        },
        "maxMicros": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "VerticalBrief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "purpose",
        "inputModes",
        "targetDuration",
        "aspect",
        "allowNewGeneration",
        "productId",
        "scriptBindingId",
        "subjectIds",
        "sourceBindings",
        "factIds",
        "recipeRefs",
        "voiceMode",
        "desiredOutcome",
        "userConstraints",
        "maxGeneratedSeconds",
        "budget",
        "lockedFieldRefs"
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
        "purpose": {
          "enum": [
            "marketing",
            "showcase",
            "story",
            "social",
            "tutorial",
            "musicVisual"
          ]
        },
        "inputModes": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "script",
              "mediaMontage",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1",
            "4:3",
            "3:4"
          ]
        },
        "allowNewGeneration": {
          "type": "boolean",
          "default": false
        },
        "productId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "scriptBindingId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "sourceBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SourceBinding"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "recipeRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "voiceMode": {
          "enum": [
            "none",
            "captions",
            "uploadedAudio",
            "nativeTrial"
          ]
        },
        "desiredOutcome": {
          "type": "string",
          "maxLength": 2000
        },
        "userConstraints": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 0,
          "maxItems": 64
        },
        "maxGeneratedSeconds": {
          "$ref": "#/$defs/Time"
        },
        "budget": {
          "$ref": "#/$defs/Budget"
        },
        "lockedFieldRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "Override": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "baseTemplateHash",
        "text",
        "reviewState",
        "reviewRef"
      ],
      "properties": {
        "baseTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "text": {
          "type": "string",
          "maxLength": 10000
        },
        "reviewState": {
          "enum": [
            "unreviewed",
            "confirmed"
          ]
        },
        "reviewRef": {
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
    "Variables": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[A-Za-z][A-Za-z0-9_]{0,63}$"
      },
      "maxProperties": 64,
      "additionalProperties": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 10000
          },
          {
            "type": "number",
            "minimum": -1000000,
            "maximum": 1000000
          },
          {
            "type": "boolean"
          }
        ]
      }
    },
    "ShotExecution": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "route",
        "profileRef",
        "sourceBindingIds",
        "subjectIds",
        "recipeRef",
        "templateRef",
        "variables",
        "factIds",
        "skillRefs",
        "targetRange",
        "providerDurationSeconds",
        "candidateCount",
        "promptOverride",
        "outputContract",
        "lockedPaths"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "route": {
          "enum": [
            "renderExisting",
            "t2v",
            "i2v",
            "firstLast",
            "nativeContinue",
            "tailFrameBridge",
            "referenceSynthesis",
            "motionTransfer",
            "videoRestyle"
          ]
        },
        "profileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceBindingIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "subjectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "recipeRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "variables": {
          "$ref": "#/$defs/Variables"
        },
        "factIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "targetRange": {
          "$ref": "#/$defs/Range"
        },
        "providerDurationSeconds": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 2,
              "maximum": 30
            },
            {
              "type": "null"
            }
          ]
        },
        "candidateCount": {
          "type": "integer",
          "minimum": 1,
          "maximum": 4
        },
        "promptOverride": {
          "anyOf": [
            {
              "$ref": "#/$defs/Override"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputContract": {
          "enum": [
            "newClip",
            "inputPlusContinuation",
            "existingAssets",
            "approxContinuation",
            "motionRemap"
          ]
        },
        "lockedPaths": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 1000
        }
      }
    },
    "SlotSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "role",
        "mediaKinds",
        "min",
        "max",
        "subjectMin",
        "subjectMax"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "$ref": "#/$defs/Id"
        },
        "mediaKinds": {
          "type": "array",
          "items": {
            "enum": [
              "image",
              "video",
              "audio",
              "text",
              "mask"
            ]
          },
          "minItems": 1,
          "maxItems": 5
        },
        "min": {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000
        },
        "max": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        },
        "subjectMin": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        },
        "subjectMax": {
          "type": "integer",
          "minimum": 0,
          "maximum": 16
        }
      }
    },
    "ParameterSpec": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "type",
        "required",
        "enumValues",
        "min",
        "max",
        "defaultValue"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "string",
            "number",
            "boolean",
            "enum"
          ]
        },
        "required": {
          "type": "boolean"
        },
        "enumValues": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 300
          },
          "minItems": 0,
          "maxItems": 64
        },
        "min": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "max": {
          "anyOf": [
            {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "defaultValue": {
          "anyOf": [
            {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 2000
                },
                {
                  "type": "number",
                  "minimum": -1000000,
                  "maximum": 1000000
                },
                {
                  "type": "boolean"
                }
              ]
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "RecipeStep": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "phase",
        "skillRef",
        "promptProgramRef",
        "dependsOn"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "phase": {
          "enum": [
            "preflight",
            "analyze",
            "plan",
            "confirm",
            "compile",
            "generate",
            "qa",
            "edit",
            "deliver"
          ]
        },
        "skillRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "promptProgramRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "PlayRecipe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "kind",
        "slotSpecs",
        "parameterSpecs",
        "allowedRoutes",
        "requiredGates",
        "steps",
        "skillRefs",
        "qaChecks",
        "example",
        "status",
        "replacementRef",
        "requiresExplicitUpgrade",
        "licenseRef"
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
          "$ref": "#/$defs/Semver"
        },
        "kind": {
          "enum": [
            "hug",
            "miniature",
            "animalHumanized",
            "babyDance"
          ]
        },
        "slotSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SlotSpec"
          },
          "minItems": 1,
          "maxItems": 16
        },
        "parameterSpecs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterSpec"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "allowedRoutes": {
          "type": "array",
          "items": {
            "enum": [
              "i2v",
              "referenceSynthesis",
              "motionTransfer",
              "renderExisting"
            ]
          },
          "minItems": 1,
          "maxItems": 4
        },
        "requiredGates": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/RecipeStep"
          },
          "minItems": 1,
          "maxItems": 32
        },
        "skillRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "qaChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1000
          },
          "minItems": 1,
          "maxItems": 32
        },
        "example": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "synthetic",
            "coverHash",
            "exampleInputHashes",
            "licenseRef"
          ],
          "properties": {
            "synthetic": {
              "const": true
            },
            "coverHash": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Hash"
                },
                {
                  "type": "null"
                }
              ]
            },
            "exampleInputHashes": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/Hash"
              },
              "minItems": 0,
              "maxItems": 16
            },
            "licenseRef": {
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
        "status": {
          "enum": [
            "active",
            "deprecated",
            "withdrawn"
          ]
        },
        "replacementRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Pin"
            },
            {
              "type": "null"
            }
          ]
        },
        "requiresExplicitUpgrade": {
          "const": true
        },
        "licenseRef": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Token": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "text"
          ],
          "properties": {
            "kind": {
              "const": "literal"
            },
            "text": {
              "type": "string",
              "maxLength": 10000
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "key"
          ],
          "properties": {
            "kind": {
              "const": "slot"
            },
            "key": {
              "$ref": "#/$defs/Id"
            }
          }
        }
      ]
    },
    "ProgramVariable": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "key",
        "required",
        "maxChars",
        "source"
      ],
      "properties": {
        "key": {
          "$ref": "#/$defs/Id"
        },
        "required": {
          "type": "boolean"
        },
        "maxChars": {
          "type": "integer",
          "minimum": 1,
          "maximum": 10000
        },
        "source": {
          "enum": [
            "user",
            "fact",
            "analysis",
            "subject",
            "skill"
          ]
        }
      }
    },
    "ParameterBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "slot",
        "providerField",
        "handling"
      ],
      "properties": {
        "slot": {
          "$ref": "#/$defs/Id"
        },
        "providerField": {
          "$ref": "#/$defs/Id"
        },
        "handling": {
          "enum": [
            "hard",
            "soft",
            "unsupported"
          ]
        }
      }
    },
    "PromptProgram": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "routeModes",
        "variables",
        "positive",
        "negative",
        "parameterBindings",
        "outputScope"
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
          "$ref": "#/$defs/Semver"
        },
        "routeModes": {
          "type": "array",
          "items": {
            "enum": [
              "renderExisting",
              "t2v",
              "i2v",
              "firstLast",
              "nativeContinue",
              "tailFrameBridge",
              "referenceSynthesis",
              "motionTransfer",
              "videoRestyle"
            ]
          },
          "minItems": 1,
          "maxItems": 10
        },
        "variables": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProgramVariable"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "positive": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 1,
          "maxItems": 128
        },
        "negative": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Token"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "parameterBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ParameterBinding"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "outputScope": {
          "enum": [
            "planning",
            "singleShot",
            "editPlan"
          ]
        }
      }
    },
    "WorkflowSnapshot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "brief",
        "products",
        "facts",
        "subjects",
        "shots",
        "recipePins",
        "templatePins",
        "analysisArtifactHashes",
        "stageRefs",
        "editPlanHash",
        "createdAt",
        "originProject",
        "templateCompilerVersion"
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
        "brief": {
          "$ref": "#/$defs/VerticalBrief"
        },
        "products": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductIdentity"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "facts": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ProductFact"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "subjects": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Subject"
          },
          "minItems": 0,
          "maxItems": 32
        },
        "shots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ShotExecution"
          },
          "minItems": 1,
          "maxItems": 1000
        },
        "recipePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 16
        },
        "templatePins": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Pin"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "analysisArtifactHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "stageRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "editPlanHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "originProject": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "projectId",
            "revision"
          ],
          "properties": {
            "projectId": {
              "$ref": "#/$defs/Id"
            },
            "revision": {
              "$ref": "#/$defs/U64"
            }
          }
        },
        "templateCompilerVersion": {
          "$ref": "#/$defs/Semver"
        }
      }
    },
    "RunError": {
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
    "WorkflowRun": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "workflowSnapshotHash",
        "projectId",
        "baseRevision",
        "state",
        "recordVersion",
        "activeNodeIds",
        "cancelEpoch",
        "error",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "baseRevision": {
          "$ref": "#/$defs/U64"
        },
        "state": {
          "enum": [
            "draft",
            "preflighting",
            "analyzing",
            "planning",
            "awaitingPlan",
            "compiling",
            "awaitingApproval",
            "readyToSubmit",
            "generating",
            "awaitingQA",
            "readyToApply",
            "applying",
            "applied",
            "delivering",
            "completed",
            "needsRebase",
            "blocked",
            "failed",
            "cancelRequested",
            "cancelled"
          ]
        },
        "recordVersion": {
          "$ref": "#/$defs/U64"
        },
        "activeNodeIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 1000
        },
        "cancelEpoch": {
          "$ref": "#/$defs/U64"
        },
        "error": {
          "anyOf": [
            {
              "$ref": "#/$defs/RunError"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        },
        "updatedAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "ClipBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "clipId",
        "shotPlanId",
        "candidateId",
        "sourceVersion"
      ],
      "properties": {
        "clipId": {
          "$ref": "#/$defs/Id"
        },
        "shotPlanId": {
          "$ref": "#/$defs/Id"
        },
        "candidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        }
      }
    },
    "ProjectWorkflowLink": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schemaVersion",
        "namespace",
        "projectId",
        "projectRevision",
        "projectContentHash",
        "workflowSnapshotHash",
        "acceptedCommandId",
        "originArchiveId",
        "clipBindings"
      ],
      "properties": {
        "schemaVersion": {
          "const": "1.0.0",
          "default": "1.0.0"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "projectId": {
          "$ref": "#/$defs/Id"
        },
        "projectRevision": {
          "$ref": "#/$defs/U64"
        },
        "projectContentHash": {
          "$ref": "#/$defs/Hash"
        },
        "workflowSnapshotHash": {
          "$ref": "#/$defs/Hash"
        },
        "acceptedCommandId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "originArchiveId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "clipBindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ClipBinding"
          },
          "minItems": 0,
          "maxItems": 10000
        }
      }
    }
  }
}
```

| 语义校验/错误 | 必须可编码的约束 |
| --- | --- |
| VerticalValidator.validateReferences | 同namespace，ID唯一；SourceBinding.asset指向对应版本与blob hash；AnalysisArtifact evidence hash可解析；subject/recipe/template/fact/skill引用必须存在且hash吻合。产品factIds和Brief/Shot factIds均需同SKU且confirmed/未过期；确认ID需受信FactLedger查证，LLM填confirmed=true不能授权。 |
| 时间/素材 | Time须最简/非负或按偏移规则、duration>0；crop x+width/y+height≤1；range在已探测素材内；SourceBinding.ordinal各角色内唯一，镜头targetRange不替代已接受NLE权威范围；执行计划须同序列量化/碰撞/handles检查。 |
| 业务/能力 | marketing/showcase必须productId；showcase有正面与细节两个明确绑定；script必有scriptBinding；输入模式、subjectIds和引用列表不得重复。renderExisting profile=null/providerDuration=null且无remote；任何新生成节点都必须allowNewGeneration=true，否则GENERATION_DISABLED，即使有费用批准也不能越过该策略。firstLast必须两个有序首尾；nativeContinue必须clip且output=inputPlusContinuation；tailFrameBridge output=approxContinuation；motionTransfer output=motionRemap。真实Profile槽/格式/时长/参考数由8I严格编译器检查。 |
| 配方/安全 | Recipe slot min≤max、subjectMin≤subjectMax；参数default符合类型与enum/range；步骤DAG无环/无未知依赖，template route匹配。schema合法不代表允许上传：live人物/声音/素材同意、儿童政策与费用审批仍独立硬门禁；LicenseCompliance商业许可事实缺口按1C默认风险放行。 |
| 错误/状态 | SLOT_COUNT、SUBJECT_ORDER_UNRESOLVED、MEDIA_COMBINATION、FACT_SKU_MISMATCH、UNCONFIRMED_FACT、FACT_EXPIRED、FACT_BINDING_CONFLICT、PORTRAIT_CONSENT_REQUIRED、PROVIDER_CHILD_POLICY_UNVERIFIED、CAPABILITY_UNSUPPORTED、OVERRIDE_REBASE_REQUIRED、APPROVAL_STALE、REVISION_CONFLICT。编译错误不提交；远端已受理失败/取消走对账，不重置已花费预算。 |

```text
-- VERTICAL_SQL_BEGIN
-- workspace additive migration vertical.v1；JSON中的U64入库前检查<=INT64_MAX。
-- 不修改core edit.v2.0/lifecycle.v1.0 payload CHECK，不修改旧library body schema。
-- migration requires document_lifecycle/1; BEGIN IMMEDIATE plus backup/rollback由MigrationRunner管理。
INSERT INTO workspace_features VALUES('vertical_workflow','1.0.0','vertical-workflow/1');
CREATE TABLE vertical_versions(
 ns TEXT NOT NULL,workflow_id TEXT NOT NULL,version INTEGER NOT NULL CHECK(version>=0),
 snapshot_hash TEXT NOT NULL,created_at TEXT NOT NULL,
 PRIMARY KEY(ns,workflow_id,version),UNIQUE(ns,snapshot_hash));
CREATE TRIGGER vertical_version_immutable BEFORE UPDATE ON vertical_versions
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_WORKFLOW_VERSION'); END;
CREATE TRIGGER vertical_version_no_replace BEFORE INSERT ON vertical_versions
 WHEN EXISTS(SELECT 1 FROM vertical_versions WHERE ns=NEW.ns AND
 ((workflow_id=NEW.workflow_id AND version=NEW.version) OR snapshot_hash=NEW.snapshot_hash))
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_WORKFLOW_VERSION'); END;
CREATE TRIGGER vertical_version_no_raw_delete BEFORE DELETE ON vertical_versions
 BEGIN SELECT RAISE(ABORT,'USE_WORKFLOW_RETENTION_SERVICE'); END;
CREATE TABLE vertical_runs(
 ns TEXT NOT NULL,id TEXT NOT NULL,workflow_id TEXT NOT NULL,workflow_version INTEGER NOT NULL,
 base_project_id TEXT NOT NULL,base_revision INTEGER NOT NULL CHECK(base_revision>=0),
 state TEXT NOT NULL CHECK(state IN ('draft','preflighting','analyzing','planning','awaitingPlan','compiling','awaitingApproval','readyToSubmit','generating','awaitingQA','readyToApply','applying','applied','delivering','completed','needsRebase','blocked','failed','cancelRequested','cancelled')),
 cancel_epoch INTEGER NOT NULL CHECK(cancel_epoch>=0),record_version INTEGER NOT NULL CHECK(record_version>=0),
 approval_hash TEXT,
 PRIMARY KEY(ns,id),FOREIGN KEY(ns,workflow_id,workflow_version) REFERENCES vertical_versions(ns,workflow_id,version),
 FOREIGN KEY(ns,base_project_id) REFERENCES project_heads(ns,project_id));
CREATE UNIQUE INDEX commands_project_identity ON commands(ns,project_id,id);
CREATE TABLE project_workflow_links(
 ns TEXT NOT NULL,project_id TEXT NOT NULL,revision INTEGER NOT NULL CHECK(revision>=0),
 workflow_id TEXT NOT NULL,workflow_version INTEGER NOT NULL,project_content_hash TEXT NOT NULL,
 link_artifact_hash TEXT NOT NULL,accepted_command_id TEXT,
 PRIMARY KEY(ns,project_id,revision,workflow_id),
 FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id),
 FOREIGN KEY(ns,workflow_id,workflow_version) REFERENCES vertical_versions(ns,workflow_id,version),
 FOREIGN KEY(ns,project_id,accepted_command_id) REFERENCES commands(ns,project_id,id));
CREATE TRIGGER workflow_link_immutable BEFORE UPDATE ON project_workflow_links
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_PROJECT_WORKFLOW_LINK'); END;
CREATE TRIGGER workflow_link_no_replace BEFORE INSERT ON project_workflow_links
 WHEN EXISTS(SELECT 1 FROM project_workflow_links WHERE ns=NEW.ns AND
 project_id=NEW.project_id AND revision=NEW.revision AND workflow_id=NEW.workflow_id)
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_PROJECT_WORKFLOW_LINK'); END;
CREATE TRIGGER workflow_link_no_raw_delete BEFORE DELETE ON project_workflow_links
 BEGIN SELECT RAISE(ABORT,'USE_WORKFLOW_RETENTION_SERVICE'); END;
-- VERTICAL_SQL_END
// trusted repository additionally verifies revision exists (R0 uses initial head),
// accepted command belongs to that exact resulting revision; matching artifact/content hashes;
// namespace in artifact == row ns. FK不验证hash内容，也不代替这些规则。
// CAS Snapshot/Link durable→BEGIN IMMEDIATE→core command batch CAS expectedR→
// INSERT matching link→receipt/outbox→COMMIT durable ACK。任何一步失败全部回滚。
// Run更新用 WHERE record_version=? AND cancel_epoch=? CAS；终态不被晚到事件倒退。
// Metadata版本/链接追加不可变；幂等重放先读同键同hash再返回，不用INSERT OR REPLACE。
// RetentionService可删除/遮罩已授权删除的CAS正文与缓存，只保不含正文的最小审计头；
// 物理元数据清理须专用受审migration/保留策略，不给Agent或普通repository绕过trigger。

```

| 兼容/可移植 | 当前有效策略 |
| --- | --- |
| 项目包 | Project/Manifest均保2.0.0不乱加根字段；extensions/vertical-workflow/{snapshot,link,mapping}.json及固定hash资源闭包列入checksums，Manifest仍用已有字段。保留制作规划是工件选项，不等于导出私聊；密钥/短URL/approval/远端可恢复句柄不入包。 |
| 归档/删除 | 8H生产工件作为RefWalker已注册根；连同产品事实证据、角色/技能/recipe/template/profile pin与许可清单按授权打包。删除正文与摘要的overlay优先，不能从旧工件恢复已删隐私；归档固定R、未完成jobs列清单，不等于取消付费任务。内容变更必须新hash，不能用旧hash悄净化。 |
| 旧App/未来版本 | 未知workflow.major或必需contentType：生产规划只读/执行禁用；核心媒体可按2.0降级播放剪辑。旧App再保存不保证保留未知sidecar，必须先保留原包/另存副本并显示“可能丢失制作规划”，不能承诺无损。共享workspace数据库须满足workspace_features全部min_writer，否则拒绝可写打开。迁移复制新快照并保留旧hash，经验证/用户确认后才切引用。 |
| 可再现边界 | 保存候选媒体/精确sourceRange/NLE效果版本可再现已接受剪辑；provider模型在线更新、seed、隐藏推理和声音无法保证重生成相同。无法合法再分发的参考/字体/LoRA记录缺失与外链，不偷带。 |
| 验证证据 | [box-local audit path]执行路由/事实/手改/取消/变更/缓存/权限边界合成测试；published_contract_checks.py从实际发布Page提取Schema与SQL，验证完整场景fixture、非法形状与跨引用、事务故障回滚、不可变版本与namespace隔离；run_regressions.py重跑既有Schema/NLE/FFmpeg/多模态/音乐角色技法/保存归档测试，完整stdout和regression-results.json存同目录。旧生命周期checker原件未改，仅派生兼容版移除获准修改s8/s12的整段字节相等断言，其余语义与保存测试保留。历史审查仅review-a/b/c.md，不写入有效规则；测试不等于真实API/模型质量/防注入效果/真机性能或法律认证。模型质量、儿童政策、实际地域账号/服务访问、计价仍分别验证；商用条款缺口仅按1C风险放行，不声明已获授权。 |

- [Wan官方提示词：主体/场景/运动与I2V运动描述](https://www.alibabacloud.com/help/en/model-studio/text-to-video-prompt)
- [Wan2.7 I2V/续写使用指南](https://www.alibabacloud.com/help/en/model-studio/wan-image-to-video-guide)
- [Wan参考生视频指南：非精确运动复制](https://www.alibabacloud.com/help/en/model-studio/video-to-video-guide)
- [Wan2.2运动迁移使用与素材要求](https://www.alibabacloud.com/help/en/model-studio/wan2-2-animate-move)
- [Premiere官方故事板自动组接：顺序/In-out/序列设置](https://helpx.adobe.com/sk/premiere-pro/how-to/storyboard-edits.html)
