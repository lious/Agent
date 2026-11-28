import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'model_pack.dart';

final class ModelPin {
  const ModelPin({
    required this.requestedPackId,
    required this.actualPackId,
    required this.actualDigest,
    required this.actualOperator,
    required this.actualRuntime,
  });

  final String requestedPackId,
      actualPackId,
      actualDigest,
      actualOperator,
      actualRuntime;
}

final class LlmCapabilities {
  const LlmCapabilities({
    required this.supportsTools,
    required this.contextTokens,
    required this.outputTokens,
    required this.runtimeId,
  });

  final bool supportsTools;
  final int contextTokens, outputTokens;
  final String runtimeId;
}

final class LlmChunk {
  const LlmChunk({
    required this.seq,
    this.text = '',
    this.toolCallJson,
    this.done = false,
    this.finishReason,
  });

  final int seq;
  final String text;
  final String? toolCallJson;
  final bool done;

  /// Trustworthy adapter terminal evidence; null is not inferred.
  final String? finishReason;
}

final class LlmGenerateRequest {
  const LlmGenerateRequest({
    required this.prompt,
    required this.maxOutputTokens,
    this.toolsEnabled = true,
  });

  final String prompt;
  final int maxOutputTokens;
  final bool toolsEnabled;
}

/// Portable runtime port. Implementations must not claim device inference
/// unless a real pack and native backend are actually loaded.
abstract interface class LlmRuntimeAdapter {
  String get runtimeId;
  Future<ModelPin> load({
    required String requestedPackId,
    required ModelPackRegistry registry,
  });
  Future<void> unload();
  LlmCapabilities capabilities();
  List<int> tokenize(String text);
  Stream<LlmChunk> generate(LlmGenerateRequest request);
  void cancel();
}

/// Assembles a possibly unordered, duplicated, or truncated chunk stream
/// into text plus at most one complete tool-call JSON object. A half tool
/// call is never executed.
final class StreamAssembler {
  StreamAssembler({this.expectTools = true});

  final bool expectTools;
  final Map<int, LlmChunk> _buffer = {};
  final Set<int> _seen = {};
  final StringBuffer text = StringBuffer();
  String? toolCallJson;
  int _next = 0;
  bool done = false;

  /// Returns true when the stream completed with a coherent assembly.
  bool accept(LlmChunk chunk) {
    if (_seen.contains(chunk.seq)) {
      return done;
    }
    _seen.add(chunk.seq);
    _buffer[chunk.seq] = chunk;
    _drain();
    return done;
  }

  void _drain() {
    while (_buffer.containsKey(_next)) {
      final chunk = _buffer.remove(_next)!;
      if (chunk.text.isNotEmpty) {
        text.write(chunk.text);
      }
      if (chunk.toolCallJson != null) {
        if (toolCallJson != null && toolCallJson != chunk.toolCallJson) {
          throw const StudioException(planInvalid, 'tool-conflict');
        }
        toolCallJson = chunk.toolCallJson;
      }
      if (chunk.done) {
        done = true;
      }
      _next++;
    }
  }

  /// Completes only when [done] was seen and every seq below the done
  /// chunk was present. Incomplete tool JSON is refused, not executed.
  String? finish() {
    if (!done) {
      if (toolCallJson != null && !_isCompleteJson(toolCallJson!)) {
        throw const StudioException(toolSchemaInvalid, 'truncated');
      }
      throw const StudioException(planInvalid, 'truncated-stream');
    }
    if (_buffer.isNotEmpty) {
      throw const StudioException(planInvalid, 'unordered-gap');
    }
    if (toolCallJson != null && !_isCompleteJson(toolCallJson!)) {
      throw const StudioException(toolSchemaInvalid, 'truncated');
    }
    return toolCallJson;
  }

  static bool _isCompleteJson(String raw) {
    final t = raw.trim();
    if (t.isEmpty || !t.startsWith('{') || !t.endsWith('}')) return false;
    var depth = 0;
    var inString = false;
    var escape = false;
    for (final cu in t.codeUnits) {
      final ch = String.fromCharCode(cu);
      if (inString) {
        if (escape) {
          escape = false;
        } else if (ch == r'\') {
          escape = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth < 0) return false;
      }
    }
    return depth == 0 && !inString;
  }
}
