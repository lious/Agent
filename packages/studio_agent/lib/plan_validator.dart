import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'tool_registry.dart';

final class ToolCallPlan {
  ToolCallPlan({
    required this.id,
    required this.name,
    required Map<String, Object?> arguments,
  }) : arguments = Map.unmodifiable(arguments) {
    requireId(id);
  }

  final String id, name;
  final Map<String, Object?> arguments;

  static ToolCallPlan parse(String raw) {
    Map<String, Object?> json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const StudioException(toolSchemaInvalid, 'not-object');
      }
      json = Map<String, Object?>.from(decoded);
    } on StudioException {
      rethrow;
    } on Object {
      throw const StudioException(toolSchemaInvalid, 'json');
    }
    final id = json['id'];
    final name = json['name'];
    final args = json['arguments'];
    if (id is! String || name is! String) {
      throw const StudioException(toolSchemaInvalid, 'id-or-name');
    }
    if (args is! Map) {
      throw const StudioException(toolSchemaInvalid, 'arguments');
    }
    return ToolCallPlan(
      id: id,
      name: name,
      arguments: Map<String, Object?>.from(args),
    );
  }
}

/// Schema, whitelist, resource, and prompt-injection checks.
final class PlanValidator {
  PlanValidator(this.registry, {this.untrustedBodies = const []});

  final ToolRegistry registry;
  final List<String> untrustedBodies;

  static final _injectedVerbs = RegExp(
    r'\b(deleteProject|uploadAll|chargeCard|shell|formatDisk)\b',
    caseSensitive: false,
  );

  ToolCallPlan validate(String rawJson) {
    final plan = ToolCallPlan.parse(rawJson);
    final tool = registry.lookup(plan.name);
    if (tool == null) {
      throw StudioException(toolNotAllowed, plan.name);
    }
    tool.validate(plan.arguments);
    _refuseUntrustedInstructions(plan);
    return plan;
  }

  void _refuseUntrustedInstructions(ToolCallPlan plan) {
    for (final body in untrustedBodies) {
      if (!_injectedVerbs.hasMatch(body)) continue;
      // An injected verb in untrusted text cannot authorize a matching
      // or high-impact tool name / argument.
      final blob = jsonEncode(plan.arguments);
      if (plan.name.contains('delete') ||
          plan.name.contains('upload') ||
          plan.name.contains('pay') ||
          plan.name.contains('shell') ||
          _injectedVerbs.hasMatch(blob) ||
          _injectedVerbs.hasMatch(plan.name)) {
        throw StudioException(untrustedInstructionRefused, plan.name);
      }
    }
  }

  /// Untrusted text alone is never a plan. This helper exists so tests
  /// can show that raw document text does not parse as a tool call.
  static void refuseRawUntrustedAsPlan(String body) {
    try {
      ToolCallPlan.parse(body);
    } on StudioException catch (e) {
      if (e.code == toolSchemaInvalid) return;
      rethrow;
    }
    // A complete JSON object in untrusted text still needs the registry
    // path; callers must not execute it directly.
    throw const StudioException(untrustedInstructionRefused, 'raw');
  }
}
