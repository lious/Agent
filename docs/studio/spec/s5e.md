## 5E · 生命周期完整Schema、SQLite兼容与逐步操作

现有Project/Manifest/EditCommand/Result的2.0.0闭合Schema不改。下面是独立document-lifecycle/1.0.0 Schema集合，每份含全部本地定义；结构对象全部required、additionalProperties=false，只有显式nullable可为null。default是注解不自动补字段；U64仍需业务校验≤9223372036854775807。Archive sidecar固定路径extensions/document-lifecycle/descriptor.json和inventory.json并进入checksums；不往core Manifest偷加字段。缺sidecar的2.0老包可正常导入，生命周期信息为“未提供”而非推测。未知sidecar major保留并禁生命周期恢复，只允许验证过的core只读或显式兼容导入；已声明requiredFeatures仍强制执行。已知2.0 reader能读取原core快照不等于能理解新保存/恢复协议或写共享workspace。

```text
{
  "saveRequest": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://studio.invalid/schemas/document-lifecycle/SaveRequest-1.0.0.json",
    "$ref": "#/$defs/SaveRequest",
    "$defs": {
      "Id": {
        "type": "string",
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
      },
      "U64": {
        "type": "string",
        "pattern": "^(0|[1-9][0-9]{0,18})$"
      },
      "Hash": {
        "type": "string",
        "pattern": "^sha256:[0-9a-f]{64}$"
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
      "RelativePath": {
        "type": "string",
        "minLength": 1,
        "maxLength": 1024,
        "pattern": "^[A-Za-z0-9_./-]+$"
      },
      "Epochs": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "privacy",
          "rights"
        ],
        "properties": {
          "privacy": {
            "$ref": "#/$defs/U64"
          },
          "rights": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "ResourceKind": {
        "enum": [
          "original",
          "generated",
          "proxy",
          "font",
          "model",
          "lora",
          "character",
          "skill",
          "session",
          "project",
          "history",
          "license",
          "evidence",
          "thumbnail",
          "render"
        ]
      },
      "PendingOperation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "logicalId",
          "kind",
          "shotId",
          "stateAtFreeze",
          "remoteResumeIncluded"
        ],
        "properties": {
          "logicalId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "video",
              "music",
              "sfx",
              "analysis"
            ]
          },
          "shotId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "stateAtFreeze": {
            "enum": [
              "queued",
              "running",
              "unknown"
            ]
          },
          "remoteResumeIncluded": {
            "const": false
          }
        }
      },
      "Omission": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "resourceRef",
          "kind",
          "reason",
          "impact"
        ],
        "properties": {
          "resourceRef": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "reason": {
            "enum": [
              "external",
              "notRedistributable",
              "purged",
              "missing",
              "notSelected",
              "unresolvedExtension"
            ]
          },
          "impact": {
            "enum": [
              "blocksFinalRender",
              "previewOnly",
              "reproGeneration",
              "rebuildable",
              "historicalOnly"
            ]
          }
        }
      },
      "InventoryEntry": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "refId",
          "kind",
          "blobHash",
          "bytes",
          "embeddedPath",
          "externalRef",
          "requiredFor",
          "redistribution",
          "rightsRecordRef"
        ],
        "properties": {
          "refId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "blobHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "bytes": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "embeddedPath": {
            "anyOf": [
              {
                "$ref": "#/$defs/RelativePath"
              },
              {
                "type": "null"
              }
            ]
          },
          "externalRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "requiredFor": {
            "type": "array",
            "items": {
              "enum": [
                "preview",
                "finalRender",
                "reproGeneration",
                "audit"
              ]
            },
            "maxItems": 4,
            "uniqueItems": true
          },
          "redistribution": {
            "enum": [
              "allowed",
              "forbidden",
              "unknown"
            ]
          },
          "rightsRecordRef": {
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
      "SaveRequest": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "requestId",
          "namespace",
          "projectId",
          "idempotencyKey",
          "kind",
          "revision",
          "targetBindingId",
          "expectedTargetVersion",
          "planHash",
          "name",
          "overwriteConsentRef",
          "uploadConsentRef",
          "expectedEpochs",
          "cancelEpoch"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "requestId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "idempotencyKey": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "checkpoint",
              "saveManaged",
              "saveBoundPackage",
              "namedVersion",
              "backup",
              "portableArchive"
            ]
          },
          "revision": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedTargetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "planHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "name": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 128
              },
              {
                "type": "null"
              }
            ]
          },
          "overwriteConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "uploadConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          },
          "cancelEpoch": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "Checkpoint": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "epochs",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "SaveReceipt": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "operationId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "targetBindingId",
          "artifactHash",
          "targetVersion",
          "publication",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "id": {
            "$ref": "#/$defs/Id"
          },
          "operationId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "artifactHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "publication": {
            "enum": [
              "localDurable",
              "providerAcceptedVerified",
              "providerAcceptedUnverified"
            ]
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "ArchiveDescriptor": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "archiveId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "mode",
          "sourceCompleteness",
          "creativeCompletion",
          "inventoryPath",
          "epochs",
          "pendingOperations",
          "omissions",
          "historyPolicy",
          "sessionPolicy",
          "redactionReportHash",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-document-lifecycle"
          },
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "mode": {
            "enum": [
              "originals",
              "proxies",
              "linked"
            ]
          },
          "sourceCompleteness": {
            "enum": [
              "selfContained",
              "proxyOnly",
              "externalRefs",
              "incomplete"
            ]
          },
          "creativeCompletion": {
            "enum": [
              "complete",
              "pendingJobs"
            ]
          },
          "inventoryPath": {
            "const": "extensions/document-lifecycle/inventory.json"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "pendingOperations": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/PendingOperation"
            },
            "maxItems": 10000
          },
          "omissions": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/Omission"
            },
            "maxItems": 100000
          },
          "historyPolicy": {
            "enum": [
              "currentOnly",
              "selectedRevisions"
            ]
          },
          "sessionPolicy": {
            "enum": [
              "excluded",
              "headersOnly",
              "selectedContent"
            ]
          },
          "redactionReportHash": {
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
          }
        }
      },
      "ResourceInventory": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "archiveId",
          "entries"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "entries": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/InventoryEntry"
            },
            "maxItems": 100000
          }
        }
      },
      "RestoreVersion": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "type",
          "id",
          "namespace",
          "projectId",
          "expectedRevision",
          "actorId",
          "receiptKey",
          "operation",
          "expectedEpochs"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "type": {
            "const": "documentLifecycle"
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
          "expectedRevision": {
            "$ref": "#/$defs/U64"
          },
          "actorId": {
            "$ref": "#/$defs/Id"
          },
          "receiptKey": {
            "$ref": "#/$defs/Id"
          },
          "operation": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "sourceCheckpointId",
              "sourceSnapshotHash",
              "restorePlanHash",
              "protectedFieldsConsentRef"
            ],
            "properties": {
              "kind": {
                "const": "restoreVersion"
              },
              "sourceCheckpointId": {
                "$ref": "#/$defs/Id"
              },
              "sourceSnapshotHash": {
                "$ref": "#/$defs/Hash"
              },
              "restorePlanHash": {
                "$ref": "#/$defs/Hash"
              },
              "protectedFieldsConsentRef": {
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
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          }
        }
      },
      "BackupChunk": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "BackupObject": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes",
          "storage",
          "chunks"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          },
          "storage": {
            "enum": [
              "whole",
              "chunked4MiB"
            ]
          },
          "chunks": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupChunk"
            },
            "maxItems": 131072
          }
        }
      },
      "BackupIndex": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "checkpointId",
          "snapshotHash",
          "inventoryHash",
          "epochs",
          "objects",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-private-backup"
          },
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "checkpointId": {
            "$ref": "#/$defs/Id"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "inventoryHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "objects": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupObject"
            },
            "maxItems": 100000
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "AutosavePolicy": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "debounceMs",
          "maxIntervalMs",
          "maxCommands",
          "externalPackageAuto"
        ],
        "properties": {
          "debounceMs": {
            "type": "integer",
            "minimum": 250,
            "maximum": 10000,
            "default": 2000
          },
          "maxIntervalMs": {
            "type": "integer",
            "minimum": 1000,
            "maximum": 300000,
            "default": 30000
          },
          "maxCommands": {
            "type": "integer",
            "minimum": 1,
            "maximum": 1000,
            "default": 50
          },
          "externalPackageAuto": {
            "type": "boolean",
            "default": false
          }
        }
      }
    }
  },
  "checkpoint": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://studio.invalid/schemas/document-lifecycle/Checkpoint-1.0.0.json",
    "$ref": "#/$defs/Checkpoint",
    "$defs": {
      "Id": {
        "type": "string",
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
      },
      "U64": {
        "type": "string",
        "pattern": "^(0|[1-9][0-9]{0,18})$"
      },
      "Hash": {
        "type": "string",
        "pattern": "^sha256:[0-9a-f]{64}$"
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
      "RelativePath": {
        "type": "string",
        "minLength": 1,
        "maxLength": 1024,
        "pattern": "^[A-Za-z0-9_./-]+$"
      },
      "Epochs": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "privacy",
          "rights"
        ],
        "properties": {
          "privacy": {
            "$ref": "#/$defs/U64"
          },
          "rights": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "ResourceKind": {
        "enum": [
          "original",
          "generated",
          "proxy",
          "font",
          "model",
          "lora",
          "character",
          "skill",
          "session",
          "project",
          "history",
          "license",
          "evidence",
          "thumbnail",
          "render"
        ]
      },
      "PendingOperation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "logicalId",
          "kind",
          "shotId",
          "stateAtFreeze",
          "remoteResumeIncluded"
        ],
        "properties": {
          "logicalId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "video",
              "music",
              "sfx",
              "analysis"
            ]
          },
          "shotId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "stateAtFreeze": {
            "enum": [
              "queued",
              "running",
              "unknown"
            ]
          },
          "remoteResumeIncluded": {
            "const": false
          }
        }
      },
      "Omission": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "resourceRef",
          "kind",
          "reason",
          "impact"
        ],
        "properties": {
          "resourceRef": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "reason": {
            "enum": [
              "external",
              "notRedistributable",
              "purged",
              "missing",
              "notSelected",
              "unresolvedExtension"
            ]
          },
          "impact": {
            "enum": [
              "blocksFinalRender",
              "previewOnly",
              "reproGeneration",
              "rebuildable",
              "historicalOnly"
            ]
          }
        }
      },
      "InventoryEntry": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "refId",
          "kind",
          "blobHash",
          "bytes",
          "embeddedPath",
          "externalRef",
          "requiredFor",
          "redistribution",
          "rightsRecordRef"
        ],
        "properties": {
          "refId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "blobHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "bytes": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "embeddedPath": {
            "anyOf": [
              {
                "$ref": "#/$defs/RelativePath"
              },
              {
                "type": "null"
              }
            ]
          },
          "externalRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "requiredFor": {
            "type": "array",
            "items": {
              "enum": [
                "preview",
                "finalRender",
                "reproGeneration",
                "audit"
              ]
            },
            "maxItems": 4,
            "uniqueItems": true
          },
          "redistribution": {
            "enum": [
              "allowed",
              "forbidden",
              "unknown"
            ]
          },
          "rightsRecordRef": {
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
      "SaveRequest": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "requestId",
          "namespace",
          "projectId",
          "idempotencyKey",
          "kind",
          "revision",
          "targetBindingId",
          "expectedTargetVersion",
          "planHash",
          "name",
          "overwriteConsentRef",
          "uploadConsentRef",
          "expectedEpochs",
          "cancelEpoch"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "requestId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "idempotencyKey": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "checkpoint",
              "saveManaged",
              "saveBoundPackage",
              "namedVersion",
              "backup",
              "portableArchive"
            ]
          },
          "revision": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedTargetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "planHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "name": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 128
              },
              {
                "type": "null"
              }
            ]
          },
          "overwriteConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "uploadConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          },
          "cancelEpoch": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "Checkpoint": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "epochs",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "SaveReceipt": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "operationId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "targetBindingId",
          "artifactHash",
          "targetVersion",
          "publication",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "id": {
            "$ref": "#/$defs/Id"
          },
          "operationId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "artifactHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "publication": {
            "enum": [
              "localDurable",
              "providerAcceptedVerified",
              "providerAcceptedUnverified"
            ]
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "ArchiveDescriptor": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "archiveId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "mode",
          "sourceCompleteness",
          "creativeCompletion",
          "inventoryPath",
          "epochs",
          "pendingOperations",
          "omissions",
          "historyPolicy",
          "sessionPolicy",
          "redactionReportHash",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-document-lifecycle"
          },
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "mode": {
            "enum": [
              "originals",
              "proxies",
              "linked"
            ]
          },
          "sourceCompleteness": {
            "enum": [
              "selfContained",
              "proxyOnly",
              "externalRefs",
              "incomplete"
            ]
          },
          "creativeCompletion": {
            "enum": [
              "complete",
              "pendingJobs"
            ]
          },
          "inventoryPath": {
            "const": "extensions/document-lifecycle/inventory.json"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "pendingOperations": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/PendingOperation"
            },
            "maxItems": 10000
          },
          "omissions": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/Omission"
            },
            "maxItems": 100000
          },
          "historyPolicy": {
            "enum": [
              "currentOnly",
              "selectedRevisions"
            ]
          },
          "sessionPolicy": {
            "enum": [
              "excluded",
              "headersOnly",
              "selectedContent"
            ]
          },
          "redactionReportHash": {
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
          }
        }
      },
      "ResourceInventory": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "archiveId",
          "entries"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "entries": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/InventoryEntry"
            },
            "maxItems": 100000
          }
        }
      },
      "RestoreVersion": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "type",
          "id",
          "namespace",
          "projectId",
          "expectedRevision",
          "actorId",
          "receiptKey",
          "operation",
          "expectedEpochs"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "type": {
            "const": "documentLifecycle"
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
          "expectedRevision": {
            "$ref": "#/$defs/U64"
          },
          "actorId": {
            "$ref": "#/$defs/Id"
          },
          "receiptKey": {
            "$ref": "#/$defs/Id"
          },
          "operation": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "sourceCheckpointId",
              "sourceSnapshotHash",
              "restorePlanHash",
              "protectedFieldsConsentRef"
            ],
            "properties": {
              "kind": {
                "const": "restoreVersion"
              },
              "sourceCheckpointId": {
                "$ref": "#/$defs/Id"
              },
              "sourceSnapshotHash": {
                "$ref": "#/$defs/Hash"
              },
              "restorePlanHash": {
                "$ref": "#/$defs/Hash"
              },
              "protectedFieldsConsentRef": {
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
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          }
        }
      },
      "BackupChunk": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "BackupObject": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes",
          "storage",
          "chunks"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          },
          "storage": {
            "enum": [
              "whole",
              "chunked4MiB"
            ]
          },
          "chunks": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupChunk"
            },
            "maxItems": 131072
          }
        }
      },
      "BackupIndex": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "checkpointId",
          "snapshotHash",
          "inventoryHash",
          "epochs",
          "objects",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-private-backup"
          },
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "checkpointId": {
            "$ref": "#/$defs/Id"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "inventoryHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "objects": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupObject"
            },
            "maxItems": 100000
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "AutosavePolicy": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "debounceMs",
          "maxIntervalMs",
          "maxCommands",
          "externalPackageAuto"
        ],
        "properties": {
          "debounceMs": {
            "type": "integer",
            "minimum": 250,
            "maximum": 10000,
            "default": 2000
          },
          "maxIntervalMs": {
            "type": "integer",
            "minimum": 1000,
            "maximum": 300000,
            "default": 30000
          },
          "maxCommands": {
            "type": "integer",
            "minimum": 1,
            "maximum": 1000,
            "default": 50
          },
          "externalPackageAuto": {
            "type": "boolean",
            "default": false
          }
        }
      }
    }
  },
  "saveReceipt": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://studio.invalid/schemas/document-lifecycle/SaveReceipt-1.0.0.json",
    "$ref": "#/$defs/SaveReceipt",
    "$defs": {
      "Id": {
        "type": "string",
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
      },
      "U64": {
        "type": "string",
        "pattern": "^(0|[1-9][0-9]{0,18})$"
      },
      "Hash": {
        "type": "string",
        "pattern": "^sha256:[0-9a-f]{64}$"
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
      "RelativePath": {
        "type": "string",
        "minLength": 1,
        "maxLength": 1024,
        "pattern": "^[A-Za-z0-9_./-]+$"
      },
      "Epochs": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "privacy",
          "rights"
        ],
        "properties": {
          "privacy": {
            "$ref": "#/$defs/U64"
          },
          "rights": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "ResourceKind": {
        "enum": [
          "original",
          "generated",
          "proxy",
          "font",
          "model",
          "lora",
          "character",
          "skill",
          "session",
          "project",
          "history",
          "license",
          "evidence",
          "thumbnail",
          "render"
        ]
      },
      "PendingOperation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "logicalId",
          "kind",
          "shotId",
          "stateAtFreeze",
          "remoteResumeIncluded"
        ],
        "properties": {
          "logicalId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "video",
              "music",
              "sfx",
              "analysis"
            ]
          },
          "shotId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "stateAtFreeze": {
            "enum": [
              "queued",
              "running",
              "unknown"
            ]
          },
          "remoteResumeIncluded": {
            "const": false
          }
        }
      },
      "Omission": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "resourceRef",
          "kind",
          "reason",
          "impact"
        ],
        "properties": {
          "resourceRef": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "reason": {
            "enum": [
              "external",
              "notRedistributable",
              "purged",
              "missing",
              "notSelected",
              "unresolvedExtension"
            ]
          },
          "impact": {
            "enum": [
              "blocksFinalRender",
              "previewOnly",
              "reproGeneration",
              "rebuildable",
              "historicalOnly"
            ]
          }
        }
      },
      "InventoryEntry": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "refId",
          "kind",
          "blobHash",
          "bytes",
          "embeddedPath",
          "externalRef",
          "requiredFor",
          "redistribution",
          "rightsRecordRef"
        ],
        "properties": {
          "refId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "blobHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "bytes": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "embeddedPath": {
            "anyOf": [
              {
                "$ref": "#/$defs/RelativePath"
              },
              {
                "type": "null"
              }
            ]
          },
          "externalRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "requiredFor": {
            "type": "array",
            "items": {
              "enum": [
                "preview",
                "finalRender",
                "reproGeneration",
                "audit"
              ]
            },
            "maxItems": 4,
            "uniqueItems": true
          },
          "redistribution": {
            "enum": [
              "allowed",
              "forbidden",
              "unknown"
            ]
          },
          "rightsRecordRef": {
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
      "SaveRequest": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "requestId",
          "namespace",
          "projectId",
          "idempotencyKey",
          "kind",
          "revision",
          "targetBindingId",
          "expectedTargetVersion",
          "planHash",
          "name",
          "overwriteConsentRef",
          "uploadConsentRef",
          "expectedEpochs",
          "cancelEpoch"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "requestId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "idempotencyKey": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "checkpoint",
              "saveManaged",
              "saveBoundPackage",
              "namedVersion",
              "backup",
              "portableArchive"
            ]
          },
          "revision": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedTargetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "planHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "name": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 128
              },
              {
                "type": "null"
              }
            ]
          },
          "overwriteConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "uploadConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          },
          "cancelEpoch": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "Checkpoint": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "epochs",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "SaveReceipt": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "operationId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "targetBindingId",
          "artifactHash",
          "targetVersion",
          "publication",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "id": {
            "$ref": "#/$defs/Id"
          },
          "operationId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "artifactHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "publication": {
            "enum": [
              "localDurable",
              "providerAcceptedVerified",
              "providerAcceptedUnverified"
            ]
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "ArchiveDescriptor": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "archiveId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "mode",
          "sourceCompleteness",
          "creativeCompletion",
          "inventoryPath",
          "epochs",
          "pendingOperations",
          "omissions",
          "historyPolicy",
          "sessionPolicy",
          "redactionReportHash",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-document-lifecycle"
          },
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "mode": {
            "enum": [
              "originals",
              "proxies",
              "linked"
            ]
          },
          "sourceCompleteness": {
            "enum": [
              "selfContained",
              "proxyOnly",
              "externalRefs",
              "incomplete"
            ]
          },
          "creativeCompletion": {
            "enum": [
              "complete",
              "pendingJobs"
            ]
          },
          "inventoryPath": {
            "const": "extensions/document-lifecycle/inventory.json"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "pendingOperations": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/PendingOperation"
            },
            "maxItems": 10000
          },
          "omissions": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/Omission"
            },
            "maxItems": 100000
          },
          "historyPolicy": {
            "enum": [
              "currentOnly",
              "selectedRevisions"
            ]
          },
          "sessionPolicy": {
            "enum": [
              "excluded",
              "headersOnly",
              "selectedContent"
            ]
          },
          "redactionReportHash": {
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
          }
        }
      },
      "ResourceInventory": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "archiveId",
          "entries"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "entries": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/InventoryEntry"
            },
            "maxItems": 100000
          }
        }
      },
      "RestoreVersion": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "type",
          "id",
          "namespace",
          "projectId",
          "expectedRevision",
          "actorId",
          "receiptKey",
          "operation",
          "expectedEpochs"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "type": {
            "const": "documentLifecycle"
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
          "expectedRevision": {
            "$ref": "#/$defs/U64"
          },
          "actorId": {
            "$ref": "#/$defs/Id"
          },
          "receiptKey": {
            "$ref": "#/$defs/Id"
          },
          "operation": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "sourceCheckpointId",
              "sourceSnapshotHash",
              "restorePlanHash",
              "protectedFieldsConsentRef"
            ],
            "properties": {
              "kind": {
                "const": "restoreVersion"
              },
              "sourceCheckpointId": {
                "$ref": "#/$defs/Id"
              },
              "sourceSnapshotHash": {
                "$ref": "#/$defs/Hash"
              },
              "restorePlanHash": {
                "$ref": "#/$defs/Hash"
              },
              "protectedFieldsConsentRef": {
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
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          }
        }
      },
      "BackupChunk": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "BackupObject": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes",
          "storage",
          "chunks"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          },
          "storage": {
            "enum": [
              "whole",
              "chunked4MiB"
            ]
          },
          "chunks": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupChunk"
            },
            "maxItems": 131072
          }
        }
      },
      "BackupIndex": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "checkpointId",
          "snapshotHash",
          "inventoryHash",
          "epochs",
          "objects",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-private-backup"
          },
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "checkpointId": {
            "$ref": "#/$defs/Id"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "inventoryHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "objects": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupObject"
            },
            "maxItems": 100000
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "AutosavePolicy": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "debounceMs",
          "maxIntervalMs",
          "maxCommands",
          "externalPackageAuto"
        ],
        "properties": {
          "debounceMs": {
            "type": "integer",
            "minimum": 250,
            "maximum": 10000,
            "default": 2000
          },
          "maxIntervalMs": {
            "type": "integer",
            "minimum": 1000,
            "maximum": 300000,
            "default": 30000
          },
          "maxCommands": {
            "type": "integer",
            "minimum": 1,
            "maximum": 1000,
            "default": 50
          },
          "externalPackageAuto": {
            "type": "boolean",
            "default": false
          }
        }
      }
    }
  },
  "archiveDescriptor": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://studio.invalid/schemas/document-lifecycle/ArchiveDescriptor-1.0.0.json",
    "$ref": "#/$defs/ArchiveDescriptor",
    "$defs": {
      "Id": {
        "type": "string",
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
      },
      "U64": {
        "type": "string",
        "pattern": "^(0|[1-9][0-9]{0,18})$"
      },
      "Hash": {
        "type": "string",
        "pattern": "^sha256:[0-9a-f]{64}$"
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
      "RelativePath": {
        "type": "string",
        "minLength": 1,
        "maxLength": 1024,
        "pattern": "^[A-Za-z0-9_./-]+$"
      },
      "Epochs": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "privacy",
          "rights"
        ],
        "properties": {
          "privacy": {
            "$ref": "#/$defs/U64"
          },
          "rights": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "ResourceKind": {
        "enum": [
          "original",
          "generated",
          "proxy",
          "font",
          "model",
          "lora",
          "character",
          "skill",
          "session",
          "project",
          "history",
          "license",
          "evidence",
          "thumbnail",
          "render"
        ]
      },
      "PendingOperation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "logicalId",
          "kind",
          "shotId",
          "stateAtFreeze",
          "remoteResumeIncluded"
        ],
        "properties": {
          "logicalId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "video",
              "music",
              "sfx",
              "analysis"
            ]
          },
          "shotId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "stateAtFreeze": {
            "enum": [
              "queued",
              "running",
              "unknown"
            ]
          },
          "remoteResumeIncluded": {
            "const": false
          }
        }
      },
      "Omission": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "resourceRef",
          "kind",
          "reason",
          "impact"
        ],
        "properties": {
          "resourceRef": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "reason": {
            "enum": [
              "external",
              "notRedistributable",
              "purged",
              "missing",
              "notSelected",
              "unresolvedExtension"
            ]
          },
          "impact": {
            "enum": [
              "blocksFinalRender",
              "previewOnly",
              "reproGeneration",
              "rebuildable",
              "historicalOnly"
            ]
          }
        }
      },
      "InventoryEntry": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "refId",
          "kind",
          "blobHash",
          "bytes",
          "embeddedPath",
          "externalRef",
          "requiredFor",
          "redistribution",
          "rightsRecordRef"
        ],
        "properties": {
          "refId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "blobHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "bytes": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "embeddedPath": {
            "anyOf": [
              {
                "$ref": "#/$defs/RelativePath"
              },
              {
                "type": "null"
              }
            ]
          },
          "externalRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "requiredFor": {
            "type": "array",
            "items": {
              "enum": [
                "preview",
                "finalRender",
                "reproGeneration",
                "audit"
              ]
            },
            "maxItems": 4,
            "uniqueItems": true
          },
          "redistribution": {
            "enum": [
              "allowed",
              "forbidden",
              "unknown"
            ]
          },
          "rightsRecordRef": {
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
      "SaveRequest": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "requestId",
          "namespace",
          "projectId",
          "idempotencyKey",
          "kind",
          "revision",
          "targetBindingId",
          "expectedTargetVersion",
          "planHash",
          "name",
          "overwriteConsentRef",
          "uploadConsentRef",
          "expectedEpochs",
          "cancelEpoch"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "requestId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "idempotencyKey": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "checkpoint",
              "saveManaged",
              "saveBoundPackage",
              "namedVersion",
              "backup",
              "portableArchive"
            ]
          },
          "revision": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedTargetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "planHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "name": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 128
              },
              {
                "type": "null"
              }
            ]
          },
          "overwriteConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "uploadConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          },
          "cancelEpoch": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "Checkpoint": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "epochs",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "SaveReceipt": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "operationId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "targetBindingId",
          "artifactHash",
          "targetVersion",
          "publication",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "id": {
            "$ref": "#/$defs/Id"
          },
          "operationId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "artifactHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "publication": {
            "enum": [
              "localDurable",
              "providerAcceptedVerified",
              "providerAcceptedUnverified"
            ]
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "ArchiveDescriptor": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "archiveId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "mode",
          "sourceCompleteness",
          "creativeCompletion",
          "inventoryPath",
          "epochs",
          "pendingOperations",
          "omissions",
          "historyPolicy",
          "sessionPolicy",
          "redactionReportHash",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-document-lifecycle"
          },
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "mode": {
            "enum": [
              "originals",
              "proxies",
              "linked"
            ]
          },
          "sourceCompleteness": {
            "enum": [
              "selfContained",
              "proxyOnly",
              "externalRefs",
              "incomplete"
            ]
          },
          "creativeCompletion": {
            "enum": [
              "complete",
              "pendingJobs"
            ]
          },
          "inventoryPath": {
            "const": "extensions/document-lifecycle/inventory.json"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "pendingOperations": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/PendingOperation"
            },
            "maxItems": 10000
          },
          "omissions": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/Omission"
            },
            "maxItems": 100000
          },
          "historyPolicy": {
            "enum": [
              "currentOnly",
              "selectedRevisions"
            ]
          },
          "sessionPolicy": {
            "enum": [
              "excluded",
              "headersOnly",
              "selectedContent"
            ]
          },
          "redactionReportHash": {
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
          }
        }
      },
      "ResourceInventory": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "archiveId",
          "entries"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "entries": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/InventoryEntry"
            },
            "maxItems": 100000
          }
        }
      },
      "RestoreVersion": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "type",
          "id",
          "namespace",
          "projectId",
          "expectedRevision",
          "actorId",
          "receiptKey",
          "operation",
          "expectedEpochs"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "type": {
            "const": "documentLifecycle"
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
          "expectedRevision": {
            "$ref": "#/$defs/U64"
          },
          "actorId": {
            "$ref": "#/$defs/Id"
          },
          "receiptKey": {
            "$ref": "#/$defs/Id"
          },
          "operation": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "sourceCheckpointId",
              "sourceSnapshotHash",
              "restorePlanHash",
              "protectedFieldsConsentRef"
            ],
            "properties": {
              "kind": {
                "const": "restoreVersion"
              },
              "sourceCheckpointId": {
                "$ref": "#/$defs/Id"
              },
              "sourceSnapshotHash": {
                "$ref": "#/$defs/Hash"
              },
              "restorePlanHash": {
                "$ref": "#/$defs/Hash"
              },
              "protectedFieldsConsentRef": {
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
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          }
        }
      },
      "BackupChunk": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "BackupObject": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes",
          "storage",
          "chunks"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          },
          "storage": {
            "enum": [
              "whole",
              "chunked4MiB"
            ]
          },
          "chunks": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupChunk"
            },
            "maxItems": 131072
          }
        }
      },
      "BackupIndex": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "checkpointId",
          "snapshotHash",
          "inventoryHash",
          "epochs",
          "objects",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-private-backup"
          },
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "checkpointId": {
            "$ref": "#/$defs/Id"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "inventoryHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "objects": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupObject"
            },
            "maxItems": 100000
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "AutosavePolicy": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "debounceMs",
          "maxIntervalMs",
          "maxCommands",
          "externalPackageAuto"
        ],
        "properties": {
          "debounceMs": {
            "type": "integer",
            "minimum": 250,
            "maximum": 10000,
            "default": 2000
          },
          "maxIntervalMs": {
            "type": "integer",
            "minimum": 1000,
            "maximum": 300000,
            "default": 30000
          },
          "maxCommands": {
            "type": "integer",
            "minimum": 1,
            "maximum": 1000,
            "default": 50
          },
          "externalPackageAuto": {
            "type": "boolean",
            "default": false
          }
        }
      }
    }
  },
  "resourceInventory": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://studio.invalid/schemas/document-lifecycle/ResourceInventory-1.0.0.json",
    "$ref": "#/$defs/ResourceInventory",
    "$defs": {
      "Id": {
        "type": "string",
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
      },
      "U64": {
        "type": "string",
        "pattern": "^(0|[1-9][0-9]{0,18})$"
      },
      "Hash": {
        "type": "string",
        "pattern": "^sha256:[0-9a-f]{64}$"
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
      "RelativePath": {
        "type": "string",
        "minLength": 1,
        "maxLength": 1024,
        "pattern": "^[A-Za-z0-9_./-]+$"
      },
      "Epochs": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "privacy",
          "rights"
        ],
        "properties": {
          "privacy": {
            "$ref": "#/$defs/U64"
          },
          "rights": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "ResourceKind": {
        "enum": [
          "original",
          "generated",
          "proxy",
          "font",
          "model",
          "lora",
          "character",
          "skill",
          "session",
          "project",
          "history",
          "license",
          "evidence",
          "thumbnail",
          "render"
        ]
      },
      "PendingOperation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "logicalId",
          "kind",
          "shotId",
          "stateAtFreeze",
          "remoteResumeIncluded"
        ],
        "properties": {
          "logicalId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "video",
              "music",
              "sfx",
              "analysis"
            ]
          },
          "shotId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "stateAtFreeze": {
            "enum": [
              "queued",
              "running",
              "unknown"
            ]
          },
          "remoteResumeIncluded": {
            "const": false
          }
        }
      },
      "Omission": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "resourceRef",
          "kind",
          "reason",
          "impact"
        ],
        "properties": {
          "resourceRef": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "reason": {
            "enum": [
              "external",
              "notRedistributable",
              "purged",
              "missing",
              "notSelected",
              "unresolvedExtension"
            ]
          },
          "impact": {
            "enum": [
              "blocksFinalRender",
              "previewOnly",
              "reproGeneration",
              "rebuildable",
              "historicalOnly"
            ]
          }
        }
      },
      "InventoryEntry": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "refId",
          "kind",
          "blobHash",
          "bytes",
          "embeddedPath",
          "externalRef",
          "requiredFor",
          "redistribution",
          "rightsRecordRef"
        ],
        "properties": {
          "refId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "blobHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "bytes": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "embeddedPath": {
            "anyOf": [
              {
                "$ref": "#/$defs/RelativePath"
              },
              {
                "type": "null"
              }
            ]
          },
          "externalRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "requiredFor": {
            "type": "array",
            "items": {
              "enum": [
                "preview",
                "finalRender",
                "reproGeneration",
                "audit"
              ]
            },
            "maxItems": 4,
            "uniqueItems": true
          },
          "redistribution": {
            "enum": [
              "allowed",
              "forbidden",
              "unknown"
            ]
          },
          "rightsRecordRef": {
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
      "SaveRequest": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "requestId",
          "namespace",
          "projectId",
          "idempotencyKey",
          "kind",
          "revision",
          "targetBindingId",
          "expectedTargetVersion",
          "planHash",
          "name",
          "overwriteConsentRef",
          "uploadConsentRef",
          "expectedEpochs",
          "cancelEpoch"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "requestId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "idempotencyKey": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "checkpoint",
              "saveManaged",
              "saveBoundPackage",
              "namedVersion",
              "backup",
              "portableArchive"
            ]
          },
          "revision": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedTargetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "planHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "name": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 128
              },
              {
                "type": "null"
              }
            ]
          },
          "overwriteConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "uploadConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          },
          "cancelEpoch": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "Checkpoint": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "epochs",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "SaveReceipt": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "operationId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "targetBindingId",
          "artifactHash",
          "targetVersion",
          "publication",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "id": {
            "$ref": "#/$defs/Id"
          },
          "operationId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "artifactHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "publication": {
            "enum": [
              "localDurable",
              "providerAcceptedVerified",
              "providerAcceptedUnverified"
            ]
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "ArchiveDescriptor": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "archiveId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "mode",
          "sourceCompleteness",
          "creativeCompletion",
          "inventoryPath",
          "epochs",
          "pendingOperations",
          "omissions",
          "historyPolicy",
          "sessionPolicy",
          "redactionReportHash",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-document-lifecycle"
          },
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "mode": {
            "enum": [
              "originals",
              "proxies",
              "linked"
            ]
          },
          "sourceCompleteness": {
            "enum": [
              "selfContained",
              "proxyOnly",
              "externalRefs",
              "incomplete"
            ]
          },
          "creativeCompletion": {
            "enum": [
              "complete",
              "pendingJobs"
            ]
          },
          "inventoryPath": {
            "const": "extensions/document-lifecycle/inventory.json"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "pendingOperations": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/PendingOperation"
            },
            "maxItems": 10000
          },
          "omissions": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/Omission"
            },
            "maxItems": 100000
          },
          "historyPolicy": {
            "enum": [
              "currentOnly",
              "selectedRevisions"
            ]
          },
          "sessionPolicy": {
            "enum": [
              "excluded",
              "headersOnly",
              "selectedContent"
            ]
          },
          "redactionReportHash": {
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
          }
        }
      },
      "ResourceInventory": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "archiveId",
          "entries"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "entries": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/InventoryEntry"
            },
            "maxItems": 100000
          }
        }
      },
      "RestoreVersion": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "type",
          "id",
          "namespace",
          "projectId",
          "expectedRevision",
          "actorId",
          "receiptKey",
          "operation",
          "expectedEpochs"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "type": {
            "const": "documentLifecycle"
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
          "expectedRevision": {
            "$ref": "#/$defs/U64"
          },
          "actorId": {
            "$ref": "#/$defs/Id"
          },
          "receiptKey": {
            "$ref": "#/$defs/Id"
          },
          "operation": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "sourceCheckpointId",
              "sourceSnapshotHash",
              "restorePlanHash",
              "protectedFieldsConsentRef"
            ],
            "properties": {
              "kind": {
                "const": "restoreVersion"
              },
              "sourceCheckpointId": {
                "$ref": "#/$defs/Id"
              },
              "sourceSnapshotHash": {
                "$ref": "#/$defs/Hash"
              },
              "restorePlanHash": {
                "$ref": "#/$defs/Hash"
              },
              "protectedFieldsConsentRef": {
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
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          }
        }
      },
      "BackupChunk": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "BackupObject": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes",
          "storage",
          "chunks"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          },
          "storage": {
            "enum": [
              "whole",
              "chunked4MiB"
            ]
          },
          "chunks": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupChunk"
            },
            "maxItems": 131072
          }
        }
      },
      "BackupIndex": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "checkpointId",
          "snapshotHash",
          "inventoryHash",
          "epochs",
          "objects",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-private-backup"
          },
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "checkpointId": {
            "$ref": "#/$defs/Id"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "inventoryHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "objects": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupObject"
            },
            "maxItems": 100000
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "AutosavePolicy": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "debounceMs",
          "maxIntervalMs",
          "maxCommands",
          "externalPackageAuto"
        ],
        "properties": {
          "debounceMs": {
            "type": "integer",
            "minimum": 250,
            "maximum": 10000,
            "default": 2000
          },
          "maxIntervalMs": {
            "type": "integer",
            "minimum": 1000,
            "maximum": 300000,
            "default": 30000
          },
          "maxCommands": {
            "type": "integer",
            "minimum": 1,
            "maximum": 1000,
            "default": 50
          },
          "externalPackageAuto": {
            "type": "boolean",
            "default": false
          }
        }
      }
    }
  },
  "restoreVersion": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://studio.invalid/schemas/document-lifecycle/RestoreVersion-1.0.0.json",
    "$ref": "#/$defs/RestoreVersion",
    "$defs": {
      "Id": {
        "type": "string",
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
      },
      "U64": {
        "type": "string",
        "pattern": "^(0|[1-9][0-9]{0,18})$"
      },
      "Hash": {
        "type": "string",
        "pattern": "^sha256:[0-9a-f]{64}$"
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
      "RelativePath": {
        "type": "string",
        "minLength": 1,
        "maxLength": 1024,
        "pattern": "^[A-Za-z0-9_./-]+$"
      },
      "Epochs": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "privacy",
          "rights"
        ],
        "properties": {
          "privacy": {
            "$ref": "#/$defs/U64"
          },
          "rights": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "ResourceKind": {
        "enum": [
          "original",
          "generated",
          "proxy",
          "font",
          "model",
          "lora",
          "character",
          "skill",
          "session",
          "project",
          "history",
          "license",
          "evidence",
          "thumbnail",
          "render"
        ]
      },
      "PendingOperation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "logicalId",
          "kind",
          "shotId",
          "stateAtFreeze",
          "remoteResumeIncluded"
        ],
        "properties": {
          "logicalId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "video",
              "music",
              "sfx",
              "analysis"
            ]
          },
          "shotId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "stateAtFreeze": {
            "enum": [
              "queued",
              "running",
              "unknown"
            ]
          },
          "remoteResumeIncluded": {
            "const": false
          }
        }
      },
      "Omission": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "resourceRef",
          "kind",
          "reason",
          "impact"
        ],
        "properties": {
          "resourceRef": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "reason": {
            "enum": [
              "external",
              "notRedistributable",
              "purged",
              "missing",
              "notSelected",
              "unresolvedExtension"
            ]
          },
          "impact": {
            "enum": [
              "blocksFinalRender",
              "previewOnly",
              "reproGeneration",
              "rebuildable",
              "historicalOnly"
            ]
          }
        }
      },
      "InventoryEntry": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "refId",
          "kind",
          "blobHash",
          "bytes",
          "embeddedPath",
          "externalRef",
          "requiredFor",
          "redistribution",
          "rightsRecordRef"
        ],
        "properties": {
          "refId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "blobHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "bytes": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "embeddedPath": {
            "anyOf": [
              {
                "$ref": "#/$defs/RelativePath"
              },
              {
                "type": "null"
              }
            ]
          },
          "externalRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "requiredFor": {
            "type": "array",
            "items": {
              "enum": [
                "preview",
                "finalRender",
                "reproGeneration",
                "audit"
              ]
            },
            "maxItems": 4,
            "uniqueItems": true
          },
          "redistribution": {
            "enum": [
              "allowed",
              "forbidden",
              "unknown"
            ]
          },
          "rightsRecordRef": {
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
      "SaveRequest": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "requestId",
          "namespace",
          "projectId",
          "idempotencyKey",
          "kind",
          "revision",
          "targetBindingId",
          "expectedTargetVersion",
          "planHash",
          "name",
          "overwriteConsentRef",
          "uploadConsentRef",
          "expectedEpochs",
          "cancelEpoch"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "requestId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "idempotencyKey": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "checkpoint",
              "saveManaged",
              "saveBoundPackage",
              "namedVersion",
              "backup",
              "portableArchive"
            ]
          },
          "revision": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedTargetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "planHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "name": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 128
              },
              {
                "type": "null"
              }
            ]
          },
          "overwriteConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "uploadConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          },
          "cancelEpoch": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "Checkpoint": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "epochs",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "SaveReceipt": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "operationId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "targetBindingId",
          "artifactHash",
          "targetVersion",
          "publication",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "id": {
            "$ref": "#/$defs/Id"
          },
          "operationId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "artifactHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "publication": {
            "enum": [
              "localDurable",
              "providerAcceptedVerified",
              "providerAcceptedUnverified"
            ]
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "ArchiveDescriptor": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "archiveId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "mode",
          "sourceCompleteness",
          "creativeCompletion",
          "inventoryPath",
          "epochs",
          "pendingOperations",
          "omissions",
          "historyPolicy",
          "sessionPolicy",
          "redactionReportHash",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-document-lifecycle"
          },
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "mode": {
            "enum": [
              "originals",
              "proxies",
              "linked"
            ]
          },
          "sourceCompleteness": {
            "enum": [
              "selfContained",
              "proxyOnly",
              "externalRefs",
              "incomplete"
            ]
          },
          "creativeCompletion": {
            "enum": [
              "complete",
              "pendingJobs"
            ]
          },
          "inventoryPath": {
            "const": "extensions/document-lifecycle/inventory.json"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "pendingOperations": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/PendingOperation"
            },
            "maxItems": 10000
          },
          "omissions": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/Omission"
            },
            "maxItems": 100000
          },
          "historyPolicy": {
            "enum": [
              "currentOnly",
              "selectedRevisions"
            ]
          },
          "sessionPolicy": {
            "enum": [
              "excluded",
              "headersOnly",
              "selectedContent"
            ]
          },
          "redactionReportHash": {
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
          }
        }
      },
      "ResourceInventory": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "archiveId",
          "entries"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "entries": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/InventoryEntry"
            },
            "maxItems": 100000
          }
        }
      },
      "RestoreVersion": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "type",
          "id",
          "namespace",
          "projectId",
          "expectedRevision",
          "actorId",
          "receiptKey",
          "operation",
          "expectedEpochs"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "type": {
            "const": "documentLifecycle"
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
          "expectedRevision": {
            "$ref": "#/$defs/U64"
          },
          "actorId": {
            "$ref": "#/$defs/Id"
          },
          "receiptKey": {
            "$ref": "#/$defs/Id"
          },
          "operation": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "sourceCheckpointId",
              "sourceSnapshotHash",
              "restorePlanHash",
              "protectedFieldsConsentRef"
            ],
            "properties": {
              "kind": {
                "const": "restoreVersion"
              },
              "sourceCheckpointId": {
                "$ref": "#/$defs/Id"
              },
              "sourceSnapshotHash": {
                "$ref": "#/$defs/Hash"
              },
              "restorePlanHash": {
                "$ref": "#/$defs/Hash"
              },
              "protectedFieldsConsentRef": {
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
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          }
        }
      },
      "BackupChunk": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "BackupObject": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes",
          "storage",
          "chunks"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          },
          "storage": {
            "enum": [
              "whole",
              "chunked4MiB"
            ]
          },
          "chunks": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupChunk"
            },
            "maxItems": 131072
          }
        }
      },
      "BackupIndex": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "checkpointId",
          "snapshotHash",
          "inventoryHash",
          "epochs",
          "objects",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-private-backup"
          },
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "checkpointId": {
            "$ref": "#/$defs/Id"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "inventoryHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "objects": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupObject"
            },
            "maxItems": 100000
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "AutosavePolicy": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "debounceMs",
          "maxIntervalMs",
          "maxCommands",
          "externalPackageAuto"
        ],
        "properties": {
          "debounceMs": {
            "type": "integer",
            "minimum": 250,
            "maximum": 10000,
            "default": 2000
          },
          "maxIntervalMs": {
            "type": "integer",
            "minimum": 1000,
            "maximum": 300000,
            "default": 30000
          },
          "maxCommands": {
            "type": "integer",
            "minimum": 1,
            "maximum": 1000,
            "default": 50
          },
          "externalPackageAuto": {
            "type": "boolean",
            "default": false
          }
        }
      }
    }
  },
  "autosavePolicy": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://studio.invalid/schemas/document-lifecycle/AutosavePolicy-1.0.0.json",
    "$ref": "#/$defs/AutosavePolicy",
    "$defs": {
      "Id": {
        "type": "string",
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
      },
      "U64": {
        "type": "string",
        "pattern": "^(0|[1-9][0-9]{0,18})$"
      },
      "Hash": {
        "type": "string",
        "pattern": "^sha256:[0-9a-f]{64}$"
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
      "RelativePath": {
        "type": "string",
        "minLength": 1,
        "maxLength": 1024,
        "pattern": "^[A-Za-z0-9_./-]+$"
      },
      "Epochs": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "privacy",
          "rights"
        ],
        "properties": {
          "privacy": {
            "$ref": "#/$defs/U64"
          },
          "rights": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "ResourceKind": {
        "enum": [
          "original",
          "generated",
          "proxy",
          "font",
          "model",
          "lora",
          "character",
          "skill",
          "session",
          "project",
          "history",
          "license",
          "evidence",
          "thumbnail",
          "render"
        ]
      },
      "PendingOperation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "logicalId",
          "kind",
          "shotId",
          "stateAtFreeze",
          "remoteResumeIncluded"
        ],
        "properties": {
          "logicalId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "video",
              "music",
              "sfx",
              "analysis"
            ]
          },
          "shotId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "stateAtFreeze": {
            "enum": [
              "queued",
              "running",
              "unknown"
            ]
          },
          "remoteResumeIncluded": {
            "const": false
          }
        }
      },
      "Omission": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "resourceRef",
          "kind",
          "reason",
          "impact"
        ],
        "properties": {
          "resourceRef": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "reason": {
            "enum": [
              "external",
              "notRedistributable",
              "purged",
              "missing",
              "notSelected",
              "unresolvedExtension"
            ]
          },
          "impact": {
            "enum": [
              "blocksFinalRender",
              "previewOnly",
              "reproGeneration",
              "rebuildable",
              "historicalOnly"
            ]
          }
        }
      },
      "InventoryEntry": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "refId",
          "kind",
          "blobHash",
          "bytes",
          "embeddedPath",
          "externalRef",
          "requiredFor",
          "redistribution",
          "rightsRecordRef"
        ],
        "properties": {
          "refId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "blobHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "bytes": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "embeddedPath": {
            "anyOf": [
              {
                "$ref": "#/$defs/RelativePath"
              },
              {
                "type": "null"
              }
            ]
          },
          "externalRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "requiredFor": {
            "type": "array",
            "items": {
              "enum": [
                "preview",
                "finalRender",
                "reproGeneration",
                "audit"
              ]
            },
            "maxItems": 4,
            "uniqueItems": true
          },
          "redistribution": {
            "enum": [
              "allowed",
              "forbidden",
              "unknown"
            ]
          },
          "rightsRecordRef": {
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
      "SaveRequest": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "requestId",
          "namespace",
          "projectId",
          "idempotencyKey",
          "kind",
          "revision",
          "targetBindingId",
          "expectedTargetVersion",
          "planHash",
          "name",
          "overwriteConsentRef",
          "uploadConsentRef",
          "expectedEpochs",
          "cancelEpoch"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "requestId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "idempotencyKey": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "checkpoint",
              "saveManaged",
              "saveBoundPackage",
              "namedVersion",
              "backup",
              "portableArchive"
            ]
          },
          "revision": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedTargetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "planHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "name": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 128
              },
              {
                "type": "null"
              }
            ]
          },
          "overwriteConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "uploadConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          },
          "cancelEpoch": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "Checkpoint": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "epochs",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "SaveReceipt": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "operationId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "targetBindingId",
          "artifactHash",
          "targetVersion",
          "publication",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "id": {
            "$ref": "#/$defs/Id"
          },
          "operationId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "artifactHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "publication": {
            "enum": [
              "localDurable",
              "providerAcceptedVerified",
              "providerAcceptedUnverified"
            ]
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "ArchiveDescriptor": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "archiveId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "mode",
          "sourceCompleteness",
          "creativeCompletion",
          "inventoryPath",
          "epochs",
          "pendingOperations",
          "omissions",
          "historyPolicy",
          "sessionPolicy",
          "redactionReportHash",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-document-lifecycle"
          },
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "mode": {
            "enum": [
              "originals",
              "proxies",
              "linked"
            ]
          },
          "sourceCompleteness": {
            "enum": [
              "selfContained",
              "proxyOnly",
              "externalRefs",
              "incomplete"
            ]
          },
          "creativeCompletion": {
            "enum": [
              "complete",
              "pendingJobs"
            ]
          },
          "inventoryPath": {
            "const": "extensions/document-lifecycle/inventory.json"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "pendingOperations": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/PendingOperation"
            },
            "maxItems": 10000
          },
          "omissions": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/Omission"
            },
            "maxItems": 100000
          },
          "historyPolicy": {
            "enum": [
              "currentOnly",
              "selectedRevisions"
            ]
          },
          "sessionPolicy": {
            "enum": [
              "excluded",
              "headersOnly",
              "selectedContent"
            ]
          },
          "redactionReportHash": {
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
          }
        }
      },
      "ResourceInventory": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "archiveId",
          "entries"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "entries": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/InventoryEntry"
            },
            "maxItems": 100000
          }
        }
      },
      "RestoreVersion": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "type",
          "id",
          "namespace",
          "projectId",
          "expectedRevision",
          "actorId",
          "receiptKey",
          "operation",
          "expectedEpochs"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "type": {
            "const": "documentLifecycle"
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
          "expectedRevision": {
            "$ref": "#/$defs/U64"
          },
          "actorId": {
            "$ref": "#/$defs/Id"
          },
          "receiptKey": {
            "$ref": "#/$defs/Id"
          },
          "operation": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "sourceCheckpointId",
              "sourceSnapshotHash",
              "restorePlanHash",
              "protectedFieldsConsentRef"
            ],
            "properties": {
              "kind": {
                "const": "restoreVersion"
              },
              "sourceCheckpointId": {
                "$ref": "#/$defs/Id"
              },
              "sourceSnapshotHash": {
                "$ref": "#/$defs/Hash"
              },
              "restorePlanHash": {
                "$ref": "#/$defs/Hash"
              },
              "protectedFieldsConsentRef": {
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
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          }
        }
      },
      "BackupChunk": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "BackupObject": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes",
          "storage",
          "chunks"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          },
          "storage": {
            "enum": [
              "whole",
              "chunked4MiB"
            ]
          },
          "chunks": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupChunk"
            },
            "maxItems": 131072
          }
        }
      },
      "BackupIndex": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "checkpointId",
          "snapshotHash",
          "inventoryHash",
          "epochs",
          "objects",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-private-backup"
          },
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "checkpointId": {
            "$ref": "#/$defs/Id"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "inventoryHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "objects": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupObject"
            },
            "maxItems": 100000
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "AutosavePolicy": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "debounceMs",
          "maxIntervalMs",
          "maxCommands",
          "externalPackageAuto"
        ],
        "properties": {
          "debounceMs": {
            "type": "integer",
            "minimum": 250,
            "maximum": 10000,
            "default": 2000
          },
          "maxIntervalMs": {
            "type": "integer",
            "minimum": 1000,
            "maximum": 300000,
            "default": 30000
          },
          "maxCommands": {
            "type": "integer",
            "minimum": 1,
            "maximum": 1000,
            "default": 50
          },
          "externalPackageAuto": {
            "type": "boolean",
            "default": false
          }
        }
      }
    }
  },
  "backupIndex": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://studio.invalid/schemas/document-lifecycle/BackupIndex-1.0.0.json",
    "$ref": "#/$defs/BackupIndex",
    "$defs": {
      "Id": {
        "type": "string",
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
      },
      "U64": {
        "type": "string",
        "pattern": "^(0|[1-9][0-9]{0,18})$"
      },
      "Hash": {
        "type": "string",
        "pattern": "^sha256:[0-9a-f]{64}$"
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
      "RelativePath": {
        "type": "string",
        "minLength": 1,
        "maxLength": 1024,
        "pattern": "^[A-Za-z0-9_./-]+$"
      },
      "Epochs": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "privacy",
          "rights"
        ],
        "properties": {
          "privacy": {
            "$ref": "#/$defs/U64"
          },
          "rights": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "ResourceKind": {
        "enum": [
          "original",
          "generated",
          "proxy",
          "font",
          "model",
          "lora",
          "character",
          "skill",
          "session",
          "project",
          "history",
          "license",
          "evidence",
          "thumbnail",
          "render"
        ]
      },
      "PendingOperation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "logicalId",
          "kind",
          "shotId",
          "stateAtFreeze",
          "remoteResumeIncluded"
        ],
        "properties": {
          "logicalId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "video",
              "music",
              "sfx",
              "analysis"
            ]
          },
          "shotId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "stateAtFreeze": {
            "enum": [
              "queued",
              "running",
              "unknown"
            ]
          },
          "remoteResumeIncluded": {
            "const": false
          }
        }
      },
      "Omission": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "resourceRef",
          "kind",
          "reason",
          "impact"
        ],
        "properties": {
          "resourceRef": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "reason": {
            "enum": [
              "external",
              "notRedistributable",
              "purged",
              "missing",
              "notSelected",
              "unresolvedExtension"
            ]
          },
          "impact": {
            "enum": [
              "blocksFinalRender",
              "previewOnly",
              "reproGeneration",
              "rebuildable",
              "historicalOnly"
            ]
          }
        }
      },
      "InventoryEntry": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "refId",
          "kind",
          "blobHash",
          "bytes",
          "embeddedPath",
          "externalRef",
          "requiredFor",
          "redistribution",
          "rightsRecordRef"
        ],
        "properties": {
          "refId": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "$ref": "#/$defs/ResourceKind"
          },
          "blobHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "bytes": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "embeddedPath": {
            "anyOf": [
              {
                "$ref": "#/$defs/RelativePath"
              },
              {
                "type": "null"
              }
            ]
          },
          "externalRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "requiredFor": {
            "type": "array",
            "items": {
              "enum": [
                "preview",
                "finalRender",
                "reproGeneration",
                "audit"
              ]
            },
            "maxItems": 4,
            "uniqueItems": true
          },
          "redistribution": {
            "enum": [
              "allowed",
              "forbidden",
              "unknown"
            ]
          },
          "rightsRecordRef": {
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
      "SaveRequest": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "requestId",
          "namespace",
          "projectId",
          "idempotencyKey",
          "kind",
          "revision",
          "targetBindingId",
          "expectedTargetVersion",
          "planHash",
          "name",
          "overwriteConsentRef",
          "uploadConsentRef",
          "expectedEpochs",
          "cancelEpoch"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "requestId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "idempotencyKey": {
            "$ref": "#/$defs/Id"
          },
          "kind": {
            "enum": [
              "checkpoint",
              "saveManaged",
              "saveBoundPackage",
              "namedVersion",
              "backup",
              "portableArchive"
            ]
          },
          "revision": {
            "anyOf": [
              {
                "$ref": "#/$defs/U64"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedTargetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "planHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "name": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 128
              },
              {
                "type": "null"
              }
            ]
          },
          "overwriteConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "uploadConsentRef": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          },
          "cancelEpoch": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "Checkpoint": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "epochs",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "SaveReceipt": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "id",
          "operationId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "targetBindingId",
          "artifactHash",
          "targetVersion",
          "publication",
          "createdAt"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "id": {
            "$ref": "#/$defs/Id"
          },
          "operationId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "targetBindingId": {
            "anyOf": [
              {
                "$ref": "#/$defs/Id"
              },
              {
                "type": "null"
              }
            ]
          },
          "artifactHash": {
            "anyOf": [
              {
                "$ref": "#/$defs/Hash"
              },
              {
                "type": "null"
              }
            ]
          },
          "targetVersion": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 512
              },
              {
                "type": "null"
              }
            ]
          },
          "publication": {
            "enum": [
              "localDurable",
              "providerAcceptedVerified",
              "providerAcceptedUnverified"
            ]
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "ArchiveDescriptor": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "archiveId",
          "namespace",
          "projectId",
          "revision",
          "snapshotHash",
          "mode",
          "sourceCompleteness",
          "creativeCompletion",
          "inventoryPath",
          "epochs",
          "pendingOperations",
          "omissions",
          "historyPolicy",
          "sessionPolicy",
          "redactionReportHash",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-document-lifecycle"
          },
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "namespace": {
            "$ref": "#/$defs/Namespace"
          },
          "projectId": {
            "$ref": "#/$defs/Id"
          },
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "mode": {
            "enum": [
              "originals",
              "proxies",
              "linked"
            ]
          },
          "sourceCompleteness": {
            "enum": [
              "selfContained",
              "proxyOnly",
              "externalRefs",
              "incomplete"
            ]
          },
          "creativeCompletion": {
            "enum": [
              "complete",
              "pendingJobs"
            ]
          },
          "inventoryPath": {
            "const": "extensions/document-lifecycle/inventory.json"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "pendingOperations": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/PendingOperation"
            },
            "maxItems": 10000
          },
          "omissions": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/Omission"
            },
            "maxItems": 100000
          },
          "historyPolicy": {
            "enum": [
              "currentOnly",
              "selectedRevisions"
            ]
          },
          "sessionPolicy": {
            "enum": [
              "excluded",
              "headersOnly",
              "selectedContent"
            ]
          },
          "redactionReportHash": {
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
          }
        }
      },
      "ResourceInventory": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "archiveId",
          "entries"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "archiveId": {
            "$ref": "#/$defs/Id"
          },
          "entries": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/InventoryEntry"
            },
            "maxItems": 100000
          }
        }
      },
      "RestoreVersion": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schemaVersion",
          "type",
          "id",
          "namespace",
          "projectId",
          "expectedRevision",
          "actorId",
          "receiptKey",
          "operation",
          "expectedEpochs"
        ],
        "properties": {
          "schemaVersion": {
            "const": "1.0.0"
          },
          "type": {
            "const": "documentLifecycle"
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
          "expectedRevision": {
            "$ref": "#/$defs/U64"
          },
          "actorId": {
            "$ref": "#/$defs/Id"
          },
          "receiptKey": {
            "$ref": "#/$defs/Id"
          },
          "operation": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "sourceCheckpointId",
              "sourceSnapshotHash",
              "restorePlanHash",
              "protectedFieldsConsentRef"
            ],
            "properties": {
              "kind": {
                "const": "restoreVersion"
              },
              "sourceCheckpointId": {
                "$ref": "#/$defs/Id"
              },
              "sourceSnapshotHash": {
                "$ref": "#/$defs/Hash"
              },
              "restorePlanHash": {
                "$ref": "#/$defs/Hash"
              },
              "protectedFieldsConsentRef": {
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
          "expectedEpochs": {
            "$ref": "#/$defs/Epochs"
          }
        }
      },
      "BackupChunk": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          }
        }
      },
      "BackupObject": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "hash",
          "bytes",
          "storage",
          "chunks"
        ],
        "properties": {
          "hash": {
            "$ref": "#/$defs/Hash"
          },
          "bytes": {
            "$ref": "#/$defs/U64"
          },
          "storage": {
            "enum": [
              "whole",
              "chunked4MiB"
            ]
          },
          "chunks": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupChunk"
            },
            "maxItems": 131072
          }
        }
      },
      "BackupIndex": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "format",
          "schemaVersion",
          "id",
          "namespace",
          "projectId",
          "revision",
          "checkpointId",
          "snapshotHash",
          "inventoryHash",
          "epochs",
          "objects",
          "createdAt"
        ],
        "properties": {
          "format": {
            "const": "studio-private-backup"
          },
          "schemaVersion": {
            "const": "1.0.0"
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
          "revision": {
            "$ref": "#/$defs/U64"
          },
          "checkpointId": {
            "$ref": "#/$defs/Id"
          },
          "snapshotHash": {
            "$ref": "#/$defs/Hash"
          },
          "inventoryHash": {
            "$ref": "#/$defs/Hash"
          },
          "epochs": {
            "$ref": "#/$defs/Epochs"
          },
          "objects": {
            "type": "array",
            "items": {
              "$ref": "#/$defs/BackupObject"
            },
            "maxItems": 100000
          },
          "createdAt": {
            "$ref": "#/$defs/Timestamp"
          }
        }
      },
      "AutosavePolicy": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "debounceMs",
          "maxIntervalMs",
          "maxCommands",
          "externalPackageAuto"
        ],
        "properties": {
          "debounceMs": {
            "type": "integer",
            "minimum": 250,
            "maximum": 10000,
            "default": 2000
          },
          "maxIntervalMs": {
            "type": "integer",
            "minimum": 1000,
            "maximum": 300000,
            "default": 30000
          },
          "maxCommands": {
            "type": "integer",
            "minimum": 1,
            "maximum": 1000,
            "default": 50
          },
          "externalPackageAuto": {
            "type": "boolean",
            "default": false
          }
        }
      }
    }
  }
}
```

