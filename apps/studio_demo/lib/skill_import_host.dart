import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_assets/studio_signed_skill_import.dart';

import 'import_fixture_composition.dart';
import 'skill_import_panel.dart';
import 'skill_source_linux.dart';

/// Existing App workspace remains owner; no FoundationApp API changes.
class SkillImportHost extends StatefulWidget {
  const SkillImportHost({super.key, required this.workspace})
    : importFixture = null;
  const SkillImportHost.testImport({
    super.key,
    required this.workspace,
    required NativeImportFixtureConfiguration this.importFixture,
  });
  final StudioWorkspace workspace;
  final NativeImportFixtureConfiguration? importFixture;
  @override
  State<SkillImportHost> createState() => _SkillImportHostState();
}

class _SkillImportHostState extends State<SkillImportHost> {
  bool _projectMounted = false;
  BuildTimeSignaturePolicy? _policy;
  final _importLifetime = ImportCompositionLifetime();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _projectMounted = true);
    });
  }

  @override
  void didUpdateWidget(covariant SkillImportHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.importFixture, widget.importFixture) ||
        !identical(oldWidget.workspace, widget.workspace)) {
      _importLifetime.invalidateBeforePublication();
      _policy = null;
    }
  }

  BuildTimeSignaturePolicy _policyForCurrent() {
    // Invoked only after the first frame, when FoundationApp has opened the demo.
    return _policy ??= widget.importFixture == null
        ? BuildTimeSignaturePolicy.disabled(
            widget.workspace.profile,
            widget.workspace.current.namespace,
          )
        : widget.importFixture!.policyForOwner(
            widget.workspace.profile,
            widget.workspace.current.namespace,
          );
  }

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
                    ownerLifetime: widget.importFixture == null
                        ? null
                        : _importLifetime,
                    currentApp: () {
                      final fixture = widget.importFixture;
                      return ImportAppSnapshot(
                        profile: widget.workspace.profile,
                        namespace: widget.workspace.current.namespace.toJson(),
                        policy: _policyForCurrent(),
                        nowSeconds:
                            fixture?.nowSeconds ??
                            DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        clockConfident: fixture?.clockConfident ?? false,
                        clockRollback: fixture?.clockRollback ?? false,
                        installedAllowlist: {...?fixture?.installedAllowlist},
                        sessionGrant: {...?fixture?.sessionGrant},
                        branchScope: {...?fixture?.branchScope},
                      );
                    },
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
                    chooseSource: (capture, guard, selected) {
                      final custom = widget.importFixture?.chooseSourceForTest;
                      if (custom != null) {
                        return custom(capture, guard, selected);
                      }
                      return chooseLinuxSkillSource(
                        capture,
                        currentAppStillValid: guard,
                        onSelected: selected,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
