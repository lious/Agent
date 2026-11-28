// Closed, local manifest-schema subset metaschema; no remote resolution.
const manifestMetaschemaJson = r'''
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$ref": "#/$defs/schema",
  "$defs": {
    "schema": {
      "anyOf": [
        {
          "type": "boolean"
        },
        {
          "type": "object",
          "properties": {
            "type": {
              "enum": [
                "object",
                "array",
                "string",
                "integer",
                "number",
                "boolean",
                "null"
              ]
            },
            "properties": {
              "type": "object",
              "additionalProperties": {
                "$ref": "#/$defs/schema"
              }
            },
            "required": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "additionalProperties": {
              "const": false
            },
            "items": {
              "$ref": "#/$defs/schema"
            },
            "enum": {
              "type": "array",
              "minItems": 1
            },
            "const": true,
            "minimum": {
              "type": "number"
            },
            "maximum": {
              "type": "number"
            },
            "$defs": {
              "type": "object",
              "additionalProperties": {
                "$ref": "#/$defs/schema"
              }
            },
            "$ref": {
              "type": "string",
              "pattern": "^#/\\$defs/[A-Za-z][A-Za-z0-9_]{0,63}$"
            },
            "minItems": {
              "type": "integer",
              "minimum": 0,
              "maximum": 9007199254740991
            },
            "maxItems": {
              "type": "integer",
              "minimum": 0,
              "maximum": 9007199254740991
            },
            "minLength": {
              "type": "integer",
              "minimum": 0,
              "maximum": 9007199254740991
            },
            "maxLength": {
              "type": "integer",
              "minimum": 0,
              "maximum": 9007199254740991
            }
          },
          "additionalProperties": false
        }
      ]
    }
  }
}
''';