| 结构之外的校验器 | 必须拒绝的关系/状态 |
| --- | --- |
| SaveRequestValidator | revision=null仅表示接单时固定最新durable head，不是执行过程中跟随latest。checkpoint/saveManaged/namedVersion的targetBindingId/planHash为null；namedVersion必须有name，其他name=null。saveBoundPackage/backup/portableArchive要求非null targetBindingId+planHash；是否需overwrite/upload consent由受信target与closure决定，不由模型填false绕过。相同idempotencyKey不同语义hash拒绝。 |
| ArchiveValidator | descriptor与core manifest的archiveId/project/ns/R/snapshotHash必须相等；inventory的每个embeddedPath都在checksums内且hash/bytes一致；embedded资源redistribution必须allowed；外链只为安全locator ID，不含远端token。referenced资源不能同时缺失又被标selfContained；proxies要求可解析PTS map且禁止finalRenderReady误导；pendingOperations非空则creativeCompletion=pendingJobs。purged行不能保留正文或被“omission”名义嵌入。 |
| LifecycleValidator | 所有指针解析同namespace/project的不可变记录；checkpoint hash等于该R文档；receipt不可用于不同目标/授权作用域。发布前必须验证固定epochs仍有效、写者fence与target version未变。RestorePlan只能指已授权同工程快照且未跨隐私屏障；fork需完整RefMap；Imported Run不继承批准。JSON Schema本身不会证明这些。 |

