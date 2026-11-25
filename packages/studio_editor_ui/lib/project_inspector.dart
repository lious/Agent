import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:studio_document/studio_document.dart';

/// Read-only metadata inspection, not project admission, resource validation or
/// plugin execution. Deliberately has no SDK, dart:io, FFI, link or network port.
/// A rejected candidate never replaces the last validated inspection snapshot.
class ProjectInspectorPanel extends StatefulWidget {
  const ProjectInspectorPanel({super.key, this.loadSelectedBytes});
  final Future<List<int>> Function()? loadSelectedBytes;
  static const maxInputBytes = 1024 * 1024;
  @override
  State<ProjectInspectorPanel> createState() => _ProjectInspectorPanelState();
}

class _ProjectInspectorPanelState extends State<ProjectInspectorPanel> {
  final _input = TextEditingController();
  ProjectDocument? _document;
  String? _error;
  bool _loading = false;
  int _epoch = 0;

  void _accept(List<int> bytes) {
    final value = readStrictJson(
      bytes,
      maxBytes: ProjectInspectorPanel.maxInputBytes,
    );
    if (value is! Map<String, dynamic>) {
      throw const FormatException('PROJECT_OBJECT_REQUIRED');
    }
    final document = ProjectDocument.fromJson(value);
    setState(() {
      _document = document;
      _error = null;
    });
  }

  void _report(Object error) {
    if (mounted) setState(() => _error = '$error');
  }

  void _paste() {
    try {
      // Bound before UTF8 allocation too; the byte bound is authoritative.
      if (_input.text.length > ProjectInspectorPanel.maxInputBytes) {
        throw const FormatException('DOCUMENT_LIMIT');
      }
      _accept(utf8.encode(_input.text));
    } catch (error) {
      _report(error);
    }
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() => _loading = true);
    try {
      final bytes = await widget.loadSelectedBytes!();
      if (mounted && epoch == _epoch) _accept(bytes);
    } catch (error) {
      if (epoch == _epoch) _report(error);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _epoch++;
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const Key('schema-inspector'),
    title: const Text('Inspect project JSON (read-only)'),
    children: [
      const Text(
        'Inspection only: 1 MiB JSON limit. Validates structure and current '
        'Schema semantics, not media bytes, licenses, capabilities or plugin '
        'behavior. Does not import, switch, edit or persist your active project. '
        'References and locators are text only; nothing is opened or uploaded.',
      ),
      TextField(
        key: const Key('inspect-json'),
        controller: _input,
        minLines: 2,
        maxLines: 5,
        maxLength: ProjectInspectorPanel.maxInputBytes,
        decoration: const InputDecoration(
          labelText: 'Paste project metadata JSON',
        ),
      ),
      OutlinedButton(
        key: const Key('inspect-validate'),
        onPressed: _loading ? null : _paste,
        child: const Text('Validate and inspect pasted JSON'),
      ),
      if (widget.loadSelectedBytes != null)
        OutlinedButton(
          key: const Key('inspect-load'),
          onPressed: _loading ? null : _load,
          child: const Text('Inspect explicitly selected local JSON path'),
        ),
      if (_loading) const LinearProgressIndicator(key: Key('inspect-loading')),
      if (_error != null) Text(_error!, key: const Key('inspect-error')),
      if (_document != null)
        ProjectInspectorView(
          key: ValueKey(_document!.hash),
          document: _document!,
        ),
    ],
  );
}

/// Paged complete metadata, including opaque extensions/unknown plugin payloads.
/// No implicit URLs, media decoders, writes, or resource availability claims.
class ProjectInspectorView extends StatefulWidget {
  const ProjectInspectorView({super.key, required this.document});
  final ProjectDocument document;
  @override
  State<ProjectInspectorView> createState() => _ProjectInspectorViewState();
}

