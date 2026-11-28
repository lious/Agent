// Derived unchanged reference closure of urn:studio:FilmSkill:1.0.0 in s8g.
const filmSkillSchemaJson = r'''
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:studio:FilmSkill:1.0.0",
  "$ref": "#/$defs/FilmSkill",
  "$defs": {
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
    },
    "Hash": {
      "type": "string",
      "pattern": "^sha256:[0-9a-f]{64}$"
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
    "Id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$"
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
    "I64": {
      "type": "string",
      "pattern": "^(0|-[1-9][0-9]{0,18}|[1-9][0-9]{0,18})$"
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
    }
  }
}
''';