```text
-- DOCUMENT_LIFECYCLE_DDL_BEGIN
-- 迁移document_lifecycle/0001；在副本/事务执行并登记组件版本，非整个DB随意改user_version。
CREATE TABLE workspace_features(component TEXT PRIMARY KEY,version TEXT NOT NULL,min_writer TEXT NOT NULL);
INSERT INTO workspace_features VALUES('document_lifecycle','1.0.0','document-lifecycle/1');
ALTER TABLE commands ADD COLUMN payload_format TEXT NOT NULL DEFAULT 'edit.v2.0'
 CHECK(payload_format IN ('edit.v2.0','lifecycle.v1.0'));
-- payload_format来自可信dispatch，不允许LLM自选；旧writer不满足min_writer必须拒绝打开可写库。
CREATE TABLE checkpoints(ns TEXT NOT NULL,id TEXT NOT NULL,project_id TEXT NOT NULL,
 revision INTEGER NOT NULL CHECK(revision>=0),snapshot_hash TEXT NOT NULL,
 privacy_epoch INTEGER NOT NULL CHECK(privacy_epoch>=0),rights_epoch INTEGER NOT NULL CHECK(rights_epoch>=0),
 created_at TEXT NOT NULL,PRIMARY KEY(ns,id),UNIQUE(ns,project_id,id),
 FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id));
CREATE TRIGGER checkpoints_no_update BEFORE UPDATE ON checkpoints
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_CHECKPOINT'); END;
CREATE TRIGGER checkpoints_no_reinsert BEFORE INSERT ON checkpoints
 WHEN EXISTS(SELECT 1 FROM checkpoints WHERE ns=NEW.ns AND id=NEW.id)
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_CHECKPOINT_ID'); END;
CREATE TABLE target_bindings(ns TEXT NOT NULL,id TEXT NOT NULL,project_id TEXT NOT NULL,
 target_token TEXT NOT NULL,capabilities_hash TEXT NOT NULL,last_receipt_id TEXT,
 PRIMARY KEY(ns,id),UNIQUE(ns,project_id,id),
 FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id),
 FOREIGN KEY(ns,project_id,id,last_receipt_id)
 REFERENCES save_receipts(ns,project_id,target_binding_id,id));
CREATE TABLE save_operations(ns TEXT NOT NULL,id TEXT NOT NULL,project_id TEXT NOT NULL,
 request_hash TEXT NOT NULL,request_kind TEXT NOT NULL CHECK(request_kind IN
 ('checkpoint','saveManaged','saveBoundPackage','namedVersion','backup','portableArchive')),
 state TEXT NOT NULL CHECK(state IN
 ('queued','capturing','validating','preparing','writing','verifying','awaitingPublication',
 'publishing','publicationUncertain','reconciling','committed','failed','cancelled')),
 captured_revision INTEGER CHECK(captured_revision>=0),captured_hash TEXT,
 writer_fence INTEGER NOT NULL CHECK(writer_fence>0),privacy_epoch INTEGER NOT NULL,
 rights_epoch INTEGER NOT NULL,cancel_epoch INTEGER NOT NULL CHECK(cancel_epoch>=0),
 target_binding_id TEXT,staged_token TEXT,receipt_id TEXT,error_code TEXT,
 PRIMARY KEY(ns,id),UNIQUE(ns,project_id,id),FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id),
 FOREIGN KEY(ns,project_id,target_binding_id) REFERENCES target_bindings(ns,project_id,id),
 FOREIGN KEY(ns,project_id,receipt_id) REFERENCES save_receipts(ns,project_id,id),
 CHECK(state!='committed' OR receipt_id IS NOT NULL));
CREATE TABLE save_waiters(ns TEXT NOT NULL,request_id TEXT NOT NULL,operation_id TEXT NOT NULL,
 idempotency_key TEXT NOT NULL,input_hash TEXT NOT NULL,PRIMARY KEY(ns,request_id),UNIQUE(ns,idempotency_key),
 FOREIGN KEY(ns,operation_id) REFERENCES save_operations(ns,id));
CREATE TABLE save_receipts(ns TEXT NOT NULL,id TEXT NOT NULL,project_id TEXT NOT NULL,
 operation_id TEXT NOT NULL,revision INTEGER NOT NULL CHECK(revision>=0),snapshot_hash TEXT NOT NULL,
 target_binding_id TEXT,artifact_hash TEXT,target_version TEXT,
 publication TEXT NOT NULL CHECK(publication IN ('localDurable','providerAcceptedVerified','providerAcceptedUnverified')),
 created_at TEXT NOT NULL,PRIMARY KEY(ns,id),UNIQUE(ns,operation_id),UNIQUE(ns,project_id,id),
 UNIQUE(ns,project_id,target_binding_id,id),
 FOREIGN KEY(ns,project_id,operation_id) REFERENCES save_operations(ns,project_id,id),
 FOREIGN KEY(ns,project_id,target_binding_id) REFERENCES target_bindings(ns,project_id,id));
CREATE TRIGGER save_receipts_no_update BEFORE UPDATE ON save_receipts
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_SAVE_RECEIPT'); END;
CREATE TRIGGER save_receipts_no_reinsert BEFORE INSERT ON save_receipts
 WHEN EXISTS(SELECT 1 FROM save_receipts WHERE ns=NEW.ns AND id=NEW.id)
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_SAVE_RECEIPT_ID'); END;
CREATE TABLE project_lifecycle(ns TEXT NOT NULL,project_id TEXT NOT NULL,
 library_state TEXT NOT NULL CHECK(library_state IN ('active','archived','trashed')),
 record_version INTEGER NOT NULL CHECK(record_version>=0),writer_fence INTEGER NOT NULL CHECK(writer_fence>0),
 writer_owner TEXT,active_target_binding_id TEXT,last_checkpoint_id TEXT,
 PRIMARY KEY(ns,project_id),FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id),
 FOREIGN KEY(ns,project_id,active_target_binding_id) REFERENCES target_bindings(ns,project_id,id),
 FOREIGN KEY(ns,project_id,last_checkpoint_id) REFERENCES checkpoints(ns,project_id,id));
CREATE TABLE named_versions(ns TEXT NOT NULL,project_id TEXT NOT NULL,name_key TEXT NOT NULL,
 display_name TEXT NOT NULL,checkpoint_id TEXT NOT NULL,PRIMARY KEY(ns,project_id,name_key),
 FOREIGN KEY(ns,project_id,checkpoint_id) REFERENCES checkpoints(ns,project_id,id));
-- 循环发布指针初始为NULL：先operation，再receipt，再同一事务更新operation/target指针。
-- 复合FK约束同ns/project/target；Repository另验receipt.operationId确为本operation、R/hash一致。
-- 只用严格INSERT；幂等先查原receipt并比hash，禁止INSERT OR REPLACE绕过不可变行语义。
-- 最后显式保存按save_operations.request_kind=saveManaged|saveBoundPackage与生命周期event seq查询，
-- 不按created_at秒值排序当作并发时钟。恢复接管运行指针/状态/资源一致性扫描。
-- 生命周期RestoreVersion的信封进入commands(payload_format=lifecycle.v1.0)，
-- 与revisions/project_heads/events/receipt仍一个事务；输出沿用CommandResult/InversePatch2.0。
-- 普通EditCommand2.0 schema不接受restoreVersion，更不接受任意Project JSON作为payload。
-- 每次Project写入检查lifecycle active + writerFence，再CAS project_heads.revision。
-- save/checkpoint/归档库状态只写lifecycle流，不制造Project revision；RestoreVersion例外。
-- DOCUMENT_LIFECYCLE_DDL_END
```