class _ProjectInspectorViewState extends State<ProjectInspectorView> {
  late Map<String, dynamic> _value;
  late List<String> _sections;
  late String _section;
  int _row = 0, _page = 0;
  String _json = '';
  final _reference = TextEditingController();
  String _matches = '';
  static const _pageSize = 4096;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant ProjectInspectorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.hash != widget.document.hash) _initialize();
  }

  void _initialize() {
    _value = widget.document.toJson();
    _sections = _value.keys.toList()..sort();
    _section = 'sequences';
    _row = 0;
    _reference.clear();
    _matches = '';
    _select();
  }

  int get _length =>
      _value[_section] is List ? (_value[_section] as List).length : 1;
  void _select() {
    _page = 0;
    final value = _value[_section];
    _json = const JsonEncoder.withIndent('  ')
        .convert(value is List ? (value.isEmpty ? [] : value[_row]) : value);
  }

  void _find() {
    final target = _reference.text;
    if (target.isEmpty || target.length > 256) {
      setState(() => _matches = 'Enter an exact id/hash (1–256 characters).');
      return;
    }
    final paths = <String>[];
    var total = 0;
    String escape(String s) => s.replaceAll('~', '~0').replaceAll('/', '~1');
    void visit(dynamic value, String path) {
      if (value is Map) {
        if (value['id'] == target || value['hash'] == target) {
          total++;
          if (paths.length < 16) paths.add(path);
        }
        for (final entry in value.entries) {
          visit(entry.value, '$path/${escape(entry.key as String)}');
        }
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          visit(value[i], '$path/$i');
        }
      }
    }

    visit(_value, '');
    setState(
      () => _matches =
          '$total matching metadata objects'
          '${total > 16 ? " (first16 shown)" : ""}: ${paths.join(", ")}',
    );
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end = (_page + 1) * _pageSize;
    final start = _page * _pageSize;
    // Avoid splitting a UTF16 surrogate pair in rendered chunks.
    var lo = start, hi = end < _json.length ? end : _json.length;
    bool lowSurrogate(int i) =>
        i < _json.length &&
        _json.codeUnitAt(i) >= 0xdc00 &&
        _json.codeUnitAt(i) <= 0xdfff;
    if (lo > 0 && lowSurrogate(lo)) lo--;
    if (hi < _json.length && lowSurrogate(hi)) hi--;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'READ ONLY · ${widget.document.title} · revision ${widget.document.revision}',
          key: const Key('inspect-snapshot'),
        ),
        Text(
          'Metadata hash ${widget.document.hash}. Blob bytes/provenance NOT verified.',
        ),
        DropdownButton<String>(
          key: const Key('inspect-section'),
          value: _section,
          isExpanded: true,
          items: [
            for (final key in _sections)
              DropdownMenuItem(
                value: key,
                child: Text(
                  '$key${_value[key] is List ? " (${(_value[key] as List).length})" : ""}',
                ),
              ),
          ],
          onChanged: (section) => setState(() {
            _section = section!;
            _row = 0;
            _select();
          }),
        ),
        Text(
          'Entry ${_length == 0 ? 0 : _row + 1}/$_length · exact JSON page ${_page + 1}/${(_json.length + _pageSize - 1) ~/ _pageSize}',
          key: const Key('inspect-position'),
        ),
        Wrap(
          children: [
            OutlinedButton(
              key: const Key('inspect-previous'),
              onPressed: _row > 0
                  ? () => setState(() {
                      _row--;
                      _select();
                    })
                  : null,
              child: const Text('Previous entry'),
            ),
            OutlinedButton(
              key: const Key('inspect-next'),
              onPressed: _row + 1 < _length
                  ? () => setState(() {
                      _row++;
                      _select();
                    })
                  : null,
              child: const Text('Next entry'),
            ),
            OutlinedButton(
              key: const Key('inspect-page-previous'),
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              child: const Text('Previous JSON page'),
            ),
            OutlinedButton(
              key: const Key('inspect-page-next'),
              onPressed: end < _json.length
                  ? () => setState(() => _page++)
                  : null,
              child: const Text('Next JSON page'),
            ),
          ],
        ),
        SelectableText(
          _json.substring(lo, hi),
          key: const Key('inspect-detail'),
        ),
        TextField(
          key: const Key('inspect-reference'),
          controller: _reference,
          maxLength: 256,
          decoration: const InputDecoration(
            labelText: 'Find exact metadata id or hash',
          ),
        ),
        OutlinedButton(
          key: const Key('inspect-find'),
          onPressed: _find,
          child: const Text(
            'Find metadata definitions (not resource resolution)',
          ),
        ),
        Text(_matches, key: const Key('inspect-matches')),
      ],
    );
  }
}
