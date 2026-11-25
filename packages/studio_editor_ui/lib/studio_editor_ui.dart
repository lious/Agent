import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

/// Real persisted project metadata slice, not a pretend timeline/media editor.
class FoundationApp extends StatefulWidget {
  const FoundationApp({super.key, required this.workspace});
  final StudioWorkspace workspace;
  @override
  State<FoundationApp> createState() => _FoundationAppState();
}

class _FoundationAppState extends State<FoundationApp> {
  late ProjectDocument _project;
  late TextEditingController _title;
  String? _error;
  @override
  void initState() {
    super.initState();
    _project = widget.workspace.openDemo();
    _title = TextEditingController(text: _project.title);
  }

  void _act(ProjectDocument Function() action) {
    try {
      final p = action();
      setState(() {
        _project = p;
        _title.text = p.title;
        _error = null;
      });
    } on StudioException catch (e) {
      setState(() => _error = e.code);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Studio Foundation',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: Scaffold(
      appBar: AppBar(
        title: Text('${widget.workspace.profile.appId} · Foundation'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Project metadata · local SQLite',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  'Revision ${_project.revision}',
                  key: const Key('revision'),
                ),
                TextField(
                  key: const Key('title'),
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Project title'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      key: const Key('save'),
                      onPressed: () => _act(
                        () => widget.workspace.rename(
                          _title.text,
                          expectedRevision: _project.revision,
                        ),
                      ),
                      child: const Text('Save title'),
                    ),
                    OutlinedButton(
                      key: const Key('undo'),
                      onPressed: widget.workspace.canUndo
                          ? () => _act(
                              () => widget.workspace.undo(
                                expectedRevision: _project.revision,
                              ),
                            )
                          : null,
                      child: const Text('Undo latest'),
                    ),
                  ],
                ),
                if (_error != null)
                  Text(
                    _error!,
                    key: const Key('error'),
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Import, timeline editing, media rendering and AI generation are not implemented in this build. No media leaves this device.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