```text
// BackupStore格式v1：对象存放在独立备份目标CAS，而不是只pin原workspace。
// backup/<sha256(indexBytes)>.json 无自身hash字段；内容进入上级保留根目录的校验记录。
// 完整index列本次全部对象；“增量”仅是写目标CAS缺少的hash，不依赖易断裂的base链。
// <4MiB对象whole：chunks=[]；>=4MiB对象chunked4MiB：按源字节固定切分，
// 除末块外每块4194304 bytes，末块1..4194304；块hash与重组整体hash都验。
// snapshotHash与inventoryHash必须在objects中可还原；Σchunk.bytes=object.bytes；
// hash不可重复异size，0字节对象whole。所有U64转DB前验证I64上界。
BackupStore.write(plan, targetRoot, cancel) -> BackupIndexHash
BackupStore.verify(indexHash) -> {verified:bool,bytes:U64,
 failureDomain:primaryVolume|otherVolume|provider, errors:SaveFailure[]}
// 先对象/块flush，再完整index flush/校验，再发布保留根；根发布前崩溃只产生孤儿块。
// 备份目标GC根=所有保留index；移除一版备份只移index根，其他版引用块不可删。
// 源workspace的GC与备份CAS独立；只有备份完整校验后才可称backupVerified。
// 同卷备份标“不能抵御本盘故障”，不可冒充异地副本；provider不冒充远端durability。
// 私有备份仍需本地备份用途许可/目标权限；导出分享须重新跑再分发gate。
// 恢复先应用live erasure overlay，已删正文的旧index不直接回挂为可读项目。
// 加密凭据/临时会话永不写index，远端目标另走明确上传批准。
```

