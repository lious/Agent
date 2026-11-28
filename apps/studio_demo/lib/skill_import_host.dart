import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_assets/studio_signed_skill_import.dart';

import 'skill_import_panel.dart';
import 'skill_source_linux.dart';

/// Existing App workspace remains owner; no FoundationApp API changes.
class SkillImportHost extends StatefulWidget {
  const SkillImportHost({super.key, required this.workspace});
  final StudioWorkspace workspace;
  @override
  State<SkillImportHost> createState() => _SkillImportHostState();
}

class _SkillImportHostState extends State<SkillImportHost> {
  bool _projectMounted = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _projectMounted = true);
    });
  }

  late final BuildTimeSignaturePolicy _policy =
      BuildTimeSignaturePolicy.disabled(
        widget.workspace.profile,
        widget.workspace.current.namespace,
      );
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          FoundationApp(workspace: widget.workspace),
          if (_projectMounted)
            Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: SkillImportPanel(
                    ownerIdentity: widget.workspace,
                    currentApp: () => ImportAppSnapshot(
                      profile: widget.workspace.profile,
                      namespace: widget.workspace.current.namespace.toJson(),
                      policy: _policy,
                      nowSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      installedAllowlist: {},
                      sessionGrant: {},
                      branchScope: {},
                    ),
                    createRepository: (current, actions) async =>
                        FilmSkillRepository(
                          SodiumVerifier.loadTrusted(
                            const String.fromEnvironment(
                              'STUDIO_SIGNED_IMPORT_SODIUM_PATH',
                            ),
                            const String.fromEnvironment(
                              'STUDIO_SIGNED_IMPORT_SODIUM_SHA256',
                            ),
                          ),
                          current,
                          actions,
                        ),
                    chooseSource: (capture, guard, selected) =>
                        chooseLinuxSkillSource(
                          capture,
                          currentAppStillValid: guard,
                          onSelected: selected,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
