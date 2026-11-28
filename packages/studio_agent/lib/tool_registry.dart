import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';

enum ToolSideEffect { none, preview, mutate }

final class ToolArgumentSchema {
  const ToolArgumentSchema({
    required this.name,
    required this.kind,
    this.required = true,
    this.allowed,
    this.maxLength = 128,
  });

  final String name, kind;
  final bool required;
  final Set<String>? allowed;
  final int maxLength;
}

typedef ToolHandler = Future<Map<String, Object?>> Function(
  Map<String, Object?> arguments,
);

final class RegisteredTool {
  RegisteredTool({
    required this.name,
    required this.sideEffect,
    required List<ToolArgumentSchema> arguments,
    required this.handler,
    this.requiresApproval = false,
  }) : arguments = List.unmodifiable(arguments) {
    requireId(name.replaceAll('.', '-'));
  }

  final String name;
  final ToolSideEffect sideEffect;
  final List<ToolArgumentSchema> arguments;
  final ToolHandler handler;
  final bool requiresApproval;

  void validate(Map<String, Object?> values) {
    for (final spec in arguments) {
      if (spec.required && !values.containsKey(spec.name)) {
        throw StudioException(toolSchemaInvalid, spec.name);
      }
      final value = values[spec.name];
      if (value == null) continue;
      if (spec.kind == 'string' && value is! String) {
        throw StudioException(toolSchemaInvalid, spec.name);
      }
      if (value is String) {
        if (value.length > spec.maxLength) {
          throw StudioException(toolSchemaInvalid, spec.name);
        }
        requireId(value);
        if (spec.allowed != null && !spec.allowed!.contains(value)) {
          throw StudioException(toolSchemaInvalid, spec.name);
        }
      }
    }
    for (final key in values.keys) {
      if (!arguments.any((s) => s.name == key)) {
        throw StudioException(toolSchemaInvalid, key);
      }
    }
  }
}

/// Restricted tool catalog. Shell, free file paths, free network, payment,
/// and project-delete tools cannot be registered.
final class ToolRegistry {
  ToolRegistry();

  final Map<String, RegisteredTool> _tools = {};
  static const forbiddenNames = {
    'shell',
    'fs.readArbitrary',
    'fs.write',
    'net.fetch',
    'payments.charge',
    'project.delete',
    'deleteProject',
    'uploadAll',
    'chargeCard',
  };

  void register(RegisteredTool tool) {
    if (forbiddenNames.contains(tool.name) ||
        tool.name.startsWith('shell.') ||
        tool.name.startsWith('net.') ||
        tool.name.startsWith('payments.')) {
      throw StudioException(toolNotAllowed, tool.name);
    }
    _tools[tool.name] = tool;
  }

  List<RegisteredTool> get registeredTools => List.unmodifiable(_tools.values);

  RegisteredTool? lookup(String name) => _tools[name];

  /// Official default catalog for Increment 2.14 tests.
  static ToolRegistry officialDefaults({
    required Map<String, int> sideEffectCounts,
    Map<String, Object?>? lastInspect,
  }) {
    final registry = ToolRegistry();
    registry.register(
      RegisteredTool(
        name: 'timeline.inspect',
        sideEffect: ToolSideEffect.none,
        arguments: const [ToolArgumentSchema(name: 'clipId', kind: 'string')],
        handler: (args) async {
          lastInspect?.addAll(args);
          return {'clipId': args['clipId'], 'durationTicks': 24};
        },
      ),
    );
    registry.register(
      RegisteredTool(
        name: 'edit.propose',
        sideEffect: ToolSideEffect.preview,
        requiresApproval: true,
        arguments: const [
          ToolArgumentSchema(name: 'clipId', kind: 'string'),
          ToolArgumentSchema(
            name: 'action',
            kind: 'string',
            allowed: {'rename'},
          ),
        ],
        handler: (args) async {
          sideEffectCounts['edit.propose'] =
              (sideEffectCounts['edit.propose'] ?? 0) + 1;
          return {'preview': true, 'clipId': args['clipId']};
        },
      ),
    );
    registry.register(
      RegisteredTool(
        name: 'speech.preview',
        sideEffect: ToolSideEffect.preview,
        arguments: const [
          ToolArgumentSchema(name: 'sentenceId', kind: 'string'),
        ],
        handler: (args) async => {
          'sentenceId': args['sentenceId'],
          'preview': true,
        },
      ),
    );
    registry.register(
      RegisteredTool(
        name: 'character.lookup',
        sideEffect: ToolSideEffect.none,
        arguments: const [
          ToolArgumentSchema(name: 'characterId', kind: 'string'),
        ],
        handler: (args) async => {'characterId': args['characterId']},
      ),
    );
    return registry;
  }
}