复合FK、不可更新/不可重复插入触发器和Repository事务共同约束生命周期记录；幂等通过查询既有回执返回，不用OR REPLACE。循环指针的Repository校验仍是必要合同，不以nullable列当完整数据库约束。历史不可变checkpoint/receipt可按保留与隐私流程删除，但必须先在同一事务解除其非必要指针/pin；最后良好/未决publication/命名版本仍引用时拒绝GC。SQLite DB迁移只增加模块表与commands.payload_format，旧编辑行默认edit.v2.0；物理workspace不作为跨App交换格式。已部署旧App不识别min_writer时不能给它共享此运行库，必须由宿主访问层阻断，不能指望旧程序自行理解新表。

| 连续操作 | 实体/事件/状态与恢复结果（自拟流程） |
| --- | --- |
| 1 连续剪辑 | 工程P在R20；trim到135帧提交→R21；手改字幕“上班轻装出发”→R22。每次after文档/逆补丁先CAS后FULL事务，DocumentCommitted带hash。手势中显示正在记录；ACK后head=22，手工锁和字幕manualFields在Project中。 |
| 2 自动与显式保存 | 2s idle触发CheckpointCreated(S22,R22)，无需重拷原视频/ACE音乐Stem；Cmd+S管理模式写UserSaveRecorded(S22)。外部文件如已关联则另走PackagePublished(receipt R22)，期间R23仍可编辑，UI准确显示“文件R22；当前R23待更新”。命名版本“客户确认A”pin S22。 |
| 3 生成未完成时归档 | 导演agent与视觉agent继续各自模型；新视频G9/ACE配乐M2仍running，已有角色Lan@1与Craft@1冻结。用户选originals归档R22，预检列权重/LoRA再分发许可风险及真实字体缺失影响，由用户选择收集哪些组件；缺商业许可不排除所选字节，用户素材/肖像声音同意仍另验；pendingOperations列G9/M2但不含远端resume/批准。需要完整成片时必须等候选就绪，保存工程无需伪造片段。 |
| 4 包发布与崩溃 | 写包过程中用户新trim成129帧→R23且FULL ACK。包R22发布后、receipt前崩溃：重启SQLite恢复head23，手调129帧/字幕仍在；journal对账识别已发布R22并补记回执，不把head改22。G9/M2先查询已登记provider task/usage，不盲重提；晚到结果只入候选，不能覆盖R23。 |
| 5 恢复归档或命名版本 | 默认导入新fork Q:R0并给RefMap，P:R23不变；角色/技法pin仍1，实时授权撤销继续有效。若明确同工程恢复S22，预览129→135帧受保护差异，先pin R23；确认后生成R24而不是倒退到22，手改字幕相同则不变。用户可undo恢复为R25的129帧，付费job不会随undo重跑。 |
| 6 归档库恢复与交付 | 另一个“移入归档库”命令只使P只读/隐藏，不删原件也不停止G9/M2；恢复active不自动接候选。最后选取候选按最新revision diff接受，缺原件/字体/必要Effect或未完成占位则阻止最终render；成片.mp4与可编辑工程包/可选会话归档分别导出，不混淆成功状态。 |

