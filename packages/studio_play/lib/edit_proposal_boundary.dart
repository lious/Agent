import 'package:studio_contracts/studio_contracts.dart';

/// v1.5 `edit_proposals` still admits only `renameProject`.
/// Play-mode decisions are a separate session workflow and must not be
/// wrapped as a catch-all project proposal.
const admittedEditProposalKind = 'renameProject';

const unsupportedPlayEditProposalKinds = {
  'lockScript',
  'unlockScript',
  'acceptTake',
  'acceptDelivery',
  'transitionAct',
  'editTimeline',
  'setCaptions',
  'setMarkers',
  'pictureLock',
};

/// Explicit fail-closed boundary: unconnected play actions are unsupported,
/// not admitted through a universal command.
void rejectPlayActionAsEditProposal(String kind) {
  if (kind == admittedEditProposalKind) {
    throw const StudioException(
      'PLAY_UNSUPPORTED_PROPOSAL',
      'renameProject stays on v1.5 edit_proposals, not this play workflow',
    );
  }
  throw StudioException('PLAY_UNSUPPORTED_PROPOSAL', kind);
}
