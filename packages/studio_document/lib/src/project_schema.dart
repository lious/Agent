// Generated from docs/studio/spec/s5.md. Do not edit.
const projectSchemaJson = r'''
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schemaVersion",
    "minReaderVersion",
    "projectId",
    "namespace",
    "revision",
    "title",
    "rootSequenceId",
    "sequences",
    "assets",
    "blobs",
    "effects",
    "transitions",
    "captions",
    "audioBuses",
    "markers",
    "rightsRecords",
    "linkGroups",
    "selectionGroups",
    "imageDocuments",
    "briefs",
    "scripts",
    "scenes",
    "characters",
    "shots",
    "generationRecords",
    "fontRefs",
    "modelRefs",
    "retainedSources",
    "defaultFontRef",
    "requiredFeatures",
    "extensions"
  ],
  "properties": {
    "schemaVersion": {
      "const": "2.0.0"
    },
    "minReaderVersion": {
      "const": "2.0.0"
    },
    "projectId": {
      "$ref": "#/$defs/Id"
    },
    "namespace": {
      "$ref": "#/$defs/Namespace"
    },
    "revision": {
      "$ref": "#/$defs/U64"
    },
    "title": {
      "type": "string",
      "minLength": 1,
      "maxLength": 1024
    },
    "rootSequenceId": {
      "$ref": "#/$defs/Id"
    },
    "sequences": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Sequence"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "assets": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Asset"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "blobs": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Blob"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "effects": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Effect"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "transitions": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Transition"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "captions": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Caption"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "audioBuses": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/AudioBus"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "markers": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Marker"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "rightsRecords": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Rights"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "linkGroups": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/LinkGroup"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "selectionGroups": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/SelectionGroup"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "imageDocuments": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/ImageDocument"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "briefs": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Brief"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "scripts": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Script"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "scenes": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Scene"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "characters": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Character"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "shots": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Shot"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "generationRecords": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/GenerationRecord"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "fontRefs": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/Font"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "modelRefs": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/ModelRef"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "retainedSources": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/RetainedSource"
      },
      "minItems": 0,
      "maxItems": 100000
    },
    "defaultFontRef": {
      "anyOf": [
        {
          "$ref": "#/$defs/Id"
        },
        {
          "type": "null"
        }
      ]
    },
    "requiredFeatures": {
      "type": "array",
      "items": {
        "type": "string",
        "minLength": 1,
        "maxLength": 128
      },
      "minItems": 0,
      "maxItems": 1024
    },
    "extensions": {
      "$ref": "#/$defs/Extensions"
    }
  },
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:studio:project:2.0.0",
  "$defs": {
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
    },
    "Text": {
      "type": "string",
      "minLength": 0,
      "maxLength": 4096
    },
    "I64": {
      "type": "string",
      "pattern": "^(0|-[1-9][0-9]{0,18}|[1-9][0-9]{0,18})$"
    },
    "U64": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,18})$"
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[0-9a-f]{64}$"
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
    "Rate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "n",
        "d"
      ],
      "properties": {
        "n": {
          "type": "integer",
          "minimum": 1,
          "maximum": 240000
        },
        "d": {
          "type": "integer",
          "minimum": 1,
          "maximum": 100000
        }
      }
    },
    "Timestamp": {
      "type": "string",
      "format": "date-time",
      "pattern": "Z$"
    },
    "Version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
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
    "Extensions": {
      "type": "object",
      "propertyNames": {
        "pattern": "^[a-z][a-z0-9_.-]{1,127}$"
      },
      "additionalProperties": true,
      "maxProperties": 64
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
    "Source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "id",
        "version",
        "streamId"
      ],
      "properties": {
        "kind": {
          "enum": [
            "asset",
            "sequence",
            "imageDocument"
          ]
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "streamId": {
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
    "Color": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "primaries",
        "transfer",
        "matrix",
        "range",
        "bitDepth",
        "alpha"
      ],
      "properties": {
        "primaries": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "transfer": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "matrix": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "range": {
          "enum": [
            "full",
            "limited",
            "unspecified"
          ]
        },
        "bitDepth": {
          "type": "integer",
          "minimum": 1,
          "maximum": 32
        },
        "alpha": {
          "enum": [
            "none",
            "straight",
            "premultiplied"
          ]
        }
      }
    },
    "Stream": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "type",
        "codec",
        "profile",
        "width",
        "height",
        "pixelFormat",
        "timeBase",
        "startPTS",
        "duration",
        "nominalFrameRate",
        "variableFrameRate",
        "rotationDeg",
        "color",
        "sampleRate",
        "channels",
        "channelLayout"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "type": {
          "enum": [
            "video",
            "audio",
            "image"
          ]
        },
        "codec": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "profile": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "width": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 32768
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
              "maximum": 32768
            },
            {
              "type": "null"
            }
          ]
        },
        "pixelFormat": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "timeBase": {
          "$ref": "#/$defs/Time"
        },
        "startPTS": {
          "$ref": "#/$defs/I64"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "nominalFrameRate": {
          "anyOf": [
            {
              "$ref": "#/$defs/Rate"
            },
            {
              "type": "null"
            }
          ]
        },
        "variableFrameRate": {
          "type": "boolean"
        },
        "rotationDeg": {
          "enum": [
            0,
            90,
            180,
            270
          ]
        },
        "color": {
          "anyOf": [
            {
              "$ref": "#/$defs/Color"
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
              "maximum": 384000
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
              "maximum": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "channelLayout": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "Proxy": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "blobHash",
        "pipelineHash",
        "sourceVersion",
        "ptsMapBlobHash",
        "width",
        "height",
        "frameRate",
        "colorPolicy"
      ],
      "properties": {
        "blobHash": {
          "$ref": "#/$defs/Hash"
        },
        "pipelineHash": {
          "$ref": "#/$defs/Hash"
        },
        "sourceVersion": {
          "$ref": "#/$defs/U64"
        },
        "ptsMapBlobHash": {
          "$ref": "#/$defs/Hash"
        },
        "width": {
          "type": "integer",
          "minimum": 2,
          "maximum": 8192
        },
        "height": {
          "type": "integer",
          "minimum": 2,
          "maximum": 8192
        },
        "frameRate": {
          "$ref": "#/$defs/Rate"
        },
        "colorPolicy": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Asset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "name",
        "kind",
        "originalBlobHash",
        "externalLocator",
        "streams",
        "proxyRefs",
        "rightsId",
        "contentFingerprint",
        "status"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "video",
            "audio",
            "image",
            "mask",
            "model3d"
          ]
        },
        "originalBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "externalLocator": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "streams": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Stream"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "proxyRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Proxy"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        },
        "contentFingerprint": {
          "$ref": "#/$defs/Hash"
        },
        "status": {
          "enum": [
            "ready",
            "missing",
            "quarantined"
          ]
        }
      }
    },
    "Blob": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "hash",
        "bytes",
        "mime",
        "packagePath",
        "role"
      ],
      "properties": {
        "hash": {
          "$ref": "#/$defs/Hash"
        },
        "bytes": {
          "$ref": "#/$defs/U64"
        },
        "mime": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "packagePath": {
          "type": "string",
          "pattern": "^(assets|originals|fonts|proxies|renders|thumbnails|snapshots|extensions)/[A-Za-z0-9_./-]+$"
        },
        "role": {
          "enum": [
            "original",
            "generated",
            "proxy",
            "render",
            "mask",
            "font",
            "thumbnail",
            "snapshot",
            "evidence",
            "ptsMap"
          ]
        }
      }
    },
    "TimeMap": {
      "oneOf": [
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "rate"
          ],
          "properties": {
            "kind": {
              "const": "linear"
            },
            "rate": {
              "$ref": "#/$defs/Time"
            }
          }
        },
        {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "knots",
            "interpolation"
          ],
          "properties": {
            "kind": {
              "const": "piecewise"
            },
            "knots": {
              "type": "array",
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "u",
                  "v"
                ],
                "properties": {
                  "u": {
                    "$ref": "#/$defs/Time"
                  },
                  "v": {
                    "$ref": "#/$defs/Time"
                  }
                }
              },
              "minItems": 2,
              "maxItems": 2048
            },
            "interpolation": {
              "const": "linear"
            }
          }
        }
      ]
    },
    "Clip": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "trackId",
        "name",
        "source",
        "timelineRange",
        "sourceRange",
        "timeMap",
        "enabled",
        "lockedFields",
        "linkGroupId",
        "selectionGroupId",
        "effectIds",
        "shotId",
        "candidateId",
        "provenanceId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "source": {
          "$ref": "#/$defs/Source"
        },
        "timelineRange": {
          "$ref": "#/$defs/Range"
        },
        "sourceRange": {
          "$ref": "#/$defs/Range"
        },
        "timeMap": {
          "$ref": "#/$defs/TimeMap"
        },
        "enabled": {
          "type": "boolean",
          "default": true
        },
        "lockedFields": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 1,
            "maxLength": 256
          },
          "minItems": 0,
          "maxItems": 256
        },
        "linkGroupId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "selectionGroupId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "effectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 256
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
        "provenanceId": {
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
    "Gap": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "trackId",
        "timelineRange"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "timelineRange": {
          "$ref": "#/$defs/Range"
        }
      }
    },
    "Item": {
      "oneOf": [
        {
          "$ref": "#/$defs/Clip"
        },
        {
          "$ref": "#/$defs/Gap"
        }
      ]
    },
    "Track": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "sequenceId",
        "name",
        "kind",
        "order",
        "locked",
        "muted",
        "solo",
        "syncLock",
        "targeted",
        "busId",
        "items"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "sequenceId": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "kind": {
          "enum": [
            "video",
            "audio",
            "caption"
          ]
        },
        "order": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647
        },
        "locked": {
          "type": "boolean",
          "default": false
        },
        "muted": {
          "type": "boolean",
          "default": false
        },
        "solo": {
          "type": "boolean",
          "default": false
        },
        "syncLock": {
          "type": "boolean",
          "default": true
        },
        "targeted": {
          "type": "boolean",
          "default": false
        },
        "busId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "items": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Item"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "Sequence": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "version",
        "canvas",
        "frameRate",
        "sampleRate",
        "workingColor",
        "outputColor",
        "backgroundRGBA",
        "duration",
        "tracks",
        "markerIds",
        "masterBusId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "canvas": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "width",
            "height",
            "pixelAspect"
          ],
          "properties": {
            "width": {
              "type": "integer",
              "minimum": 2,
              "maximum": 8192,
              "multipleOf": 2
            },
            "height": {
              "type": "integer",
              "minimum": 2,
              "maximum": 8192,
              "multipleOf": 2
            },
            "pixelAspect": {
              "$ref": "#/$defs/Time"
            }
          }
        },
        "frameRate": {
          "$ref": "#/$defs/Rate"
        },
        "sampleRate": {
          "const": 48000
        },
        "workingColor": {
          "const": "linear-rec709"
        },
        "outputColor": {
          "const": "rec709"
        },
        "backgroundRGBA": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "minItems": 4,
          "maxItems": 4
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "tracks": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Track"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "markerIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "masterBusId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Keyframe": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "param",
        "localTime",
        "value",
        "interpolation",
        "easing"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "param": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "localTime": {
          "$ref": "#/$defs/Time"
        },
        "value": {
          "oneOf": [
            {
              "type": "number",
              "minimum": -1000000000000,
              "maximum": 1000000000000
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 2,
              "maxItems": 2
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 3,
              "maxItems": 3
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 4,
              "maxItems": 4
            },
            {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": -1000000000000,
                "maximum": 1000000000000
              },
              "minItems": 6,
              "maxItems": 6
            }
          ]
        },
        "interpolation": {
          "enum": [
            "hold",
            "linear"
          ]
        },
        "easing": {
          "type": "null"
        }
      }
    },
    "TransformParams": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "translateX",
        "translateY",
        "scaleX",
        "scaleY",
        "rotationDeg",
        "anchorX",
        "anchorY"
      ],
      "properties": {
        "translateX": {
          "type": "number",
          "minimum": -1000000000000,
          "maximum": 1000000000000,
          "default": 0
        },
        "translateY": {
          "type": "number",
          "minimum": -1000000000000,
          "maximum": 1000000000000,
          "default": 0
        },
        "scaleX": {
          "type": "number",
          "minimum": 0,
          "maximum": 100,
          "default": 1,
          "exclusiveMinimum": 0
        },
        "scaleY": {
          "type": "number",
          "minimum": 0,
          "maximum": 100,
          "default": 1,
          "exclusiveMinimum": 0
        },
        "rotationDeg": {
          "type": "number",
          "minimum": -360000,
          "maximum": 360000,
          "default": 0
        },
        "anchorX": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0.5
        },
        "anchorY": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0.5
        }
      }
    },
    "CropParams": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "left",
        "top",
        "right",
        "bottom"
      ],
      "properties": {
        "left": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0
        },
        "top": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 0
        },
        "right": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 1
        },
        "bottom": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 1
        }
      }
    },
    "TextParams": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "fontRef",
        "fontSizePx",
        "fillRGBA",
        "strokePx",
        "shadow",
        "lineHeight",
        "letterSpacing",
        "alignment",
        "layoutRect"
      ],
      "properties": {
        "fontRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "fontSizePx": {
          "type": "number",
          "minimum": 6,
          "maximum": 1024,
          "default": 48
        },
        "fillRGBA": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "minItems": 4,
          "maxItems": 4
        },
        "strokePx": {
          "type": "number",
          "minimum": 0,
          "maximum": 32,
          "default": 0
        },
        "shadow": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "offsetX",
            "offsetY",
            "blurPx",
            "rgba"
          ],
          "properties": {
            "offsetX": {
              "type": "number",
              "minimum": -1024,
              "maximum": 1024
            },
            "offsetY": {
              "type": "number",
              "minimum": -1024,
              "maximum": 1024
            },
            "blurPx": {
              "type": "number",
              "minimum": 0,
              "maximum": 128
            },
            "rgba": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              },
              "minItems": 4,
              "maxItems": 4
            }
          }
        },
        "lineHeight": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 4,
          "default": 1.2
        },
        "letterSpacing": {
          "type": "number",
          "minimum": -100,
          "maximum": 100,
          "default": 0
        },
        "alignment": {
          "enum": [
            "left",
            "center",
            "right",
            "justify"
          ]
        },
        "layoutRect": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          "minItems": 4,
          "maxItems": 4
        }
      }
    },
    "Effect": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "owner",
        "pluginVersion",
        "enabled",
        "keyframes",
        "extensions",
        "type",
        "parameters"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "owner": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "id"
          ],
          "properties": {
            "kind": {
              "enum": [
                "clip",
                "track",
                "sequence",
                "caption",
                "imageLayer",
                "audioBus"
              ]
            },
            "id": {
              "$ref": "#/$defs/Id"
            }
          }
        },
        "pluginVersion": {
          "$ref": "#/$defs/Version"
        },
        "enabled": {
          "type": "boolean"
        },
        "keyframes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Keyframe"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "extensions": {
          "$ref": "#/$defs/Extensions"
        },
        "type": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "parameters": {
          "type": "object"
        }
      },
      "oneOf": [
        {
          "properties": {
            "type": {
              "const": "transform2d"
            },
            "parameters": {
              "$ref": "#/$defs/TransformParams"
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "crop"
            },
            "parameters": {
              "$ref": "#/$defs/CropParams"
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "opacity"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "value"
              ],
              "properties": {
                "value": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1,
                  "default": 1
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "colorBasic"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "exposureStops",
                "contrast",
                "saturation"
              ],
              "properties": {
                "exposureStops": {
                  "type": "number",
                  "minimum": -8,
                  "maximum": 8,
                  "default": 0
                },
                "contrast": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 2,
                  "default": 1
                },
                "saturation": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 2,
                  "default": 1
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "mask"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "blobHash",
                "transform",
                "invert"
              ],
              "properties": {
                "blobHash": {
                  "$ref": "#/$defs/Hash"
                },
                "transform": {
                  "type": "array",
                  "items": {
                    "type": "number",
                    "minimum": -1000000000000,
                    "maximum": 1000000000000
                  },
                  "minItems": 6,
                  "maxItems": 6
                },
                "invert": {
                  "type": "boolean",
                  "default": false
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "gain"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "gainDb"
              ],
              "properties": {
                "gainDb": {
                  "type": "number",
                  "minimum": -96,
                  "maximum": 12,
                  "default": 0
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "pan"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "value",
                "mode"
              ],
              "properties": {
                "value": {
                  "type": "number",
                  "minimum": -1,
                  "maximum": 1,
                  "default": 0
                },
                "mode": {
                  "enum": [
                    "monoEqualPower",
                    "stereoBalance"
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "limiter"
            },
            "parameters": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "ceilingDb",
                "lookaheadMs",
                "releaseMs"
              ],
              "properties": {
                "ceilingDb": {
                  "type": "number",
                  "minimum": -24,
                  "maximum": 0,
                  "default": -1
                },
                "lookaheadMs": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 20,
                  "default": 5
                },
                "releaseMs": {
                  "type": "number",
                  "minimum": 1,
                  "maximum": 2000,
                  "default": 100
                }
              }
            }
          }
        },
        {
          "properties": {
            "type": {
              "const": "textStyle"
            },
            "parameters": {
              "$ref": "#/$defs/TextParams"
            }
          }
        },
        {
          "properties": {
            "type": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_.-]+/[A-Za-z0-9_.-]+$"
            },
            "parameters": {
              "type": "object",
              "maxProperties": 256
            }
          }
        }
      ]
    },
    "Transition": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sequenceId",
        "trackId",
        "leftClipId",
        "rightClipId",
        "cut",
        "before",
        "after",
        "kind",
        "curve",
        "missingHandlePolicy",
        "enabled"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sequenceId": {
          "$ref": "#/$defs/Id"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "leftClipId": {
          "$ref": "#/$defs/Id"
        },
        "rightClipId": {
          "$ref": "#/$defs/Id"
        },
        "cut": {
          "$ref": "#/$defs/Time"
        },
        "before": {
          "$ref": "#/$defs/Time"
        },
        "after": {
          "$ref": "#/$defs/Time"
        },
        "kind": {
          "enum": [
            "dissolve",
            "audioEqualPower"
          ]
        },
        "curve": {
          "const": "linear"
        },
        "missingHandlePolicy": {
          "enum": [
            "reject",
            "freeze"
          ]
        },
        "enabled": {
          "type": "boolean"
        }
      }
    },
    "Anchor": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "clipId",
        "range"
      ],
      "properties": {
        "kind": {
          "enum": [
            "absolute",
            "clipLocal",
            "source"
          ]
        },
        "clipId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
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
        }
      }
    },
    "Caption": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "trackId",
        "timelineRange",
        "text",
        "language",
        "styleEffectId",
        "anchor",
        "manualFields",
        "words",
        "speakerId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "trackId": {
          "$ref": "#/$defs/Id"
        },
        "timelineRange": {
          "$ref": "#/$defs/Range"
        },
        "text": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "language": {
          "type": "string",
          "pattern": "^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$"
        },
        "styleEffectId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "anchor": {
          "$ref": "#/$defs/Anchor"
        },
        "manualFields": {
          "type": "array",
          "items": {
            "enum": [
              "text",
              "timing",
              "style",
              "speaker"
            ]
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "words": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "text",
              "sourceRange",
              "confidence"
            ],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 0,
                "maxLength": 128
              },
              "sourceRange": {
                "$ref": "#/$defs/Range"
              },
              "confidence": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              }
            }
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "speakerId": {
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
    "AudioBus": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "inputBusIds",
        "gainDb",
        "pan",
        "effectIds",
        "muted",
        "solo",
        "outputBusId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "name": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "inputBusIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 128
        },
        "gainDb": {
          "type": "number",
          "minimum": -96,
          "maximum": 12,
          "default": 0
        },
        "pan": {
          "type": "number",
          "minimum": -1,
          "maximum": 1,
          "default": 0
        },
        "effectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 256
        },
        "muted": {
          "type": "boolean"
        },
        "solo": {
          "type": "boolean"
        },
        "outputBusId": {
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
    "Marker": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "sequenceId",
        "label",
        "colorRGBA",
        "anchor",
        "time",
        "duration",
        "ripple"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "sequenceId": {
          "$ref": "#/$defs/Id"
        },
        "label": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "colorRGBA": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "minItems": 4,
          "maxItems": 4
        },
        "anchor": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "clipId"
          ],
          "properties": {
            "kind": {
              "enum": [
                "absolute",
                "clipLocal"
              ]
            },
            "clipId": {
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
        "time": {
          "$ref": "#/$defs/Time"
        },
        "duration": {
          "$ref": "#/$defs/Time"
        },
        "ripple": {
          "type": "boolean"
        }
      }
    },
    "Rights": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "assetIds",
        "holder",
        "statement",
        "evidenceBlobHash",
        "providerTermsRef",
        "allowedUses",
        "territories",
        "expiresAt",
        "consentId",
        "verified"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "kind": {
          "enum": [
            "userAttestation",
            "license",
            "providerTerms"
          ]
        },
        "assetIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "holder": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "statement": {
          "type": "string",
          "minLength": 0,
          "maxLength": 16384
        },
        "evidenceBlobHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "providerTermsRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "allowedUses": {
          "type": "array",
          "items": {
            "enum": [
              "edit",
              "export",
              "upload",
              "redistribute"
            ]
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "territories": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 64
          },
          "minItems": 0,
          "maxItems": 100000
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
        "consentId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified": {
          "type": "boolean"
        }
      }
    },
    "LinkGroup": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "anchorClipId",
        "members",
        "syncPolicy"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "anchorClipId": {
          "$ref": "#/$defs/Id"
        },
        "members": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "clipId",
              "offset"
            ],
            "properties": {
              "clipId": {
                "$ref": "#/$defs/Id"
              },
              "offset": {
                "$ref": "#/$defs/Time"
              }
            }
          },
          "minItems": 2,
          "maxItems": 100000
        },
        "syncPolicy": {
          "enum": [
            "preserve",
            "allowOutOfSync"
          ]
        }
      }
    },
    "SelectionGroup": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "memberClipIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "memberClipIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 100000
        }
      }
    },
    "Layer": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "parentId",
        "kind",
        "sourceRef",
        "text",
        "transform",
        "opacity",
        "blendMode",
        "maskRef",
        "effectIds",
        "locked",
        "visible"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "parentId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "kind": {
          "enum": [
            "raster",
            "text",
            "group",
            "vector"
          ]
        },
        "sourceRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "text": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 65536
            },
            {
              "type": "null"
            }
          ]
        },
        "transform": {
          "type": "array",
          "items": {
            "type": "number",
            "minimum": -1000000000000,
            "maximum": 1000000000000
          },
          "minItems": 6,
          "maxItems": 6
        },
        "opacity": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "default": 1
        },
        "blendMode": {
          "enum": [
            "normal",
            "multiply",
            "screen"
          ]
        },
        "maskRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "effectIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 256
        },
        "locked": {
          "type": "boolean"
        },
        "visible": {
          "type": "boolean"
        }
      }
    },
    "ImageDocument": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "width",
        "height",
        "color",
        "rootLayerIds",
        "layers",
        "fontRefs"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "width": {
          "type": "integer",
          "minimum": 1,
          "maximum": 32768
        },
        "height": {
          "type": "integer",
          "minimum": 1,
          "maximum": 32768
        },
        "color": {
          "const": "linear-rec709"
        },
        "rootLayerIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "layers": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Layer"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "fontRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "Font": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "family",
        "style",
        "hash",
        "licenseRef",
        "embedAllowed",
        "fallbackFamilies"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "family": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "style": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "hash": {
          "$ref": "#/$defs/Hash"
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
        },
        "embedAllowed": {
          "type": "boolean"
        },
        "fallbackFamilies": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 1,
            "maxLength": 256
          },
          "minItems": 0,
          "maxItems": 32
        }
      }
    },
    "ModelRef": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "profileId",
        "packageHash",
        "weightLicenseId",
        "engineLicenseId"
      ],
      "properties": {
        "profileId": {
          "$ref": "#/$defs/Id"
        },
        "packageHash": {
          "anyOf": [
            {
              "$ref": "#/$defs/Hash"
            },
            {
              "type": "null"
            }
          ]
        },
        "weightLicenseId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "engineLicenseId": {
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
    "Reference": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "assetRef",
        "role",
        "rightsId"
      ],
      "properties": {
        "assetRef": {
          "$ref": "#/$defs/EntityRef"
        },
        "role": {
          "enum": [
            "subject",
            "style",
            "firstFrame",
            "lastFrame",
            "audio",
            "source"
          ]
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Brief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "locale",
        "audience",
        "objective",
        "targetDuration",
        "aspect",
        "deliveryPresetId",
        "requiredFacts",
        "forbiddenClaims",
        "referenceRefs",
        "brandPolicy",
        "audioPolicy",
        "textPolicy",
        "budget",
        "purpose",
        "purposePayload"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "locale": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "audience": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "objective": {
          "type": "string",
          "minLength": 1,
          "maxLength": 4096
        },
        "targetDuration": {
          "$ref": "#/$defs/Time"
        },
        "aspect": {
          "enum": [
            "9:16",
            "16:9",
            "1:1"
          ]
        },
        "deliveryPresetId": {
          "$ref": "#/$defs/Id"
        },
        "requiredFacts": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 2048
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "forbiddenClaims": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 2048
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "referenceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Reference"
          },
          "minItems": 0,
          "maxItems": 64
        },
        "brandPolicy": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "palette",
            "logoAssetRef",
            "safeArea",
            "restrictedTopics",
            "rightsAttestationId"
          ],
          "properties": {
            "palette": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 0,
                "maxLength": 64
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "logoAssetRef": {
              "anyOf": [
                {
                  "$ref": "#/$defs/EntityRef"
                },
                {
                  "type": "null"
                }
              ]
            },
            "safeArea": {
              "type": "array",
              "items": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              },
              "minItems": 4,
              "maxItems": 4
            },
            "restrictedTopics": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 0,
                "maxLength": 256
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "rightsAttestationId": {
              "$ref": "#/$defs/Id"
            }
          }
        },
        "audioPolicy": {
          "enum": [
            "originalOnly",
            "providedMusic",
            "generated",
            "silent"
          ]
        },
        "textPolicy": {
          "const": "editableOverlay"
        },
        "budget": {
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
        "purpose": {
          "enum": [
            "productAd",
            "social",
            "story",
            "tutorial",
            "photoMotion",
            "musicVisual"
          ]
        },
        "purposePayload": {
          "type": "object"
        }
      },
      "oneOf": [
        {
          "properties": {
            "purpose": {
              "const": "productAd"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "productName",
                "verifiedClaims",
                "audience",
                "cta",
                "referenceAssetId",
                "offer",
                "endDate",
                "brandPalette"
              ],
              "properties": {
                "productName": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 256
                },
                "verifiedClaims": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 1024
                  },
                  "minItems": 1,
                  "maxItems": 5
                },
                "audience": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "cta": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "referenceAssetId": {
                  "$ref": "#/$defs/Id"
                },
                "offer": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 1024
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "endDate": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/Timestamp"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "brandPalette": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 64
                  },
                  "minItems": 0,
                  "maxItems": 100000
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "social"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "platform",
                "audience",
                "topic",
                "hookText",
                "payoff",
                "trendReference",
                "captionsStyle"
              ],
              "properties": {
                "platform": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 128
                },
                "audience": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "topic": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "hookText": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "payoff": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "trendReference": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/EntityRef"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "captionsStyle": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 128
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "story"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "logline",
                "characterIds",
                "location",
                "conflict",
                "ending",
                "rating",
                "dialogue",
                "continuityBible"
              ],
              "properties": {
                "logline": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "characterIds": {
                  "type": "array",
                  "items": {
                    "$ref": "#/$defs/Id"
                  },
                  "minItems": 1,
                  "maxItems": 100000
                },
                "location": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2048
                },
                "conflict": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "ending": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "rating": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 64
                },
                "dialogue": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 4096
                  },
                  "minItems": 0,
                  "maxItems": 100000
                },
                "continuityBible": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 16384
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "tutorial"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "learningGoal",
                "steps",
                "factsSourceRefs",
                "targetAudience",
                "screenRecordingAsset",
                "safetyWarnings"
              ],
              "properties": {
                "learningGoal": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2048
                },
                "steps": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "additionalProperties": false,
                    "required": [
                      "action",
                      "expectedResult"
                    ],
                    "properties": {
                      "action": {
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 2048
                      },
                      "expectedResult": {
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 2048
                      }
                    }
                  },
                  "minItems": 1,
                  "maxItems": 100
                },
                "factsSourceRefs": {
                  "type": "array",
                  "items": {
                    "$ref": "#/$defs/EntityRef"
                  },
                  "minItems": 1,
                  "maxItems": 100000
                },
                "targetAudience": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "screenRecordingAsset": {
                  "anyOf": [
                    {
                      "$ref": "#/$defs/EntityRef"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "safetyWarnings": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 2048
                  },
                  "minItems": 0,
                  "maxItems": 100000
                }
              }
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "photoMotion"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "photoAssetId",
                "rightsConfirmed",
                "motionRegion",
                "cameraMotion",
                "preserveRegions",
                "loop",
                "endFrameAssetId"
              ],
              "properties": {
                "photoAssetId": {
                  "$ref": "#/$defs/Id"
                },
                "rightsConfirmed": {
                  "type": "boolean"
                },
                "motionRegion": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 4096
                },
                "cameraMotion": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "preserveRegions": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 0,
                    "maxLength": 1024
                  },
                  "minItems": 0,
                  "maxItems": 100000
                },
                "loop": {
                  "type": "boolean"
                },
                "endFrameAssetId": {
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
            }
          }
        },
        {
          "properties": {
            "purpose": {
              "const": "musicVisual"
            },
            "purposePayload": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "audioAssetId",
                "musicRights",
                "beatGridRef",
                "mood",
                "visualMotif",
                "targetRange",
                "lyrics",
                "bpm"
              ],
              "properties": {
                "audioAssetId": {
                  "$ref": "#/$defs/Id"
                },
                "musicRights": {
                  "$ref": "#/$defs/Id"
                },
                "beatGridRef": {
                  "$ref": "#/$defs/Hash"
                },
                "mood": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 1024
                },
                "visualMotif": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2048
                },
                "targetRange": {
                  "$ref": "#/$defs/Range"
                },
                "lyrics": {
                  "anyOf": [
                    {
                      "type": "string",
                      "minLength": 0,
                      "maxLength": 16384
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "bpm": {
                  "anyOf": [
                    {
                      "type": "number",
                      "minimum": 1,
                      "maximum": 400
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              }
            }
          }
        }
      ]
    },
    "Character": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "name",
        "appearanceRef",
        "motivation",
        "constraints",
        "rightsId"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 256
        },
        "appearanceRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "motivation": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "constraints": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 2048
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "rightsId": {
          "$ref": "#/$defs/Id"
        }
      }
    },
    "Script": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "briefId",
        "title",
        "sceneIds",
        "language",
        "status"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "briefId": {
          "$ref": "#/$defs/Id"
        },
        "title": {
          "type": "string",
          "minLength": 0,
          "maxLength": 256
        },
        "sceneIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "language": {
          "type": "string",
          "minLength": 0,
          "maxLength": 64
        },
        "status": {
          "enum": [
            "draft",
            "approved",
            "stale"
          ]
        }
      }
    },
    "Scene": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "scriptId",
        "order",
        "summary",
        "characterIds",
        "shotIds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "scriptId": {
          "$ref": "#/$defs/Id"
        },
        "order": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647
        },
        "summary": {
          "type": "string",
          "minLength": 0,
          "maxLength": 16384
        },
        "characterIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "shotIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "Shot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "version",
        "sceneId",
        "order",
        "purposeBeat",
        "targetTimelineRange",
        "subjectRefs",
        "setting",
        "action",
        "camera",
        "lighting",
        "continuity",
        "captionPlan",
        "voicePlan",
        "musicRange",
        "generationMode",
        "firstFrameRef",
        "lastFrameRef",
        "referenceRefs",
        "targetProviderProfileId",
        "selectedCandidateId",
        "lockedFields"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "sceneId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "order": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647
        },
        "purposeBeat": {
          "type": "string",
          "minLength": 0,
          "maxLength": 1024
        },
        "targetTimelineRange": {
          "$ref": "#/$defs/Range"
        },
        "subjectRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/EntityRef"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "setting": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "action": {
          "type": "string",
          "minLength": 0,
          "maxLength": 4096
        },
        "camera": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "size",
            "motion",
            "lensIntent"
          ],
          "properties": {
            "size": {
              "type": "string",
              "minLength": 0,
              "maxLength": 128
            },
            "motion": {
              "type": "string",
              "minLength": 0,
              "maxLength": 1024
            },
            "lensIntent": {
              "type": "string",
              "minLength": 0,
              "maxLength": 1024
            }
          }
        },
        "lighting": {
          "type": "string",
          "minLength": 0,
          "maxLength": 2048
        },
        "continuity": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "characterRefs",
            "wardrobe",
            "screenDirection",
            "propRefs",
            "mustPreserve"
          ],
          "properties": {
            "characterRefs": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/EntityRef"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "wardrobe": {
              "type": "string",
              "minLength": 0,
              "maxLength": 2048
            },
            "screenDirection": {
              "type": "string",
              "minLength": 0,
              "maxLength": 1024
            },
            "propRefs": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/EntityRef"
              },
              "minItems": 0,
              "maxItems": 100000
            },
            "mustPreserve": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 0,
                "maxLength": 2048
              },
              "minItems": 0,
              "maxItems": 100000
            }
          }
        },
        "captionPlan": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "text",
              "range"
            ],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 0,
                "maxLength": 4096
              },
              "range": {
                "$ref": "#/$defs/Range"
              }
            }
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "voicePlan": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "text",
              "range",
              "speakerId"
            ],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 0,
                "maxLength": 4096
              },
              "range": {
                "$ref": "#/$defs/Range"
              },
              "speakerId": {
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
          "minItems": 0,
          "maxItems": 100000
        },
        "musicRange": {
          "anyOf": [
            {
              "$ref": "#/$defs/Range"
            },
            {
              "type": "null"
            }
          ]
        },
        "generationMode": {
          "enum": [
            "t2v",
            "i2v",
            "firstLast",
            "reference"
          ]
        },
        "firstFrameRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "lastFrameRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/EntityRef"
            },
            {
              "type": "null"
            }
          ]
        },
        "referenceRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Reference"
          },
          "minItems": 0,
          "maxItems": 100000
        },
        "targetProviderProfileId": {
          "$ref": "#/$defs/Id"
        },
        "selectedCandidateId": {
          "anyOf": [
            {
              "$ref": "#/$defs/Id"
            },
            {
              "type": "null"
            }
          ]
        },
        "lockedFields": {
          "type": "array",
          "items": {
            "type": "string",
            "minLength": 0,
            "maxLength": 256
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    },
    "GenerationRecord": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "candidateIds",
        "provider",
        "modelId",
        "providerModelVersion",
        "templateId",
        "templateVersion",
        "promptHash",
        "promptText",
        "negativePrompt",
        "parameterProfileId",
        "inputAssetRefs",
        "seed",
        "parameters",
        "rights",
        "outputAssetRefs",
        "jobId",
        "createdAt"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/Id"
        },
        "candidateIds": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Id"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "provider": {
          "$ref": "#/$defs/Id"
        },
        "modelId": {
          "$ref": "#/$defs/Id"
        },
        "providerModelVersion": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 256
            },
            {
              "type": "null"
            }
          ]
        },
        "templateId": {
          "$ref": "#/$defs/Id"
        },
        "templateVersion": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64
        },
        "promptHash": {
          "$ref": "#/$defs/Hash"
        },
        "promptText": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 65536
            },
            {
              "type": "null"
            }
          ]
        },
        "negativePrompt": {
          "anyOf": [
            {
              "type": "string",
              "minLength": 0,
              "maxLength": 8192
            },
            {
              "type": "null"
            }
          ]
        },
        "parameterProfileId": {
          "$ref": "#/$defs/Id"
        },
        "inputAssetRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/EntityRef"
          },
          "minItems": 0,
          "maxItems": 100000
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
        "parameters": {
          "type": "object",
          "maxProperties": 128
        },
        "rights": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "attestationId",
            "licenseSnapshotRef"
          ],
          "properties": {
            "attestationId": {
              "$ref": "#/$defs/Id"
            },
            "licenseSnapshotRef": {
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
        "outputAssetRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/EntityRef"
          },
          "minItems": 1,
          "maxItems": 100000
        },
        "jobId": {
          "$ref": "#/$defs/Id"
        },
        "createdAt": {
          "$ref": "#/$defs/Timestamp"
        }
      }
    },
    "RetainedSource": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "id",
        "version",
        "definitionBlobHash",
        "dependencyBlobHashes"
      ],
      "properties": {
        "kind": {
          "enum": [
            "asset",
            "sequence",
            "imageDocument"
          ]
        },
        "id": {
          "$ref": "#/$defs/Id"
        },
        "version": {
          "$ref": "#/$defs/U64"
        },
        "definitionBlobHash": {
          "$ref": "#/$defs/Hash"
        },
        "dependencyBlobHashes": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/Hash"
          },
          "minItems": 0,
          "maxItems": 100000
        }
      }
    }
  }
}
''';