```text
// tests/document/lifecycle/ 对应本轮box合成故障模型，而非App构建结果。
python3 [box-local audit path]
# 实际使用私有临时文件/ZIP、fsync/replace和合成SQLite；异常钩子模拟保存阶段中断、
# ENOSPC/EACCES/ENODEV/EIO、publish后未回执、并发R、fence、privacy撤销。
# 模型验证：重开后目标仅旧完整或新完整；head不倒退；正文不复活；归档闭包/安全导入。
# 不等于真实kill/断电/文件系统控制器/SAF/iCloud/Windows/浏览器持久化保证。
# 完整Schema/DDL从实际发布Page回读校验：
[box-local audit path] [box-local audit path]
# 三轮具体发现/修正/依据：[box-local audit path]
# 历史审查归档：[box-local audit path]
```

- [SQLite atomic commit：硬件假设与故障](https://www.sqlite.org/atomiccommit.html)
- [SQLite WAL：提交、checkpoint、网络限制与WAL-reset修复](https://www.sqlite.org/wal.html)
- [SQLite synchronous/fullfsync配置](https://www.sqlite.org/pragma.html#pragma_synchronous)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [Apple NSFileCoordinator与后台协调](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
- [Android SAF：provider能力/授权/写入](https://developer.android.com/training/data-storage/shared/documents-files)
- [Windows ReplaceFileW失败与同卷边界](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew)
- [Windows FlushFileBuffers](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers)

保存生命周期为可实施详细设计，尚未构建原生App或做真实断电/真机文档provider/多进程锁/介质损坏/大工程性能测试。所有默认间隔/保留/大小上限均为本产品策略；公共文档核验日期2026-11-24（北京时间）。用户电脑离线，本轮公共资料从box网络读取，未连接Mac、读取私有工程、上传素材或调用付费服务。历史Review在box单独归档；正文只保留有效规则、测试范围和未验证门禁。
