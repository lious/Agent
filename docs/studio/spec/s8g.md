## 8G · 新增完整Schema、SQLite与可移植包：不破坏Project 2.0

下列为实际展开的Draft2020-12 Schema，不是省略号类图。新增包自身schemaVersion=1.0.0，核心Project/Command/Manifest仍2.0.0且原builder不改。所有对象required覆盖全部列字段，additionalProperties=false；nullable仅anyOf null，未设default意味着构造器必须显式给值，不从缺字段猜授权。Time/U64/Hash复用原定义，64位整数JSON字符串与有理数规则不变。Schema仅验证结构，下面列的跨引用、许可、时间/业务关系必须由Validator另验。

## CharacterPack与ProjectCharacterRef完整Schema

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:studio:CharacterPack:1.0.0",
  "$ref": "#/$defs/CharacterPack",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-[1-9][0-9]{0,18}|[1-9][0-9]{0,18})$"
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
    "EntityRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
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
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "LibraryLicense": {
      "type": "object",
      "properties": {
        "codeLicense": {
          "type": "string",
          "maxLength": 128
        },
        "weightLicense": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "termsHash": {
          "$ref": "#/$defs/Hash"
        },
        "attributionText": {
          "type": "string",
          "maxLength": 16384
        },
        "sourceUrls": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 32,
          "minItems": 0
        }
      },
      "required": [
        "codeLicense",
        "weightLicense",
        "termsHash",
        "attributionText",
        "sourceUrls"
      ],
      "additionalProperties": false
    },
    "Traits": {
      "type": "object",
      "properties": {
        "ageMin": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 120
            },
            {
              "type": "null"
            }
          ]
        },
        "ageMax": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 120
            },
            {
              "type": "null"
            }
          ]
        },
        "ageBasis": {
          "enum": [
            "fictionalDesign",
            "userDeclared",
            "unknown"
          ]
        },
        "heightCm": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 30,
              "maximum": 250
            },
            {
              "type": "null"
            }
          ]
        },
        "bodyBuild": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "posture": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "eyeShape": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "eyeColor": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "nose": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "mouth": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "jaw": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "brows": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "ears": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "skinToneNotes": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "hairStyle": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "hairColor": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "distinctiveFeatures": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        },
        "doNotDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        }
      },
      "required": [
        "ageMin",
        "ageMax",
        "ageBasis",
        "heightCm",
        "bodyBuild",
        "posture",
        "eyeShape",
        "eyeColor",
        "nose",
        "mouth",
        "jaw",
        "brows",
        "ears",
        "skinToneNotes",
        "hairStyle",
        "hairColor",
        "distinctiveFeatures",
        "doNotDrift"
      ],
      "additionalProperties": false
    },
    "Voice": {
      "type": "object",
      "properties": {
        "description": {
          "type": "string",
          "maxLength": 2048
        },
        "languages": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 32,
          "minItems": 0
        },
        "registerIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "accentIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "speedIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "maxItems": 16,
          "minItems": 0
        },
        "cloningAllowed": {
          "type": "boolean"
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
        },
        "providerSpeakerIdRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "description",
        "languages",
        "registerIntent",
        "accentIntent",
        "speedIntent",
        "sampleHashes",
        "cloningAllowed",
        "voiceRightsId",
        "providerSpeakerIdRef"
      ],
      "additionalProperties": false
    },
    "PortraitRights": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "subjectKind": {
          "enum": [
            "fictional",
            "realPerson"
          ]
        },
        "holderRef": {
          "$ref": "#/$defs/Id"
        },
        "allowedUses": {
          "type": "array",
          "items": {
            "enum": [
              "referenceGeneration",
              "training",
              "voiceClone",
              "exportOutput",
              "redistributePack",
              "upload"
            ]
          },
          "maxItems": 6,
          "minItems": 0
        },
        "allowedProviderIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "territories": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 128,
          "minItems": 0
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
        },
        "revocationAuthorityRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidenceHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "status": {
          "enum": [
            "asserted",
            "verified",
            "revoked",
            "expired"
          ]
        },
        "existingOutputsPolicy": {
          "enum": [
            "retainAllowed",
            "blockUse",
            "reviewRequired"
          ]
        }
      },
      "required": [
        "id",
        "version",
        "subjectKind",
        "holderRef",
        "allowedUses",
        "allowedProviderIds",
        "territories",
        "expiresAt",
        "revocationAuthorityRef",
        "evidenceHash",
        "status",
        "existingOutputsPolicy"
      ],
      "additionalProperties": false
    },
    "CharacterAsset": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "fictional",
            "realPerson"
          ]
        },
        "description": {
          "type": "string",
          "maxLength": 16384
        },
        "traits": {
          "$ref": "#/$defs/Traits"
        },
        "voice": {
          "$ref": "#/$defs/Voice"
        },
        "defaultLookId": {
          "$ref": "#/$defs/Id"
        },
        "portraitRightsId": {
          "$ref": "#/$defs/Id"
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 128,
          "minItems": 0
        }
      },
      "required": [
        "id",
        "version",
        "name",
        "kind",
        "description",
        "traits",
        "voice",
        "defaultLookId",
        "portraitRightsId",
        "tags"
      ],
      "additionalProperties": false
    },
    "LookVariant": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "label": {
          "type": "string",
          "maxLength": 256
        },
        "era": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "wardrobe": {
          "type": "string",
          "maxLength": 4096
        },
        "hairOverride": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "makeup": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "stateDescription": {
          "type": "string",
          "maxLength": 2048
        },
        "referenceIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "forbiddenChanges": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        }
      },
      "required": [
        "id",
        "label",
        "era",
        "wardrobe",
        "hairOverride",
        "makeup",
        "stateDescription",
        "referenceIds",
        "forbiddenChanges"
      ],
      "additionalProperties": false
    },
    "ReferenceView": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "lookId": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "front",
            "left",
            "right",
            "back",
            "threeQuarter",
            "fullBody",
            "expression",
            "wardrobeDetail"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "expression": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "source": {
          "enum": [
            "userProvided",
            "syntheticApproved"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      },
      "required": [
        "id",
        "lookId",
        "role",
        "blobHash",
        "expression",
        "source",
        "rightsId"
      ],
      "additionalProperties": false
    },
    "AdapterBinding": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "referenceImages",
            "lora",
            "featureEmbedding"
          ]
        },
        "providerProfileId": {
          "$ref": "#/$defs/Id"
        },
        "baseModelFamily": {
          "type": "string",
          "maxLength": 128
        },
        "baseModelFingerprint": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "encoderFingerprint": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "embeddingLayout": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "adapterBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceRoles": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 16,
          "minItems": 0
        },
        "strategy": {
          "enum": [
            "singleFirstFrame",
            "multiReference",
            "subjectCondition",
            "textOnly"
          ]
        },
        "preprocessorHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "parameterHash": {
          "$ref": "#/$defs/Hash"
        },
        "trainingRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "id",
        "kind",
        "providerProfileId",
        "baseModelFamily",
        "baseModelFingerprint",
        "encoderFingerprint",
        "embeddingLayout",
        "adapterBlobHash",
        "referenceRoles",
        "strategy",
        "preprocessorHash",
        "parameterHash",
        "trainingRightsId"
      ],
      "additionalProperties": false
    },
    "LibraryResource": {
      "type": "object",
      "properties": {
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "role": {
          "enum": [
            "referenceImage",
            "voiceReference",
            "adapter",
            "licenseEvidence"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      },
      "required": [
        "hash",
        "bytes",
        "mime",
        "role",
        "rightsId"
      ],
      "additionalProperties": false
    },
    "CharacterPack": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "asset": {
          "$ref": "#/$defs/CharacterAsset"
        },
        "looks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/LookVariant"
          },
          "maxItems": 128,
          "minItems": 1
        },
        "references": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ReferenceView"
          },
          "maxItems": 256,
          "minItems": 0
        },
        "bindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AdapterBinding"
          },
          "maxItems": 128,
          "minItems": 0
        },
        "rights": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PortraitRights"
          },
          "maxItems": 128,
          "minItems": 1
        },
        "resources": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/LibraryResource"
          },
          "maxItems": 1024,
          "minItems": 0
        },
        "license": {
          "$ref": "#/$defs/LibraryLicense"
        },
        "signatureRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "schemaVersion",
        "libraryId",
        "namespace",
        "asset",
        "looks",
        "references",
        "bindings",
        "rights",
        "resources",
        "license",
        "signatureRef"
      ],
      "additionalProperties": false
    },
    "CharacterOverride": {
      "type": "object",
      "properties": {
        "wardrobe": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 4096
            },
            {
              "type": "null"
            }
          ]
        },
        "era": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "stateDescription": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 2048
            },
            {
              "type": "null"
            }
          ]
        },
        "hairStyle": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "wardrobe",
        "era",
        "stateDescription",
        "hairStyle"
      ],
      "additionalProperties": false
    },
    "ProjectCharacterRef": {
      "type": "object",
      "properties": {
        "projectCharacterId": {
          "$ref": "#/$defs/Id"
        },
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "pinnedVersion": {
          "$ref": "#/$defs/U64"
        },
        "packHash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
          "$ref": "#/$defs/Id"
        },
        "overrides": {
          "$ref": "#/$defs/CharacterOverride"
        },
        "bindingId": {
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
      },
      "required": [
        "projectCharacterId",
        "libraryId",
        "assetId",
        "pinnedVersion",
        "packHash",
        "lookId",
        "overrides",
        "bindingId",
        "rightsEpoch"
      ],
      "additionalProperties": false
    },
    "ProfileRef": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        }
      },
      "required": [
        "id",
        "version"
      ],
      "additionalProperties": false
    },
    "MusicSpec": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "profile": {
          "$ref": "#/$defs/ProfileRef"
        },
        "task": {
          "enum": [
            "music",
            "sfx",
            "loop",
            "cover",
            "repaint",
            "separate"
          ]
        },
        "description": {
          "type": "string",
          "maxLength": 8192
        },
        "voiceMode": {
          "enum": [
            "instrumental",
            "singing",
            "unspecified"
          ]
        },
        "lyrics": {
          "type": "object",
          "properties": {
            "format": {
              "enum": [
                "plain",
                "lrc"
              ]
            },
            "bodyRef": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Id"
                },
                {
                  "type": "null"
                }
              ]
            },
            "language": {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 64
                },
                {
                  "type": "null"
                }
              ]
            }
          },
          "required": [
            "format",
            "bodyRef",
            "language"
          ],
          "additionalProperties": false
        },
        "bpm": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 30,
              "maximum": 300
            },
            {
              "type": "null"
            }
          ]
        },
        "key": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "meter": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "numerator": {
                  "type": "integer",
                  "minimum": 1,
                  "maximum": 12
                },
                "denominator": {
                  "enum": [
                    2,
                    4,
                    8,
                    16
                  ]
                }
              },
              "required": [
                "numerator",
                "denominator"
              ],
              "additionalProperties": false
            },
            {
              "type": "null"
            }
          ]
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "sourceAudioRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "abcHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "planningMode": {
          "enum": [
            "none",
            "full",
            "melody"
          ]
        },
        "requestedStems": {
          "type": "array",
          "items": {
            "enum": [
              "vocals",
              "accompaniment",
              "drums",
              "bass",
              "other"
            ]
          },
          "maxItems": 5,
          "minItems": 0
        },
        "seed": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "loopRequired": {
          "type": "boolean"
        },
        "rightsIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "targetTimelineRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputSampleRate": {
          "const": 48000
        },
        "budget": {
          "type": "object",
          "properties": {
            "currency": {
              "type": "string",
              "pattern": "^[A-Z]{3}$"
            },
            "maxMicros": {
              "$ref": "#/$defs/U64"
            }
          },
          "required": [
            "currency",
            "maxMicros"
          ],
          "additionalProperties": false
        },
        "manualProtectionRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 256,
          "minItems": 0
        }
      },
      "required": [
        "schemaVersion",
        "id",
        "version",
        "profile",
        "task",
        "description",
        "voiceMode",
        "lyrics",
        "bpm",
        "key",
        "meter",
        "duration",
        "sourceAudioRef",
        "sourceRange",
        "abcHash",
        "planningMode",
        "requestedStems",
        "seed",
        "loopRequired",
        "rightsIds",
        "targetTimelineRange",
        "outputSampleRate",
        "budget",
        "manualProtectionRefs"
      ],
      "additionalProperties": false
    },
    "SkillSlot": {
      "oneOf": [
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "number"
            },
            "minimum": {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            "maximum": {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            "defaultValue": {
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
            "unit": {
              "type": "string",
              "maxLength": 64
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "minimum",
            "maximum",
            "defaultValue",
            "unit",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "enum"
            },
            "choices": {
              "type": "array",
              "items": {
                "type": "string",
                "maxLength": 256
              },
              "maxItems": 64,
              "minItems": 1
            },
            "defaultValue": {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 256
                },
                {
                  "type": "null"
                }
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "choices",
            "defaultValue",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "time"
            },
            "defaultValue": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Time"
                },
                {
                  "type": "null"
                }
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "defaultValue",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "entityRef"
            },
            "entityKind": {
              "enum": [
                "clip",
                "shot",
                "asset",
                "effect",
                "sequence"
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "entityKind",
            "required"
          ],
          "additionalProperties": false
        }
      ]
    },
    "SkillMapping": {
      "type": "object",
      "properties": {
        "providerProfileId": {
          "$ref": "#/$defs/Id"
        },
        "fieldPath": {
          "type": "string",
          "maxLength": 256
        },
        "handling": {
          "enum": [
            "api",
            "promptSuggestion",
            "nle",
            "unsupported"
          ]
        },
        "parameterName": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "warningCode": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "required": {
          "type": "boolean"
        }
      },
      "required": [
        "providerProfileId",
        "fieldPath",
        "handling",
        "parameterName",
        "templateRef",
        "warningCode",
        "required"
      ],
      "additionalProperties": false
    },
    "SkillStep": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "action": {
          "enum": [
            "proposeShot",
            "proposeEdit",
            "analyze",
            "generateCandidate",
            "runSkill"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 16,
          "minItems": 0
        },
        "toolId": {
          "enum": [
            "stage.proposeShot",
            "project.proposeEdit",
            "media.analyze",
            "model.generateCandidate",
            "skill.invoke"
          ]
        },
        "argumentsTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "outputSchemaHash": {
          "$ref": "#/$defs/Hash"
        },
        "budgetPolicy": {
          "const": "inheritOnly"
        }
      },
      "required": [
        "id",
        "action",
        "dependsOn",
        "toolId",
        "argumentsTemplateHash",
        "outputSchemaHash",
        "budgetPolicy"
      ],
      "additionalProperties": false
    },
    "FilmSkill": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "family": {
          "enum": [
            "camera_craft",
            "lighting_craft",
            "transition_craft",
            "editing_craft",
            "workflow_craft"
          ]
        },
        "title": {
          "type": "string",
          "maxLength": 256
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 128,
          "minItems": 0
        },
        "narrativeUses": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "counterExamples": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "parameterSlots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillSlot"
          },
          "maxItems": 32,
          "minItems": 0
        },
        "capabilityMappings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillMapping"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillStep"
          },
          "maxItems": 16,
          "minItems": 1
        },
        "requiredTools": {
          "type": "array",
          "items": {
            "enum": [
              "stage.proposeShot",
              "project.proposeEdit",
              "media.analyze",
              "model.generateCandidate",
              "skill.invoke"
            ]
          },
          "maxItems": 5,
          "minItems": 0
        },
        "requiredFeatures": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 64,
          "minItems": 0
        },
        "reviewChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "license": {
          "$ref": "#/$defs/LibraryLicense"
        },
        "provenanceRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "signatureRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "testFixturesHash": {
          "$ref": "#/$defs/Hash"
        }
      },
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "family",
        "title",
        "tags",
        "narrativeUses",
        "counterExamples",
        "parameterSlots",
        "capabilityMappings",
        "steps",
        "requiredTools",
        "requiredFeatures",
        "reviewChecks",
        "license",
        "provenanceRefs",
        "signatureRef",
        "testFixturesHash"
      ],
      "additionalProperties": false
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:studio:ProjectCharacterRef:1.0.0",
  "$ref": "#/$defs/ProjectCharacterRef",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-[1-9][0-9]{0,18}|[1-9][0-9]{0,18})$"
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
    "EntityRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
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
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "LibraryLicense": {
      "type": "object",
      "properties": {
        "codeLicense": {
          "type": "string",
          "maxLength": 128
        },
        "weightLicense": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "termsHash": {
          "$ref": "#/$defs/Hash"
        },
        "attributionText": {
          "type": "string",
          "maxLength": 16384
        },
        "sourceUrls": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 32,
          "minItems": 0
        }
      },
      "required": [
        "codeLicense",
        "weightLicense",
        "termsHash",
        "attributionText",
        "sourceUrls"
      ],
      "additionalProperties": false
    },
    "Traits": {
      "type": "object",
      "properties": {
        "ageMin": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 120
            },
            {
              "type": "null"
            }
          ]
        },
        "ageMax": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 120
            },
            {
              "type": "null"
            }
          ]
        },
        "ageBasis": {
          "enum": [
            "fictionalDesign",
            "userDeclared",
            "unknown"
          ]
        },
        "heightCm": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 30,
              "maximum": 250
            },
            {
              "type": "null"
            }
          ]
        },
        "bodyBuild": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "posture": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "eyeShape": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "eyeColor": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "nose": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "mouth": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "jaw": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "brows": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "ears": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "skinToneNotes": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "hairStyle": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "hairColor": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "distinctiveFeatures": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        },
        "doNotDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        }
      },
      "required": [
        "ageMin",
        "ageMax",
        "ageBasis",
        "heightCm",
        "bodyBuild",
        "posture",
        "eyeShape",
        "eyeColor",
        "nose",
        "mouth",
        "jaw",
        "brows",
        "ears",
        "skinToneNotes",
        "hairStyle",
        "hairColor",
        "distinctiveFeatures",
        "doNotDrift"
      ],
      "additionalProperties": false
    },
    "Voice": {
      "type": "object",
      "properties": {
        "description": {
          "type": "string",
          "maxLength": 2048
        },
        "languages": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 32,
          "minItems": 0
        },
        "registerIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "accentIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "speedIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "maxItems": 16,
          "minItems": 0
        },
        "cloningAllowed": {
          "type": "boolean"
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
        },
        "providerSpeakerIdRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "description",
        "languages",
        "registerIntent",
        "accentIntent",
        "speedIntent",
        "sampleHashes",
        "cloningAllowed",
        "voiceRightsId",
        "providerSpeakerIdRef"
      ],
      "additionalProperties": false
    },
    "PortraitRights": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "subjectKind": {
          "enum": [
            "fictional",
            "realPerson"
          ]
        },
        "holderRef": {
          "$ref": "#/$defs/Id"
        },
        "allowedUses": {
          "type": "array",
          "items": {
            "enum": [
              "referenceGeneration",
              "training",
              "voiceClone",
              "exportOutput",
              "redistributePack",
              "upload"
            ]
          },
          "maxItems": 6,
          "minItems": 0
        },
        "allowedProviderIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "territories": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 128,
          "minItems": 0
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
        },
        "revocationAuthorityRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidenceHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "status": {
          "enum": [
            "asserted",
            "verified",
            "revoked",
            "expired"
          ]
        },
        "existingOutputsPolicy": {
          "enum": [
            "retainAllowed",
            "blockUse",
            "reviewRequired"
          ]
        }
      },
      "required": [
        "id",
        "version",
        "subjectKind",
        "holderRef",
        "allowedUses",
        "allowedProviderIds",
        "territories",
        "expiresAt",
        "revocationAuthorityRef",
        "evidenceHash",
        "status",
        "existingOutputsPolicy"
      ],
      "additionalProperties": false
    },
    "CharacterAsset": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "fictional",
            "realPerson"
          ]
        },
        "description": {
          "type": "string",
          "maxLength": 16384
        },
        "traits": {
          "$ref": "#/$defs/Traits"
        },
        "voice": {
          "$ref": "#/$defs/Voice"
        },
        "defaultLookId": {
          "$ref": "#/$defs/Id"
        },
        "portraitRightsId": {
          "$ref": "#/$defs/Id"
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 128,
          "minItems": 0
        }
      },
      "required": [
        "id",
        "version",
        "name",
        "kind",
        "description",
        "traits",
        "voice",
        "defaultLookId",
        "portraitRightsId",
        "tags"
      ],
      "additionalProperties": false
    },
    "LookVariant": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "label": {
          "type": "string",
          "maxLength": 256
        },
        "era": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "wardrobe": {
          "type": "string",
          "maxLength": 4096
        },
        "hairOverride": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "makeup": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "stateDescription": {
          "type": "string",
          "maxLength": 2048
        },
        "referenceIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "forbiddenChanges": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        }
      },
      "required": [
        "id",
        "label",
        "era",
        "wardrobe",
        "hairOverride",
        "makeup",
        "stateDescription",
        "referenceIds",
        "forbiddenChanges"
      ],
      "additionalProperties": false
    },
    "ReferenceView": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "lookId": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "front",
            "left",
            "right",
            "back",
            "threeQuarter",
            "fullBody",
            "expression",
            "wardrobeDetail"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "expression": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "source": {
          "enum": [
            "userProvided",
            "syntheticApproved"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      },
      "required": [
        "id",
        "lookId",
        "role",
        "blobHash",
        "expression",
        "source",
        "rightsId"
      ],
      "additionalProperties": false
    },
    "AdapterBinding": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "referenceImages",
            "lora",
            "featureEmbedding"
          ]
        },
        "providerProfileId": {
          "$ref": "#/$defs/Id"
        },
        "baseModelFamily": {
          "type": "string",
          "maxLength": 128
        },
        "baseModelFingerprint": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "encoderFingerprint": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "embeddingLayout": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "adapterBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceRoles": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 16,
          "minItems": 0
        },
        "strategy": {
          "enum": [
            "singleFirstFrame",
            "multiReference",
            "subjectCondition",
            "textOnly"
          ]
        },
        "preprocessorHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "parameterHash": {
          "$ref": "#/$defs/Hash"
        },
        "trainingRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "id",
        "kind",
        "providerProfileId",
        "baseModelFamily",
        "baseModelFingerprint",
        "encoderFingerprint",
        "embeddingLayout",
        "adapterBlobHash",
        "referenceRoles",
        "strategy",
        "preprocessorHash",
        "parameterHash",
        "trainingRightsId"
      ],
      "additionalProperties": false
    },
    "LibraryResource": {
      "type": "object",
      "properties": {
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "role": {
          "enum": [
            "referenceImage",
            "voiceReference",
            "adapter",
            "licenseEvidence"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      },
      "required": [
        "hash",
        "bytes",
        "mime",
        "role",
        "rightsId"
      ],
      "additionalProperties": false
    },
    "CharacterPack": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "asset": {
          "$ref": "#/$defs/CharacterAsset"
        },
        "looks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/LookVariant"
          },
          "maxItems": 128,
          "minItems": 1
        },
        "references": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ReferenceView"
          },
          "maxItems": 256,
          "minItems": 0
        },
        "bindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AdapterBinding"
          },
          "maxItems": 128,
          "minItems": 0
        },
        "rights": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PortraitRights"
          },
          "maxItems": 128,
          "minItems": 1
        },
        "resources": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/LibraryResource"
          },
          "maxItems": 1024,
          "minItems": 0
        },
        "license": {
          "$ref": "#/$defs/LibraryLicense"
        },
        "signatureRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "schemaVersion",
        "libraryId",
        "namespace",
        "asset",
        "looks",
        "references",
        "bindings",
        "rights",
        "resources",
        "license",
        "signatureRef"
      ],
      "additionalProperties": false
    },
    "CharacterOverride": {
      "type": "object",
      "properties": {
        "wardrobe": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 4096
            },
            {
              "type": "null"
            }
          ]
        },
        "era": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "stateDescription": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 2048
            },
            {
              "type": "null"
            }
          ]
        },
        "hairStyle": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "wardrobe",
        "era",
        "stateDescription",
        "hairStyle"
      ],
      "additionalProperties": false
    },
    "ProjectCharacterRef": {
      "type": "object",
      "properties": {
        "projectCharacterId": {
          "$ref": "#/$defs/Id"
        },
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "pinnedVersion": {
          "$ref": "#/$defs/U64"
        },
        "packHash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
          "$ref": "#/$defs/Id"
        },
        "overrides": {
          "$ref": "#/$defs/CharacterOverride"
        },
        "bindingId": {
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
      },
      "required": [
        "projectCharacterId",
        "libraryId",
        "assetId",
        "pinnedVersion",
        "packHash",
        "lookId",
        "overrides",
        "bindingId",
        "rightsEpoch"
      ],
      "additionalProperties": false
    },
    "ProfileRef": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        }
      },
      "required": [
        "id",
        "version"
      ],
      "additionalProperties": false
    },
    "MusicSpec": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "profile": {
          "$ref": "#/$defs/ProfileRef"
        },
        "task": {
          "enum": [
            "music",
            "sfx",
            "loop",
            "cover",
            "repaint",
            "separate"
          ]
        },
        "description": {
          "type": "string",
          "maxLength": 8192
        },
        "voiceMode": {
          "enum": [
            "instrumental",
            "singing",
            "unspecified"
          ]
        },
        "lyrics": {
          "type": "object",
          "properties": {
            "format": {
              "enum": [
                "plain",
                "lrc"
              ]
            },
            "bodyRef": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Id"
                },
                {
                  "type": "null"
                }
              ]
            },
            "language": {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 64
                },
                {
                  "type": "null"
                }
              ]
            }
          },
          "required": [
            "format",
            "bodyRef",
            "language"
          ],
          "additionalProperties": false
        },
        "bpm": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 30,
              "maximum": 300
            },
            {
              "type": "null"
            }
          ]
        },
        "key": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "meter": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "numerator": {
                  "type": "integer",
                  "minimum": 1,
                  "maximum": 12
                },
                "denominator": {
                  "enum": [
                    2,
                    4,
                    8,
                    16
                  ]
                }
              },
              "required": [
                "numerator",
                "denominator"
              ],
              "additionalProperties": false
            },
            {
              "type": "null"
            }
          ]
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "sourceAudioRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "abcHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "planningMode": {
          "enum": [
            "none",
            "full",
            "melody"
          ]
        },
        "requestedStems": {
          "type": "array",
          "items": {
            "enum": [
              "vocals",
              "accompaniment",
              "drums",
              "bass",
              "other"
            ]
          },
          "maxItems": 5,
          "minItems": 0
        },
        "seed": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "loopRequired": {
          "type": "boolean"
        },
        "rightsIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "targetTimelineRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputSampleRate": {
          "const": 48000
        },
        "budget": {
          "type": "object",
          "properties": {
            "currency": {
              "type": "string",
              "pattern": "^[A-Z]{3}$"
            },
            "maxMicros": {
              "$ref": "#/$defs/U64"
            }
          },
          "required": [
            "currency",
            "maxMicros"
          ],
          "additionalProperties": false
        },
        "manualProtectionRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 256,
          "minItems": 0
        }
      },
      "required": [
        "schemaVersion",
        "id",
        "version",
        "profile",
        "task",
        "description",
        "voiceMode",
        "lyrics",
        "bpm",
        "key",
        "meter",
        "duration",
        "sourceAudioRef",
        "sourceRange",
        "abcHash",
        "planningMode",
        "requestedStems",
        "seed",
        "loopRequired",
        "rightsIds",
        "targetTimelineRange",
        "outputSampleRate",
        "budget",
        "manualProtectionRefs"
      ],
      "additionalProperties": false
    },
    "SkillSlot": {
      "oneOf": [
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "number"
            },
            "minimum": {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            "maximum": {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            "defaultValue": {
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
            "unit": {
              "type": "string",
              "maxLength": 64
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "minimum",
            "maximum",
            "defaultValue",
            "unit",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "enum"
            },
            "choices": {
              "type": "array",
              "items": {
                "type": "string",
                "maxLength": 256
              },
              "maxItems": 64,
              "minItems": 1
            },
            "defaultValue": {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 256
                },
                {
                  "type": "null"
                }
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "choices",
            "defaultValue",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "time"
            },
            "defaultValue": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Time"
                },
                {
                  "type": "null"
                }
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "defaultValue",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "entityRef"
            },
            "entityKind": {
              "enum": [
                "clip",
                "shot",
                "asset",
                "effect",
                "sequence"
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "entityKind",
            "required"
          ],
          "additionalProperties": false
        }
      ]
    },
    "SkillMapping": {
      "type": "object",
      "properties": {
        "providerProfileId": {
          "$ref": "#/$defs/Id"
        },
        "fieldPath": {
          "type": "string",
          "maxLength": 256
        },
        "handling": {
          "enum": [
            "api",
            "promptSuggestion",
            "nle",
            "unsupported"
          ]
        },
        "parameterName": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "warningCode": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "required": {
          "type": "boolean"
        }
      },
      "required": [
        "providerProfileId",
        "fieldPath",
        "handling",
        "parameterName",
        "templateRef",
        "warningCode",
        "required"
      ],
      "additionalProperties": false
    },
    "SkillStep": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "action": {
          "enum": [
            "proposeShot",
            "proposeEdit",
            "analyze",
            "generateCandidate",
            "runSkill"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 16,
          "minItems": 0
        },
        "toolId": {
          "enum": [
            "stage.proposeShot",
            "project.proposeEdit",
            "media.analyze",
            "model.generateCandidate",
            "skill.invoke"
          ]
        },
        "argumentsTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "outputSchemaHash": {
          "$ref": "#/$defs/Hash"
        },
        "budgetPolicy": {
          "const": "inheritOnly"
        }
      },
      "required": [
        "id",
        "action",
        "dependsOn",
        "toolId",
        "argumentsTemplateHash",
        "outputSchemaHash",
        "budgetPolicy"
      ],
      "additionalProperties": false
    },
    "FilmSkill": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "family": {
          "enum": [
            "camera_craft",
            "lighting_craft",
            "transition_craft",
            "editing_craft",
            "workflow_craft"
          ]
        },
        "title": {
          "type": "string",
          "maxLength": 256
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 128,
          "minItems": 0
        },
        "narrativeUses": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "counterExamples": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "parameterSlots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillSlot"
          },
          "maxItems": 32,
          "minItems": 0
        },
        "capabilityMappings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillMapping"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillStep"
          },
          "maxItems": 16,
          "minItems": 1
        },
        "requiredTools": {
          "type": "array",
          "items": {
            "enum": [
              "stage.proposeShot",
              "project.proposeEdit",
              "media.analyze",
              "model.generateCandidate",
              "skill.invoke"
            ]
          },
          "maxItems": 5,
          "minItems": 0
        },
        "requiredFeatures": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 64,
          "minItems": 0
        },
        "reviewChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "license": {
          "$ref": "#/$defs/LibraryLicense"
        },
        "provenanceRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "signatureRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "testFixturesHash": {
          "$ref": "#/$defs/Hash"
        }
      },
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "family",
        "title",
        "tags",
        "narrativeUses",
        "counterExamples",
        "parameterSlots",
        "capabilityMappings",
        "steps",
        "requiredTools",
        "requiredFeatures",
        "reviewChecks",
        "license",
        "provenanceRefs",
        "signatureRef",
        "testFixturesHash"
      ],
      "additionalProperties": false
    }
  }
}
```

## MusicSpec与FilmSkillAsset完整Schema

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:studio:MusicSpec:1.0.0",
  "$ref": "#/$defs/MusicSpec",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-[1-9][0-9]{0,18}|[1-9][0-9]{0,18})$"
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
    "EntityRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
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
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "LibraryLicense": {
      "type": "object",
      "properties": {
        "codeLicense": {
          "type": "string",
          "maxLength": 128
        },
        "weightLicense": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "termsHash": {
          "$ref": "#/$defs/Hash"
        },
        "attributionText": {
          "type": "string",
          "maxLength": 16384
        },
        "sourceUrls": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 32,
          "minItems": 0
        }
      },
      "required": [
        "codeLicense",
        "weightLicense",
        "termsHash",
        "attributionText",
        "sourceUrls"
      ],
      "additionalProperties": false
    },
    "Traits": {
      "type": "object",
      "properties": {
        "ageMin": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 120
            },
            {
              "type": "null"
            }
          ]
        },
        "ageMax": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 120
            },
            {
              "type": "null"
            }
          ]
        },
        "ageBasis": {
          "enum": [
            "fictionalDesign",
            "userDeclared",
            "unknown"
          ]
        },
        "heightCm": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 30,
              "maximum": 250
            },
            {
              "type": "null"
            }
          ]
        },
        "bodyBuild": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "posture": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "eyeShape": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "eyeColor": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "nose": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "mouth": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "jaw": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "brows": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "ears": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "skinToneNotes": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "hairStyle": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "hairColor": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "distinctiveFeatures": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        },
        "doNotDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        }
      },
      "required": [
        "ageMin",
        "ageMax",
        "ageBasis",
        "heightCm",
        "bodyBuild",
        "posture",
        "eyeShape",
        "eyeColor",
        "nose",
        "mouth",
        "jaw",
        "brows",
        "ears",
        "skinToneNotes",
        "hairStyle",
        "hairColor",
        "distinctiveFeatures",
        "doNotDrift"
      ],
      "additionalProperties": false
    },
    "Voice": {
      "type": "object",
      "properties": {
        "description": {
          "type": "string",
          "maxLength": 2048
        },
        "languages": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 32,
          "minItems": 0
        },
        "registerIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "accentIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "speedIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "maxItems": 16,
          "minItems": 0
        },
        "cloningAllowed": {
          "type": "boolean"
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
        },
        "providerSpeakerIdRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "description",
        "languages",
        "registerIntent",
        "accentIntent",
        "speedIntent",
        "sampleHashes",
        "cloningAllowed",
        "voiceRightsId",
        "providerSpeakerIdRef"
      ],
      "additionalProperties": false
    },
    "PortraitRights": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "subjectKind": {
          "enum": [
            "fictional",
            "realPerson"
          ]
        },
        "holderRef": {
          "$ref": "#/$defs/Id"
        },
        "allowedUses": {
          "type": "array",
          "items": {
            "enum": [
              "referenceGeneration",
              "training",
              "voiceClone",
              "exportOutput",
              "redistributePack",
              "upload"
            ]
          },
          "maxItems": 6,
          "minItems": 0
        },
        "allowedProviderIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "territories": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 128,
          "minItems": 0
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
        },
        "revocationAuthorityRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidenceHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "status": {
          "enum": [
            "asserted",
            "verified",
            "revoked",
            "expired"
          ]
        },
        "existingOutputsPolicy": {
          "enum": [
            "retainAllowed",
            "blockUse",
            "reviewRequired"
          ]
        }
      },
      "required": [
        "id",
        "version",
        "subjectKind",
        "holderRef",
        "allowedUses",
        "allowedProviderIds",
        "territories",
        "expiresAt",
        "revocationAuthorityRef",
        "evidenceHash",
        "status",
        "existingOutputsPolicy"
      ],
      "additionalProperties": false
    },
    "CharacterAsset": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "fictional",
            "realPerson"
          ]
        },
        "description": {
          "type": "string",
          "maxLength": 16384
        },
        "traits": {
          "$ref": "#/$defs/Traits"
        },
        "voice": {
          "$ref": "#/$defs/Voice"
        },
        "defaultLookId": {
          "$ref": "#/$defs/Id"
        },
        "portraitRightsId": {
          "$ref": "#/$defs/Id"
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 128,
          "minItems": 0
        }
      },
      "required": [
        "id",
        "version",
        "name",
        "kind",
        "description",
        "traits",
        "voice",
        "defaultLookId",
        "portraitRightsId",
        "tags"
      ],
      "additionalProperties": false
    },
    "LookVariant": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "label": {
          "type": "string",
          "maxLength": 256
        },
        "era": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "wardrobe": {
          "type": "string",
          "maxLength": 4096
        },
        "hairOverride": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "makeup": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "stateDescription": {
          "type": "string",
          "maxLength": 2048
        },
        "referenceIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "forbiddenChanges": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        }
      },
      "required": [
        "id",
        "label",
        "era",
        "wardrobe",
        "hairOverride",
        "makeup",
        "stateDescription",
        "referenceIds",
        "forbiddenChanges"
      ],
      "additionalProperties": false
    },
    "ReferenceView": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "lookId": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "front",
            "left",
            "right",
            "back",
            "threeQuarter",
            "fullBody",
            "expression",
            "wardrobeDetail"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "expression": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "source": {
          "enum": [
            "userProvided",
            "syntheticApproved"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      },
      "required": [
        "id",
        "lookId",
        "role",
        "blobHash",
        "expression",
        "source",
        "rightsId"
      ],
      "additionalProperties": false
    },
    "AdapterBinding": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "referenceImages",
            "lora",
            "featureEmbedding"
          ]
        },
        "providerProfileId": {
          "$ref": "#/$defs/Id"
        },
        "baseModelFamily": {
          "type": "string",
          "maxLength": 128
        },
        "baseModelFingerprint": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "encoderFingerprint": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "embeddingLayout": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "adapterBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceRoles": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 16,
          "minItems": 0
        },
        "strategy": {
          "enum": [
            "singleFirstFrame",
            "multiReference",
            "subjectCondition",
            "textOnly"
          ]
        },
        "preprocessorHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "parameterHash": {
          "$ref": "#/$defs/Hash"
        },
        "trainingRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "id",
        "kind",
        "providerProfileId",
        "baseModelFamily",
        "baseModelFingerprint",
        "encoderFingerprint",
        "embeddingLayout",
        "adapterBlobHash",
        "referenceRoles",
        "strategy",
        "preprocessorHash",
        "parameterHash",
        "trainingRightsId"
      ],
      "additionalProperties": false
    },
    "LibraryResource": {
      "type": "object",
      "properties": {
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "role": {
          "enum": [
            "referenceImage",
            "voiceReference",
            "adapter",
            "licenseEvidence"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      },
      "required": [
        "hash",
        "bytes",
        "mime",
        "role",
        "rightsId"
      ],
      "additionalProperties": false
    },
    "CharacterPack": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "asset": {
          "$ref": "#/$defs/CharacterAsset"
        },
        "looks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/LookVariant"
          },
          "maxItems": 128,
          "minItems": 1
        },
        "references": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ReferenceView"
          },
          "maxItems": 256,
          "minItems": 0
        },
        "bindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AdapterBinding"
          },
          "maxItems": 128,
          "minItems": 0
        },
        "rights": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PortraitRights"
          },
          "maxItems": 128,
          "minItems": 1
        },
        "resources": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/LibraryResource"
          },
          "maxItems": 1024,
          "minItems": 0
        },
        "license": {
          "$ref": "#/$defs/LibraryLicense"
        },
        "signatureRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "schemaVersion",
        "libraryId",
        "namespace",
        "asset",
        "looks",
        "references",
        "bindings",
        "rights",
        "resources",
        "license",
        "signatureRef"
      ],
      "additionalProperties": false
    },
    "CharacterOverride": {
      "type": "object",
      "properties": {
        "wardrobe": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 4096
            },
            {
              "type": "null"
            }
          ]
        },
        "era": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "stateDescription": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 2048
            },
            {
              "type": "null"
            }
          ]
        },
        "hairStyle": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "wardrobe",
        "era",
        "stateDescription",
        "hairStyle"
      ],
      "additionalProperties": false
    },
    "ProjectCharacterRef": {
      "type": "object",
      "properties": {
        "projectCharacterId": {
          "$ref": "#/$defs/Id"
        },
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "pinnedVersion": {
          "$ref": "#/$defs/U64"
        },
        "packHash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
          "$ref": "#/$defs/Id"
        },
        "overrides": {
          "$ref": "#/$defs/CharacterOverride"
        },
        "bindingId": {
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
      },
      "required": [
        "projectCharacterId",
        "libraryId",
        "assetId",
        "pinnedVersion",
        "packHash",
        "lookId",
        "overrides",
        "bindingId",
        "rightsEpoch"
      ],
      "additionalProperties": false
    },
    "ProfileRef": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        }
      },
      "required": [
        "id",
        "version"
      ],
      "additionalProperties": false
    },
    "MusicSpec": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "profile": {
          "$ref": "#/$defs/ProfileRef"
        },
        "task": {
          "enum": [
            "music",
            "sfx",
            "loop",
            "cover",
            "repaint",
            "separate"
          ]
        },
        "description": {
          "type": "string",
          "maxLength": 8192
        },
        "voiceMode": {
          "enum": [
            "instrumental",
            "singing",
            "unspecified"
          ]
        },
        "lyrics": {
          "type": "object",
          "properties": {
            "format": {
              "enum": [
                "plain",
                "lrc"
              ]
            },
            "bodyRef": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Id"
                },
                {
                  "type": "null"
                }
              ]
            },
            "language": {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 64
                },
                {
                  "type": "null"
                }
              ]
            }
          },
          "required": [
            "format",
            "bodyRef",
            "language"
          ],
          "additionalProperties": false
        },
        "bpm": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 30,
              "maximum": 300
            },
            {
              "type": "null"
            }
          ]
        },
        "key": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "meter": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "numerator": {
                  "type": "integer",
                  "minimum": 1,
                  "maximum": 12
                },
                "denominator": {
                  "enum": [
                    2,
                    4,
                    8,
                    16
                  ]
                }
              },
              "required": [
                "numerator",
                "denominator"
              ],
              "additionalProperties": false
            },
            {
              "type": "null"
            }
          ]
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "sourceAudioRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "abcHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "planningMode": {
          "enum": [
            "none",
            "full",
            "melody"
          ]
        },
        "requestedStems": {
          "type": "array",
          "items": {
            "enum": [
              "vocals",
              "accompaniment",
              "drums",
              "bass",
              "other"
            ]
          },
          "maxItems": 5,
          "minItems": 0
        },
        "seed": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "loopRequired": {
          "type": "boolean"
        },
        "rightsIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "targetTimelineRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputSampleRate": {
          "const": 48000
        },
        "budget": {
          "type": "object",
          "properties": {
            "currency": {
              "type": "string",
              "pattern": "^[A-Z]{3}$"
            },
            "maxMicros": {
              "$ref": "#/$defs/U64"
            }
          },
          "required": [
            "currency",
            "maxMicros"
          ],
          "additionalProperties": false
        },
        "manualProtectionRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 256,
          "minItems": 0
        }
      },
      "required": [
        "schemaVersion",
        "id",
        "version",
        "profile",
        "task",
        "description",
        "voiceMode",
        "lyrics",
        "bpm",
        "key",
        "meter",
        "duration",
        "sourceAudioRef",
        "sourceRange",
        "abcHash",
        "planningMode",
        "requestedStems",
        "seed",
        "loopRequired",
        "rightsIds",
        "targetTimelineRange",
        "outputSampleRate",
        "budget",
        "manualProtectionRefs"
      ],
      "additionalProperties": false
    },
    "SkillSlot": {
      "oneOf": [
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "number"
            },
            "minimum": {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            "maximum": {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            "defaultValue": {
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
            "unit": {
              "type": "string",
              "maxLength": 64
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "minimum",
            "maximum",
            "defaultValue",
            "unit",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "enum"
            },
            "choices": {
              "type": "array",
              "items": {
                "type": "string",
                "maxLength": 256
              },
              "maxItems": 64,
              "minItems": 1
            },
            "defaultValue": {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 256
                },
                {
                  "type": "null"
                }
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "choices",
            "defaultValue",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "time"
            },
            "defaultValue": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Time"
                },
                {
                  "type": "null"
                }
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "defaultValue",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "entityRef"
            },
            "entityKind": {
              "enum": [
                "clip",
                "shot",
                "asset",
                "effect",
                "sequence"
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "entityKind",
            "required"
          ],
          "additionalProperties": false
        }
      ]
    },
    "SkillMapping": {
      "type": "object",
      "properties": {
        "providerProfileId": {
          "$ref": "#/$defs/Id"
        },
        "fieldPath": {
          "type": "string",
          "maxLength": 256
        },
        "handling": {
          "enum": [
            "api",
            "promptSuggestion",
            "nle",
            "unsupported"
          ]
        },
        "parameterName": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "warningCode": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "required": {
          "type": "boolean"
        }
      },
      "required": [
        "providerProfileId",
        "fieldPath",
        "handling",
        "parameterName",
        "templateRef",
        "warningCode",
        "required"
      ],
      "additionalProperties": false
    },
    "SkillStep": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "action": {
          "enum": [
            "proposeShot",
            "proposeEdit",
            "analyze",
            "generateCandidate",
            "runSkill"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 16,
          "minItems": 0
        },
        "toolId": {
          "enum": [
            "stage.proposeShot",
            "project.proposeEdit",
            "media.analyze",
            "model.generateCandidate",
            "skill.invoke"
          ]
        },
        "argumentsTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "outputSchemaHash": {
          "$ref": "#/$defs/Hash"
        },
        "budgetPolicy": {
          "const": "inheritOnly"
        }
      },
      "required": [
        "id",
        "action",
        "dependsOn",
        "toolId",
        "argumentsTemplateHash",
        "outputSchemaHash",
        "budgetPolicy"
      ],
      "additionalProperties": false
    },
    "FilmSkill": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "family": {
          "enum": [
            "camera_craft",
            "lighting_craft",
            "transition_craft",
            "editing_craft",
            "workflow_craft"
          ]
        },
        "title": {
          "type": "string",
          "maxLength": 256
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 128,
          "minItems": 0
        },
        "narrativeUses": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "counterExamples": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "parameterSlots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillSlot"
          },
          "maxItems": 32,
          "minItems": 0
        },
        "capabilityMappings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillMapping"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillStep"
          },
          "maxItems": 16,
          "minItems": 1
        },
        "requiredTools": {
          "type": "array",
          "items": {
            "enum": [
              "stage.proposeShot",
              "project.proposeEdit",
              "media.analyze",
              "model.generateCandidate",
              "skill.invoke"
            ]
          },
          "maxItems": 5,
          "minItems": 0
        },
        "requiredFeatures": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 64,
          "minItems": 0
        },
        "reviewChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "license": {
          "$ref": "#/$defs/LibraryLicense"
        },
        "provenanceRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "signatureRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "testFixturesHash": {
          "$ref": "#/$defs/Hash"
        }
      },
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "family",
        "title",
        "tags",
        "narrativeUses",
        "counterExamples",
        "parameterSlots",
        "capabilityMappings",
        "steps",
        "requiredTools",
        "requiredFeatures",
        "reviewChecks",
        "license",
        "provenanceRefs",
        "signatureRef",
        "testFixturesHash"
      ],
      "additionalProperties": false
    }
  }
}
```

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:studio:FilmSkill:1.0.0",
  "$ref": "#/$defs/FilmSkill",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-[1-9][0-9]{0,18}|[1-9][0-9]{0,18})$"
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
    "EntityRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
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
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "LibraryLicense": {
      "type": "object",
      "properties": {
        "codeLicense": {
          "type": "string",
          "maxLength": 128
        },
        "weightLicense": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "termsHash": {
          "$ref": "#/$defs/Hash"
        },
        "attributionText": {
          "type": "string",
          "maxLength": 16384
        },
        "sourceUrls": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 32,
          "minItems": 0
        }
      },
      "required": [
        "codeLicense",
        "weightLicense",
        "termsHash",
        "attributionText",
        "sourceUrls"
      ],
      "additionalProperties": false
    },
    "Traits": {
      "type": "object",
      "properties": {
        "ageMin": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 120
            },
            {
              "type": "null"
            }
          ]
        },
        "ageMax": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 120
            },
            {
              "type": "null"
            }
          ]
        },
        "ageBasis": {
          "enum": [
            "fictionalDesign",
            "userDeclared",
            "unknown"
          ]
        },
        "heightCm": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 30,
              "maximum": 250
            },
            {
              "type": "null"
            }
          ]
        },
        "bodyBuild": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "posture": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "eyeShape": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "eyeColor": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "nose": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "mouth": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "jaw": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "brows": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "ears": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "skinToneNotes": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "hairStyle": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "hairColor": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "distinctiveFeatures": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        },
        "doNotDrift": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        }
      },
      "required": [
        "ageMin",
        "ageMax",
        "ageBasis",
        "heightCm",
        "bodyBuild",
        "posture",
        "eyeShape",
        "eyeColor",
        "nose",
        "mouth",
        "jaw",
        "brows",
        "ears",
        "skinToneNotes",
        "hairStyle",
        "hairColor",
        "distinctiveFeatures",
        "doNotDrift"
      ],
      "additionalProperties": false
    },
    "Voice": {
      "type": "object",
      "properties": {
        "description": {
          "type": "string",
          "maxLength": 2048
        },
        "languages": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 32,
          "minItems": 0
        },
        "registerIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "accentIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "speedIntent": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "sampleHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "maxItems": 16,
          "minItems": 0
        },
        "cloningAllowed": {
          "type": "boolean"
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
        },
        "providerSpeakerIdRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "description",
        "languages",
        "registerIntent",
        "accentIntent",
        "speedIntent",
        "sampleHashes",
        "cloningAllowed",
        "voiceRightsId",
        "providerSpeakerIdRef"
      ],
      "additionalProperties": false
    },
    "PortraitRights": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "subjectKind": {
          "enum": [
            "fictional",
            "realPerson"
          ]
        },
        "holderRef": {
          "$ref": "#/$defs/Id"
        },
        "allowedUses": {
          "type": "array",
          "items": {
            "enum": [
              "referenceGeneration",
              "training",
              "voiceClone",
              "exportOutput",
              "redistributePack",
              "upload"
            ]
          },
          "maxItems": 6,
          "minItems": 0
        },
        "allowedProviderIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "territories": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 128,
          "minItems": 0
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
        },
        "revocationAuthorityRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidenceHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "status": {
          "enum": [
            "asserted",
            "verified",
            "revoked",
            "expired"
          ]
        },
        "existingOutputsPolicy": {
          "enum": [
            "retainAllowed",
            "blockUse",
            "reviewRequired"
          ]
        }
      },
      "required": [
        "id",
        "version",
        "subjectKind",
        "holderRef",
        "allowedUses",
        "allowedProviderIds",
        "territories",
        "expiresAt",
        "revocationAuthorityRef",
        "evidenceHash",
        "status",
        "existingOutputsPolicy"
      ],
      "additionalProperties": false
    },
    "CharacterAsset": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "fictional",
            "realPerson"
          ]
        },
        "description": {
          "type": "string",
          "maxLength": 16384
        },
        "traits": {
          "$ref": "#/$defs/Traits"
        },
        "voice": {
          "$ref": "#/$defs/Voice"
        },
        "defaultLookId": {
          "$ref": "#/$defs/Id"
        },
        "portraitRightsId": {
          "$ref": "#/$defs/Id"
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 128,
          "minItems": 0
        }
      },
      "required": [
        "id",
        "version",
        "name",
        "kind",
        "description",
        "traits",
        "voice",
        "defaultLookId",
        "portraitRightsId",
        "tags"
      ],
      "additionalProperties": false
    },
    "LookVariant": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "label": {
          "type": "string",
          "maxLength": 256
        },
        "era": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "wardrobe": {
          "type": "string",
          "maxLength": 4096
        },
        "hairOverride": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "makeup": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        },
        "stateDescription": {
          "type": "string",
          "maxLength": 2048
        },
        "referenceIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "forbiddenChanges": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 1024
          },
          "maxItems": 64,
          "minItems": 0
        }
      },
      "required": [
        "id",
        "label",
        "era",
        "wardrobe",
        "hairOverride",
        "makeup",
        "stateDescription",
        "referenceIds",
        "forbiddenChanges"
      ],
      "additionalProperties": false
    },
    "ReferenceView": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "lookId": {
          "$ref": "#/$defs/Id"
        },
        "role": {
          "enum": [
            "front",
            "left",
            "right",
            "back",
            "threeQuarter",
            "fullBody",
            "expression",
            "wardrobeDetail"
          ]
        },
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "expression": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "source": {
          "enum": [
            "userProvided",
            "syntheticApproved"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      },
      "required": [
        "id",
        "lookId",
        "role",
        "blobHash",
        "expression",
        "source",
        "rightsId"
      ],
      "additionalProperties": false
    },
    "AdapterBinding": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "referenceImages",
            "lora",
            "featureEmbedding"
          ]
        },
        "providerProfileId": {
          "$ref": "#/$defs/Id"
        },
        "baseModelFamily": {
          "type": "string",
          "maxLength": 128
        },
        "baseModelFingerprint": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "encoderFingerprint": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "embeddingLayout": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "adapterBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceRoles": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 64
          },
          "maxItems": 16,
          "minItems": 0
        },
        "strategy": {
          "enum": [
            "singleFirstFrame",
            "multiReference",
            "subjectCondition",
            "textOnly"
          ]
        },
        "preprocessorHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "parameterHash": {
          "$ref": "#/$defs/Hash"
        },
        "trainingRightsId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "id",
        "kind",
        "providerProfileId",
        "baseModelFamily",
        "baseModelFingerprint",
        "encoderFingerprint",
        "embeddingLayout",
        "adapterBlobHash",
        "referenceRoles",
        "strategy",
        "preprocessorHash",
        "parameterHash",
        "trainingRightsId"
      ],
      "additionalProperties": false
    },
    "LibraryResource": {
      "type": "object",
      "properties": {
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "mime": {
          "type": "string",
          "maxLength": 128
        },
        "role": {
          "enum": [
            "referenceImage",
            "voiceReference",
            "adapter",
            "licenseEvidence"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      },
      "required": [
        "hash",
        "bytes",
        "mime",
        "role",
        "rightsId"
      ],
      "additionalProperties": false
    },
    "CharacterPack": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "asset": {
          "$ref": "#/$defs/CharacterAsset"
        },
        "looks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/LookVariant"
          },
          "maxItems": 128,
          "minItems": 1
        },
        "references": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ReferenceView"
          },
          "maxItems": 256,
          "minItems": 0
        },
        "bindings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/AdapterBinding"
          },
          "maxItems": 128,
          "minItems": 0
        },
        "rights": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/PortraitRights"
          },
          "maxItems": 128,
          "minItems": 1
        },
        "resources": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/LibraryResource"
          },
          "maxItems": 1024,
          "minItems": 0
        },
        "license": {
          "$ref": "#/$defs/LibraryLicense"
        },
        "signatureRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "schemaVersion",
        "libraryId",
        "namespace",
        "asset",
        "looks",
        "references",
        "bindings",
        "rights",
        "resources",
        "license",
        "signatureRef"
      ],
      "additionalProperties": false
    },
    "CharacterOverride": {
      "type": "object",
      "properties": {
        "wardrobe": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 4096
            },
            {
              "type": "null"
            }
          ]
        },
        "era": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "stateDescription": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 2048
            },
            {
              "type": "null"
            }
          ]
        },
        "hairStyle": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 1024
            },
            {
              "type": "null"
            }
          ]
        }
      },
      "required": [
        "wardrobe",
        "era",
        "stateDescription",
        "hairStyle"
      ],
      "additionalProperties": false
    },
    "ProjectCharacterRef": {
      "type": "object",
      "properties": {
        "projectCharacterId": {
          "$ref": "#/$defs/Id"
        },
        "libraryId": {
          "$ref": "#/$defs/Id"
        },
        "assetId": {
          "$ref": "#/$defs/Id"
        },
        "pinnedVersion": {
          "$ref": "#/$defs/U64"
        },
        "packHash": {
          "$ref": "#/$defs/Hash"
        },
        "lookId": {
          "$ref": "#/$defs/Id"
        },
        "overrides": {
          "$ref": "#/$defs/CharacterOverride"
        },
        "bindingId": {
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
      },
      "required": [
        "projectCharacterId",
        "libraryId",
        "assetId",
        "pinnedVersion",
        "packHash",
        "lookId",
        "overrides",
        "bindingId",
        "rightsEpoch"
      ],
      "additionalProperties": false
    },
    "ProfileRef": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        }
      },
      "required": [
        "id",
        "version"
      ],
      "additionalProperties": false
    },
    "MusicSpec": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "profile": {
          "$ref": "#/$defs/ProfileRef"
        },
        "task": {
          "enum": [
            "music",
            "sfx",
            "loop",
            "cover",
            "repaint",
            "separate"
          ]
        },
        "description": {
          "type": "string",
          "maxLength": 8192
        },
        "voiceMode": {
          "enum": [
            "instrumental",
            "singing",
            "unspecified"
          ]
        },
        "lyrics": {
          "type": "object",
          "properties": {
            "format": {
              "enum": [
                "plain",
                "lrc"
              ]
            },
            "bodyRef": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Id"
                },
                {
                  "type": "null"
                }
              ]
            },
            "language": {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 64
                },
                {
                  "type": "null"
                }
              ]
            }
          },
          "required": [
            "format",
            "bodyRef",
            "language"
          ],
          "additionalProperties": false
        },
        "bpm": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 30,
              "maximum": 300
            },
            {
              "type": "null"
            }
          ]
        },
        "key": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "meter": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "numerator": {
                  "type": "integer",
                  "minimum": 1,
                  "maximum": 12
                },
                "denominator": {
                  "enum": [
                    2,
                    4,
                    8,
                    16
                  ]
                }
              },
              "required": [
                "numerator",
                "denominator"
              ],
              "additionalProperties": false
            },
            {
              "type": "null"
            }
          ]
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "sourceAudioRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "abcHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "planningMode": {
          "enum": [
            "none",
            "full",
            "melody"
          ]
        },
        "requestedStems": {
          "type": "array",
          "items": {
            "enum": [
              "vocals",
              "accompaniment",
              "drums",
              "bass",
              "other"
            ]
          },
          "maxItems": 5,
          "minItems": 0
        },
        "seed": {
          "anyOf": [
            {
              "$ref": "#/$defs/U64"
            },
            {
              "type": "null"
            }
          ]
        },
        "loopRequired": {
          "type": "boolean"
        },
        "rightsIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "targetTimelineRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "outputSampleRate": {
          "const": 48000
        },
        "budget": {
          "type": "object",
          "properties": {
            "currency": {
              "type": "string",
              "pattern": "^[A-Z]{3}$"
            },
            "maxMicros": {
              "$ref": "#/$defs/U64"
            }
          },
          "required": [
            "currency",
            "maxMicros"
          ],
          "additionalProperties": false
        },
        "manualProtectionRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 256,
          "minItems": 0
        }
      },
      "required": [
        "schemaVersion",
        "id",
        "version",
        "profile",
        "task",
        "description",
        "voiceMode",
        "lyrics",
        "bpm",
        "key",
        "meter",
        "duration",
        "sourceAudioRef",
        "sourceRange",
        "abcHash",
        "planningMode",
        "requestedStems",
        "seed",
        "loopRequired",
        "rightsIds",
        "targetTimelineRange",
        "outputSampleRate",
        "budget",
        "manualProtectionRefs"
      ],
      "additionalProperties": false
    },
    "SkillSlot": {
      "oneOf": [
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "number"
            },
            "minimum": {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            "maximum": {
              "type": "number",
              "minimum": -1000000,
              "maximum": 1000000
            },
            "defaultValue": {
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
            "unit": {
              "type": "string",
              "maxLength": 64
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "minimum",
            "maximum",
            "defaultValue",
            "unit",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "enum"
            },
            "choices": {
              "type": "array",
              "items": {
                "type": "string",
                "maxLength": 256
              },
              "maxItems": 64,
              "minItems": 1
            },
            "defaultValue": {
              "anyOf": [
                {
                  "type": "string",
                  "maxLength": 256
                },
                {
                  "type": "null"
                }
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "choices",
            "defaultValue",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "time"
            },
            "defaultValue": {
              "anyOf": [
                {
                  "$ref": "#/$defs/Time"
                },
                {
                  "type": "null"
                }
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "defaultValue",
            "required"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "key": {
              "$ref": "#/$defs/Id"
            },
            "kind": {
              "const": "entityRef"
            },
            "entityKind": {
              "enum": [
                "clip",
                "shot",
                "asset",
                "effect",
                "sequence"
              ]
            },
            "required": {
              "type": "boolean"
            }
          },
          "required": [
            "key",
            "kind",
            "entityKind",
            "required"
          ],
          "additionalProperties": false
        }
      ]
    },
    "SkillMapping": {
      "type": "object",
      "properties": {
        "providerProfileId": {
          "$ref": "#/$defs/Id"
        },
        "fieldPath": {
          "type": "string",
          "maxLength": 256
        },
        "handling": {
          "enum": [
            "api",
            "promptSuggestion",
            "nle",
            "unsupported"
          ]
        },
        "parameterName": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "templateRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "warningCode": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "required": {
          "type": "boolean"
        }
      },
      "required": [
        "providerProfileId",
        "fieldPath",
        "handling",
        "parameterName",
        "templateRef",
        "warningCode",
        "required"
      ],
      "additionalProperties": false
    },
    "SkillStep": {
      "type": "object",
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "action": {
          "enum": [
            "proposeShot",
            "proposeEdit",
            "analyze",
            "generateCandidate",
            "runSkill"
          ]
        },
        "dependsOn": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "maxItems": 16,
          "minItems": 0
        },
        "toolId": {
          "enum": [
            "stage.proposeShot",
            "project.proposeEdit",
            "media.analyze",
            "model.generateCandidate",
            "skill.invoke"
          ]
        },
        "argumentsTemplateHash": {
          "$ref": "#/$defs/Hash"
        },
        "outputSchemaHash": {
          "$ref": "#/$defs/Hash"
        },
        "budgetPolicy": {
          "const": "inheritOnly"
        }
      },
      "required": [
        "id",
        "action",
        "dependsOn",
        "toolId",
        "argumentsTemplateHash",
        "outputSchemaHash",
        "budgetPolicy"
      ],
      "additionalProperties": false
    },
    "FilmSkill": {
      "type": "object",
      "properties": {
        "schemaVersion": {
          "const": "1.0.0"
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/Version"
        },
        "namespace": {
          "$ref": "#/$defs/Namespace"
        },
        "family": {
          "enum": [
            "camera_craft",
            "lighting_craft",
            "transition_craft",
            "editing_craft",
            "workflow_craft"
          ]
        },
        "title": {
          "type": "string",
          "maxLength": 256
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 128,
          "minItems": 0
        },
        "narrativeUses": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "counterExamples": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "parameterSlots": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillSlot"
          },
          "maxItems": 32,
          "minItems": 0
        },
        "capabilityMappings": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillMapping"
          },
          "maxItems": 64,
          "minItems": 0
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SkillStep"
          },
          "maxItems": 16,
          "minItems": 1
        },
        "requiredTools": {
          "type": "array",
          "items": {
            "enum": [
              "stage.proposeShot",
              "project.proposeEdit",
              "media.analyze",
              "model.generateCandidate",
              "skill.invoke"
            ]
          },
          "maxItems": 5,
          "minItems": 0
        },
        "requiredFeatures": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 128
          },
          "maxItems": 64,
          "minItems": 0
        },
        "reviewChecks": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "license": {
          "$ref": "#/$defs/LibraryLicense"
        },
        "provenanceRefs": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 2048
          },
          "maxItems": 64,
          "minItems": 0
        },
        "signatureRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "testFixturesHash": {
          "$ref": "#/$defs/Hash"
        }
      },
      "required": [
        "schemaVersion",
        "id",
        "version",
        "namespace",
        "family",
        "title",
        "tags",
        "narrativeUses",
        "counterExamples",
        "parameterSlots",
        "capabilityMappings",
        "steps",
        "requiredTools",
        "requiredFeatures",
        "reviewChecks",
        "license",
        "provenanceRefs",
        "signatureRef",
        "testFixturesHash"
      ],
      "additionalProperties": false
    }
  }
}
```

| 非JSON Schema自动完成的校验 | 具体规则 |
| --- | --- |
| CharacterPackValidator | asset/looks/references/rights/resources ID唯一，defaultLook与引用look存在，role/资源mime/hash/bytes匹配；参考图及Voice样本有权利且在resource闭包。ageMin≤ageMax；realPerson不能引用fictional授权；cloningAllowed→voiceRightsId且voiceClone允许。LoRA需baseFingerprint/adapter hash及训练权利，featureEmbedding还需encoderFingerprint/preprocessorHash/embeddingLayout匹配，kind与null字段组合合法；导出需redistributePack。身份描述不运行人脸识别。 |
| MusicSpecValidator | duration>0且符合所选profile，repaint/cover/separate所需sourceRange不能越音频源；source time按Q/sample映射。LRC语法/递增时码检查不等于已和模型音频同步；requestedStems去重且每角色有真实能力路径；planningMode/ABC与YuE2模式相容；BPM/key/meter profile不支持则显式报错或用户接受软化，不静默丢字段。 |
| SkillValidator/Policy | slot key唯一、min≤max/default在范围内、enum default在choices；steps ID唯一/DAG闭合无环、声明tools覆盖实际step、action与tool匹配。实体ref必须在授权scope，pluginVersion固定且Registry存在；不能让包的签名自己给自己信任。Effect/Transition业务验证与锁/handles在compile和accept都执行。 |
| 向后兼容与unknown feature | Character/Craft元数据扩展可在旧App保留opaque blob；若只影响再生成，旧App仍可剪已有合法媒体但禁角色升级/技法再编译。新增render operator必须requiredFeatures，缺则不能render/export。需要live肖像权/撤销限制的包声明studio.live-rights.v1；不懂的App只读元数据，禁止生成/上传/导出，不让忽略扩展绕授权。 |
| 包、会话与同步边界 | assets与音乐输出按既有originals/generated/renders引用；library包在extensions/下列manifest+闭包，所有blob登记Project.blobs后才可归档，独立库使用自身manifest/校验和。pins保版本；library grants、license商业合同证据原文、endpoint secret、临时会话/FTS/embedding不默认进工程。只导出授权声明快照/opaque decision ID，接收App重验许可。跨App主动导入不承诺复活原App审批。 |

```text
-- T57_LIBRARY_DDL_BEGIN
-- workspace w5 -> w6；事务迁移，引用CAS blob内容不可变，事件/outbox同原库。
CREATE TABLE library_versions (
 namespace TEXT NOT NULL,library_id TEXT NOT NULL,kind TEXT NOT NULL
 CHECK(kind IN ('character','filmSkill','musicRecipe')),entity_id TEXT NOT NULL,
 version TEXT NOT NULL,body_hash TEXT NOT NULL,
 PRIMARY KEY(namespace,library_id,kind,entity_id,version)
);
CREATE TRIGGER library_body_immutable BEFORE UPDATE ON library_versions
BEGIN SELECT RAISE(ABORT,'IMMUTABLE_VERSION'); END;
CREATE TABLE library_heads (
 namespace TEXT NOT NULL,library_id TEXT NOT NULL,kind TEXT NOT NULL,
 entity_id TEXT NOT NULL,head_version TEXT NOT NULL,
 PRIMARY KEY(namespace,library_id,kind,entity_id),
 FOREIGN KEY(namespace,library_id,kind,entity_id,head_version)
 REFERENCES library_versions(namespace,library_id,kind,entity_id,version)
);
CREATE TABLE character_look_index (
 namespace TEXT NOT NULL,library_id TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind='character'),
 asset_id TEXT NOT NULL,asset_version TEXT NOT NULL,look_id TEXT NOT NULL,body_hash TEXT NOT NULL,
 PRIMARY KEY(namespace,library_id,asset_id,asset_version,look_id),
 FOREIGN KEY(namespace,library_id,kind,asset_id,asset_version)
 REFERENCES library_versions(namespace,library_id,kind,entity_id,version)
);
CREATE TABLE model_adapter_bindings (
 namespace TEXT NOT NULL,library_id TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind='character'),
 asset_id TEXT NOT NULL,asset_version TEXT NOT NULL,binding_id TEXT NOT NULL,
 body_hash TEXT NOT NULL,base_fingerprint TEXT,
 PRIMARY KEY(namespace,library_id,asset_id,asset_version,binding_id),
 FOREIGN KEY(namespace,library_id,kind,asset_id,asset_version)
 REFERENCES library_versions(namespace,library_id,kind,entity_id,version)
);
CREATE TABLE portrait_rights_versions (
 namespace TEXT NOT NULL,rights_id TEXT NOT NULL,version TEXT NOT NULL,body_hash TEXT NOT NULL,
 PRIMARY KEY(namespace,rights_id,version)
);
CREATE TABLE portrait_rights_live (
 namespace TEXT NOT NULL,rights_id TEXT NOT NULL,epoch TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('active','revoked','expired','unknown')),
 checked_at TEXT,lease_until TEXT,
 PRIMARY KEY(namespace,rights_id)
);
CREATE TABLE library_project_pins (
 namespace TEXT NOT NULL,project_id TEXT NOT NULL,revision TEXT NOT NULL,
 library_id TEXT NOT NULL,kind TEXT NOT NULL,entity_id TEXT NOT NULL,version TEXT NOT NULL,
 effective_ref_hash TEXT NOT NULL,
 PRIMARY KEY(namespace,project_id,revision,library_id,kind,entity_id,version,effective_ref_hash),
 FOREIGN KEY(namespace,library_id,kind,entity_id,version)
 REFERENCES library_versions(namespace,library_id,kind,entity_id,version)
);
CREATE TABLE audio_candidates (
 namespace TEXT NOT NULL,id TEXT NOT NULL,plan_hash TEXT NOT NULL,state TEXT NOT NULL,
 manifest_hash TEXT,record_version TEXT NOT NULL,
 PRIMARY KEY(namespace,id),CHECK(state IN ('processing','ready','rejected','selected','quarantined'))
);
CREATE TABLE license_decisions (
 namespace TEXT NOT NULL,id TEXT NOT NULL,context_hash TEXT NOT NULL,body_hash TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('allow','block','needsReview')),valid_until TEXT,
 PRIMARY KEY(namespace,id)
);
CREATE VIRTUAL TABLE craft_fts USING fts5(namespace UNINDEXED,library_id UNINDEXED,
 skill_id UNINDEXED,version UNINDEXED,title,tags,uses,counterexamples);
-- ACL先在授权version集合中过滤，再join FTS结果；namespace列存在不代表自动有ACL。
-- 沿用artifact_dependencies登记rights/model/skill版本选择器，撤销走10A denylist/outbox。
-- seq/version数字比较仍用BigInt或规范非负串length,value排序，skill语义版本用SemVer比较器。
-- T57_LIBRARY_DDL_END
```

可编码路径：studio_audio_generation负责MusicSpec/Provider/LicenseGate；studio_asset_library负责不可变角色库/角色resolver/rights；studio_craft扩展既有SkillPackage及RegistryBridge；native/studio_media负责音频probe/重采样/混音/beat分析与受审transition节点。三者共用原CAS、Document CommandCoordinator、Harness/ContextCompiler/ResourceArbiter，不再各造会话/审批/渲染内核。API与DTO共享；原生模型worker、Web后端、存储授权仍各端适配，不宣称100%二进制复用。
