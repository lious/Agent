import 'package:studio_contracts/studio_contracts.dart';

import 'play_compute.dart';

enum PlayMode { crew, mystery }

enum PersonKind { human, assistant }

enum CrewRole { director, assistantDirector, screenwriter, performer, editor }

enum MysteryRole { gm, player, publicScreen }

enum DeviceKind { host, privateClient, publicScreen, compute }

enum DeliveryKind { take, draft, request }

enum TaskPhase {
  issued,
  claimed,
  submitted,
  reviewed,
  accepted,
  cancelled,
  reassigned,
}

/// Person, role and device are authorized separately. A title is not admin.
final class TrustScope {
  const TrustScope(this.id);
  final String id;

  static const public = TrustScope('public');
  static const crewConfidential = TrustScope('crew.confidential');
  static const mysteryTruth = TrustScope('mystery.truth');
  static TrustScope character(String characterId) =>
      TrustScope('character.$characterId');
  static TrustScope sides(String characterId) =>
      TrustScope('sides.$characterId');

  @override
  bool operator ==(Object other) => other is TrustScope && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

final class PlayPerson {
  PlayPerson({
    required this.id,
    required this.label,
    this.kind = PersonKind.human,
  }) {
    requireId(id);
  }
  final String id, label;
  final PersonKind kind;
}

final class PlayDevice {
  PlayDevice({
    required this.id,
    required this.personId,
    required this.kind,
    required Set<TrustScope> scopes,
    bool canCompute = false,
    this.online = true,
  }) : scopes = Set.unmodifiable(_bounded(kind, scopes)),
       forcedAudience = kind == DeviceKind.publicScreen,
       canCompute = kind == DeviceKind.publicScreen ? false : canCompute {
    requireId(id);
    requireId(personId);
  }
  final String id, personId;
  final DeviceKind kind;
  final Set<TrustScope> scopes;
  final bool forcedAudience;
  final bool canCompute;
  bool online;

  /// Exact granted scopes only. Holding [TrustScope.mysteryTruth] does not
  /// admit any other scope; public screens stay audience-only.
  bool allows(TrustScope scope) {
    if (forcedAudience) return scope == TrustScope.public;
    return scopes.contains(scope);
  }

  static Set<TrustScope> _bounded(DeviceKind kind, Set<TrustScope> scopes) {
    if (kind == DeviceKind.publicScreen) return {TrustScope.public};
    return scopes;
  }
}

final class PlayGrant {
  PlayGrant({
    required this.id,
    required this.personId,
    required this.label,
    this.crewRole,
    this.mysteryRole,
    this.characterId,
    Set<String> sceneIds = const {},
    Set<String> departments = const {},
    this.lead = false,
  }) : sceneIds = Set.unmodifiable(sceneIds),
       departments = Set.unmodifiable(departments) {
    requireId(id);
    requireId(personId);
    if ((crewRole == null) == (mysteryRole == null)) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'role');
    }
    final character = characterId;
    if (character != null) requireId(character);
  }
  final String id, personId, label;
  final CrewRole? crewRole;
  final MysteryRole? mysteryRole;
  final String? characterId;
  final Set<String> sceneIds, departments;
  final bool lead;
  bool revoked = false;
}

/// The role used for a decision is recorded even when one person holds several.
final class Acting {
  Acting({
    required this.personId,
    required this.deviceId,
    required this.grantId,
    required this.roleLabel,
    required this.assistant,
  });
  final String personId, deviceId, grantId, roleLabel;
  final bool assistant;
}

final class DecisionRecord {
  DecisionRecord({
    required this.seq,
    required this.kind,
    required this.acting,
    required this.summary,
    this.draft = false,
    Map<String, Object?> data = const {},
  }) : data = Map.unmodifiable(data);
  final int seq;
  final String kind;
  final Acting acting;
  final String summary;
  final bool draft;
  final Map<String, Object?> data;
}

final class ViewDocument {
  const ViewDocument({
    required this.id,
    required this.title,
    required this.body,
    this.thumbnail = '',
    this.scope = 'public',
  });
  final String id, title, body, thumbnail, scope;
}

/// A projected view contains only records the (person, role, device) triple
/// may receive. Secrets are omitted entirely, not hidden by a control.
final class PlayView {
  PlayView({
    required this.personId,
    required this.deviceId,
    required this.grantId,
    required List<ViewDocument> documents,
    required List<ViewDocument> notifications,
    required List<String> logs,
    required List<ViewDocument> searchHits,
    required List<ViewDocument> computeOutputs,
    required List<ViewDocument> publicBoard,
  }) : documents = List.unmodifiable(documents),
       notifications = List.unmodifiable(notifications),
       logs = List.unmodifiable(logs),
       searchHits = List.unmodifiable(searchHits),
       computeOutputs = List.unmodifiable(computeOutputs),
       publicBoard = List.unmodifiable(publicBoard);
  final String personId, deviceId, grantId;
  final List<ViewDocument> documents,
      notifications,
      searchHits,
      computeOutputs,
      publicBoard;
  final List<String> logs;

  Iterable<String> get texts sync* {
    for (final row in [
      ...documents,
      ...notifications,
      ...searchHits,
      ...computeOutputs,
      ...publicBoard,
    ]) {
      yield row.body;
      yield row.thumbnail;
      yield row.title;
    }
    yield* logs;
  }

  bool containsText(String needle) => texts.any((t) => t.contains(needle));

  bool hasDocument(String id) =>
      documents.any((d) => d.id == id) || publicBoard.any((d) => d.id == id);
}

final class PlayScene {
  PlayScene({
    required this.id,
    required this.title,
    required this.body,
    required List<String> characterIds,
  }) : characterIds = List.unmodifiable(characterIds) {
    requireId(id);
  }
  final String id, title, body;
  final List<String> characterIds;
}

final class PlayCharacter {
  PlayCharacter({required this.id, required this.name, this.bible = const {}}) {
    requireId(id);
  }
  final String id, name;

  /// Citations reference script version + scene; this is not a second script.
  final Map<String, String> bible;
}

final class PlayShot {
  PlayShot({required this.id, required this.sceneId, required this.title}) {
    requireId(id);
    requireId(sceneId);
  }
  final String id, sceneId, title;
}

final class ScriptVersion {
  ScriptVersion({
    required this.id,
    required this.number,
    required List<PlayScene> scenes,
    required List<PlayCharacter> characters,
    required List<PlayShot> shots,
  }) : scenes = List.unmodifiable(scenes),
       characters = List.unmodifiable(characters),
       shots = List.unmodifiable(shots);
  final String id;
  final int number;
  final List<PlayScene> scenes;
  final List<PlayCharacter> characters;
  final List<PlayShot> shots;
  bool locked = false;

  PlayScene scene(String id) => scenes.firstWhere((s) => s.id == id);
  PlayCharacter character(String id) =>
      characters.firstWhere((c) => c.id == id);
}

final class WorkPackage {
  WorkPackage({
    required this.scriptVersionId,
    required this.callSheet,
    required this.shotList,
    required Map<String, String> sides,
    required Map<String, Map<String, String>> bible,
  }) : sides = Map.unmodifiable(sides),
       bible = Map.unmodifiable(bible);
  final String scriptVersionId, callSheet, shotList;
  final Map<String, String> sides;
  final Map<String, Map<String, String>> bible;
}

final class CrewTask {
  CrewTask({
    required this.id,
    required this.issuerGrantId,
    required this.issuerPersonId,
    required this.official,
    required this.craft,
    required this.sceneId,
    required this.scriptVersionId,
    this.assigneePersonId,
    this.department = '',
  });
  final String id,
      issuerGrantId,
      issuerPersonId,
      craft,
      sceneId,
      scriptVersionId;
  bool official;
  String? assigneePersonId;
  final String department;
  TaskPhase phase = TaskPhase.issued;
  bool needsReview = false;
  final List<String> history = [];
  String? claimedByPersonId;
  String? claimedByGrantId;
}

final class Delivery {
  Delivery({
    required this.id,
    required this.taskId,
    required this.authorPersonId,
    required this.authorGrantId,
    required this.kind,
    required this.body,
    required this.contentHash,
    required this.source,
    required this.scriptVersionId,
    required this.authorizationNote,
    this.supersedesId,
    this.technicalRetry = false,
  });
  final String id,
      taskId,
      authorPersonId,
      authorGrantId,
      body,
      contentHash,
      source,
      scriptVersionId,
      authorizationNote;
  final DeliveryKind kind;
  final String? supersedesId;
  final bool technicalRetry;
  String? technicalMark;
  String? adoptionId;
}

final class SpaceCard {
  SpaceCard({required this.id, required this.title, required this.body}) {
    requireId(id);
  }
  final String id, title, body;
}

final class PropTag {
  PropTag({required this.id, required this.spaceId, required this.label}) {
    requireId(id);
    requireId(spaceId);
  }
  final String id, spaceId, label;
}

final class MysteryClue {
  MysteryClue({
    required this.id,
    required this.title,
    required this.body,
    required this.thumbnail,
    this.characterId,
    this.spaceId,
  }) {
    requireId(id);
  }
  final String id, title, body, thumbnail;
  String? characterId;
  final String? spaceId;
  bool delivered = false;
  bool published = false;
  bool publicRequested = false;
}

final class StoryEvent {
  StoryEvent({
    required this.id,
    required this.kind,
    required this.actId,
    required this.visibility,
    required this.summary,
    Map<String, Object?> data = const {},
  }) : data = Map.unmodifiable(data) {
    if (kind.startsWith('NLE.') ||
        kind == 'SetCaptions' ||
        kind == 'SetMarkers' ||
        kind == 'renameProject') {
      throw StudioException('PLAY_UNSUPPORTED_PROPOSAL', 'story-event');
    }
  }
  final String id, kind, actId, visibility, summary;
  final Map<String, Object?> data;
}

final class PlaySession {
  PlaySession._({
    required this.id,
    required this.namespace,
    required this.mode,
    required PlayPerson host,
    required PlayDevice hostDevice,
    required PlayGrant hostGrant,
  }) {
    requireId(id);
    persons[host.id] = host;
    devices[hostDevice.id] = hostDevice;
    grants[hostGrant.id] = hostGrant;
    hostPersonId = host.id;
    hostDeviceId = hostDevice.id;
    hostGrantId = hostGrant.id;
    compute = PlayComputeDispatcher(this);
  }

  factory PlaySession.crew({
    required String id,
    required Namespace namespace,
    required String hostPersonId,
    required String hostDeviceId,
    String hostLabel = 'Director',
  }) {
    final host = PlayPerson(id: hostPersonId, label: hostLabel);
    return PlaySession._(
      id: id,
      namespace: namespace,
      mode: PlayMode.crew,
      host: host,
      hostDevice: PlayDevice(
        id: hostDeviceId,
        personId: hostPersonId,
        kind: DeviceKind.host,
        scopes: {TrustScope.public, TrustScope.crewConfidential},
        canCompute: true,
      ),
      hostGrant: PlayGrant(
        id: 'grant-director',
        personId: hostPersonId,
        label: 'director',
        crewRole: CrewRole.director,
      ),
    );
  }

  factory PlaySession.mystery({
    required String id,
    required Namespace namespace,
    required String hostPersonId,
    required String hostDeviceId,
    String hostLabel = 'GM',
  }) {
    final host = PlayPerson(id: hostPersonId, label: hostLabel);
    return PlaySession._(
      id: id,
      namespace: namespace,
      mode: PlayMode.mystery,
      host: host,
      hostDevice: PlayDevice(
        id: hostDeviceId,
        personId: hostPersonId,
        kind: DeviceKind.host,
        scopes: {TrustScope.public, TrustScope.mysteryTruth},
        canCompute: true,
      ),
      hostGrant: PlayGrant(
        id: 'grant-gm',
        personId: hostPersonId,
        label: 'gm',
        mysteryRole: MysteryRole.gm,
      ),
    );
  }

  final String id;
  final Namespace namespace;
  final PlayMode mode;
  late final String hostPersonId, hostDeviceId, hostGrantId;
  late final PlayComputeDispatcher compute;
  final Map<String, PlayPerson> persons = {};
  final Map<String, PlayDevice> devices = {};
  final Map<String, PlayGrant> grants = {};
  final List<DecisionRecord> decisions = [];
  final List<String> _logs = [];
  int _seq = 0;
  int projectRevision = 0;

  // Crew state
  final List<ScriptVersion> scripts = [];
  String? lockedScriptVersionId;
  final Map<String, CrewTask> tasks = {};
  final Map<String, Delivery> deliveries = {};
  final Map<String, DecisionRecord> adoptions = {};
  final List<DecisionRecord> draftOpinions = [];

  // Mystery state
  final List<SpaceCard> spaces = [];
  final List<PropTag> props = [];
  final Map<String, MysteryClue> clues = {};
  final Map<String, PlayCharacter> mysteryCharacters = {};
  String truth = '';
  String atmosphere = '';
  bool published = false;
  String currentAct = 'setup';
  final List<StoryEvent> storyLog = [];
  final Map<String, bool> memorialConsents = {};
  final Map<String, int> playerPage = {};
  final List<ViewDocument> computeOutputs = [];

  int get nextSeq => ++_seq;
  bool get hostOnline => devices[hostDeviceId]?.online ?? false;

  /// Authorized-host local execution is not a [PlayDevice.allows] wildcard.
  /// A GM notebook may run already-visible private material locally; a device
  /// that merely holds mysteryTruth still cannot admit other scopes.
  bool hostMayRunLocally(PlayDevice device, TrustScope scope) {
    if (device.id != hostDeviceId || !device.online || device.forcedAudience) {
      return false;
    }
    final g = grant(hostGrantId);
    if (g.revoked || g.mysteryRole != MysteryRole.gm) return false;
    if (!device.scopes.contains(TrustScope.mysteryTruth)) return false;
    return scope == TrustScope.mysteryTruth ||
        scope.id.startsWith('character.');
  }

  PlayPerson person(String id) =>
      persons[id] ?? (throw StudioException('PLAY_PERMISSION_DENIED', id));
  PlayDevice device(String id) =>
      devices[id] ?? (throw StudioException('PLAY_DEVICE_TRUST', id));
  PlayGrant grant(String id) =>
      grants[id] ?? (throw StudioException('PLAY_PERMISSION_DENIED', id));

  Acting acting({
    required String personId,
    required String deviceId,
    required String grantId,
  }) {
    final g = grant(grantId);
    final d = device(deviceId);
    person(personId);
    if (g.personId != personId) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'grant-person');
    }
    if (g.revoked) {
      throw StudioException('PLAY_ROLE_REVOKED');
    }
    if (d.personId != personId) {
      throw StudioException('PLAY_DEVICE_TRUST', 'device-person');
    }
    return Acting(
      personId: personId,
      deviceId: deviceId,
      grantId: grantId,
      roleLabel: g.label,
      assistant: person(personId).kind == PersonKind.assistant,
    );
  }

  void addPerson({
    required String id,
    required String label,
    PersonKind kind = PersonKind.human,
  }) {
    if (persons.containsKey(id)) {
      throw StudioException('PLAY_PERMISSION_DENIED', id);
    }
    persons[id] = PlayPerson(id: id, label: label, kind: kind);
  }

  void addDevice({
    required String id,
    required String personId,
    required DeviceKind kind,
    Set<TrustScope>? scopes,
    bool canCompute = false,
  }) {
    person(personId);
    if (devices.containsKey(id)) {
      throw StudioException('PLAY_DEVICE_TRUST', id);
    }
    var resolved = {...?scopes};
    if (resolved.isEmpty) resolved.add(TrustScope.public);
    if (kind == DeviceKind.privateClient) {
      for (final g in grants.values) {
        if (g.personId == personId && g.characterId != null && !g.revoked) {
          resolved.add(TrustScope.character(g.characterId!));
          resolved.add(TrustScope.sides(g.characterId!));
        }
      }
    }
    devices[id] = PlayDevice(
      id: id,
      personId: personId,
      kind: kind,
      scopes: resolved,
      canCompute: canCompute,
    );
  }

  void setOnline(String deviceId, bool online) {
    device(deviceId).online = online;
  }

  String grantRole({
    required Acting by,
    required String id,
    required String personId,
    required String label,
    CrewRole? crewRole,
    MysteryRole? mysteryRole,
    String? characterId,
    Set<String> sceneIds = const {},
    Set<String> departments = const {},
    bool lead = false,
  }) {
    _requireHostCapable(by, grantRoles: true);
    person(personId);
    if (mode == PlayMode.crew && crewRole == null) {
      throw StudioException('PLAY_MODE', 'crew-role');
    }
    if (mode == PlayMode.mystery && mysteryRole == null) {
      throw StudioException('PLAY_MODE', 'mystery-role');
    }
    final granted = PlayGrant(
      id: id,
      personId: personId,
      label: label,
      crewRole: crewRole,
      mysteryRole: mysteryRole,
      characterId: characterId,
      sceneIds: sceneIds,
      departments: departments,
      lead: lead,
    );
    grants[id] = granted;
    if (characterId != null &&
        (mysteryRole == MysteryRole.player || crewRole == CrewRole.performer)) {
      final extra = {
        TrustScope.character(characterId),
        TrustScope.sides(characterId),
      };
      for (final d in devices.values) {
        if (d.personId == personId && d.kind == DeviceKind.privateClient) {
          devices[d.id] = PlayDevice(
            id: d.id,
            personId: d.personId,
            kind: d.kind,
            scopes: {...d.scopes, ...extra},
            canCompute: d.canCompute,
          )..online = d.online;
        }
      }
    }
    _record(by, 'grant', 'granted $label to $personId');
    return id;
  }

  void revoke(Acting by, String grantId) {
    _requireHostCapable(by, grantRoles: true);
    grant(grantId).revoked = true;
    _record(by, 'revoke', 'revoked $grantId');
  }

  void _requireHostCapable(
    Acting by, {
    bool grantRoles = false,
    bool lock = false,
    bool approve = false,
  }) {
    if (by.assistant && (grantRoles || lock || approve)) {
      throw StudioException('PLAY_AI_FORBIDDEN');
    }
    final g = grant(by.grantId);
    if (g.revoked) throw StudioException('PLAY_ROLE_REVOKED');
    if (mode == PlayMode.crew) {
      if (g.crewRole != CrewRole.director &&
          !(g.crewRole == CrewRole.assistantDirector && !lock && !approve)) {
        if (grantRoles || lock || approve) {
          throw StudioException('PLAY_PERMISSION_DENIED');
        }
      }
      if ((lock || approve || grantRoles) && g.crewRole != CrewRole.director) {
        throw StudioException('PLAY_PERMISSION_DENIED');
      }
    }
    if (mode == PlayMode.mystery && g.mysteryRole != MysteryRole.gm) {
      if (grantRoles || lock || approve) {
        throw StudioException('PLAY_PERMISSION_DENIED');
      }
    }
  }

  DecisionRecord _record(
    Acting acting,
    String kind,
    String summary, {
    bool draft = false,
    Map<String, Object?> data = const {},
  }) {
    final row = DecisionRecord(
      seq: nextSeq,
      kind: kind,
      acting: acting,
      summary: summary,
      draft: draft,
      data: {'role': acting.roleLabel, ...data},
    );
    decisions.add(row);
    _logs.add(_scopedLog(acting, kind, summary));
    return row;
  }

  String _scopedLog(Acting acting, String kind, String summary) {
    final g = grant(acting.grantId);
    final d = device(acting.deviceId);
    final scope = d.forcedAudience
        ? 'public'
        : (g.mysteryRole == MysteryRole.gm
              ? 'gm'
              : (g.characterId != null
                    ? 'character.${g.characterId}'
                    : (g.crewRole == CrewRole.performer ? 'sides' : 'crew')));
    return '[$scope] $kind:${acting.roleLabel}:$summary';
  }

  List<String> _visibleLogs(PlayDevice device, PlayGrant grant) {
    return _logs.where((line) {
      if (device.forcedAudience ||
          grant.mysteryRole == MysteryRole.publicScreen) {
        return line.startsWith('[public]');
      }
      if (mode == PlayMode.mystery) {
        if (grant.mysteryRole == MysteryRole.gm &&
            device.allows(TrustScope.mysteryTruth)) {
          return true;
        }
        if (grant.characterId != null) {
          return line.startsWith('[public]') ||
              line.startsWith('[character.${grant.characterId}]');
        }
        return line.startsWith('[public]');
      }
      if (grant.crewRole == CrewRole.performer) {
        return !line.contains('full-script');
      }
      return true;
    }).toList();
  }

  // --- Crew workflow --------------------------------------------------

  ScriptVersion commitScriptVersion(
    Acting by, {
    required String id,
    required List<PlayScene> scenes,
    required List<PlayCharacter> characters,
    required List<PlayShot> shots,
  }) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    final g = grant(by.grantId);
    if (g.crewRole != CrewRole.director &&
        g.crewRole != CrewRole.screenwriter &&
        !by.assistant) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'script-draft');
    }
    if (scripts.any((s) => s.id == id)) {
      final existing = scripts.firstWhere((s) => s.id == id);
      if (existing.locked) {
        throw StudioException('PLAY_SCRIPT_LOCKED', id);
      }
    }
    final version = ScriptVersion(
      id: id,
      number: scripts.length + 1,
      scenes: scenes,
      characters: characters,
      shots: shots,
    );
    scripts.add(version);
    _record(by, 'script-draft', 'draft $id');
    return version;
  }

  void lockScript(Acting by, String versionId) {
    _requireMode(PlayMode.crew);
    _requireHostCapable(by, lock: true);
    final version = scripts.firstWhere(
      (s) => s.id == versionId,
      orElse: () => throw StudioException('PLAY_SCRIPT_LOCKED', versionId),
    );
    version.locked = true;
    lockedScriptVersionId = versionId;
    for (final task in tasks.values) {
      if (task.scriptVersionId != versionId &&
          task.phase != TaskPhase.accepted) {
        task.needsReview = true;
        task.history.add('needs-review after lock $versionId');
      }
    }
    _record(by, 'lock-script', 'locked $versionId');
  }

  void mutateScript(Acting by, String versionId) {
    _requireMode(PlayMode.crew);
    final version = scripts.firstWhere((s) => s.id == versionId);
    if (version.locked) {
      throw StudioException('PLAY_SCRIPT_LOCKED', versionId);
    }
    _record(by, 'mutate-script', versionId);
  }

  WorkPackage deriveWorkPackage(String versionId) {
    final version = scripts.firstWhere((s) => s.id == versionId);
    final sides = <String, String>{};
    final bible = <String, Map<String, String>>{};
    for (final character in version.characters) {
      final scenes = version.scenes
          .where((s) => s.characterIds.contains(character.id))
          .map((s) => '${s.id}:${s.title}:${s.body}')
          .join('\n');
      sides[character.id] = scenes;
      bible[character.id] = {
        for (final entry in character.bible.entries) entry.key: entry.value,
        'sourceVersion': version.id,
      };
    }
    return WorkPackage(
      scriptVersionId: version.id,
      callSheet: version.scenes.map((s) => s.id).join(','),
      shotList: version.shots.map((s) => s.id).join(','),
      sides: sides,
      bible: bible,
    );
  }

  String issueTask(
    Acting by, {
    required String id,
    required String craft,
    required String sceneId,
    required String scriptVersionId,
    String? assigneePersonId,
    String department = '',
  }) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    if (by.assistant) throw StudioException('PLAY_AI_FORBIDDEN');
    final g = grant(by.grantId);
    final official = _canIssueOfficial(
      g,
      sceneId: sceneId,
      department: department,
    );
    if (!official) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'issue');
    }
    final task = CrewTask(
      id: id,
      issuerGrantId: by.grantId,
      issuerPersonId: by.personId,
      official: true,
      craft: craft,
      sceneId: sceneId,
      scriptVersionId: scriptVersionId,
      assigneePersonId: assigneePersonId,
      department: department,
    );
    task.history.add('issued by ${by.roleLabel}');
    tasks[id] = task;
    _record(by, 'issue', id, data: {'role': by.roleLabel});
    return id;
  }

  String raiseRequest(
    Acting by, {
    required String id,
    required String craft,
    required String sceneId,
    required String scriptVersionId,
  }) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    final task = CrewTask(
      id: id,
      issuerGrantId: by.grantId,
      issuerPersonId: by.personId,
      official: false,
      craft: craft,
      sceneId: sceneId,
      scriptVersionId: scriptVersionId,
    );
    task.phase = TaskPhase.issued;
    task.history.add('request by ${by.roleLabel}');
    tasks[id] = task;
    _record(by, 'request', id);
    return id;
  }

  void approveRequest(Acting by, String taskId) {
    _requireMode(PlayMode.crew);
    final g = grant(by.grantId);
    if (g.crewRole != CrewRole.director &&
        g.crewRole != CrewRole.assistantDirector) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'approve-request');
    }
    final task = _task(taskId);
    if (task.official) throw StudioException('PLAY_TASK_STATE', taskId);
    task.official = true;
    task.history.add('approved as official by ${by.roleLabel}');
    _record(by, 'approve-request', taskId);
  }

  bool _canIssueOfficial(
    PlayGrant g, {
    required String sceneId,
    required String department,
  }) {
    if (g.crewRole == CrewRole.director ||
        g.crewRole == CrewRole.assistantDirector) {
      return true;
    }
    // Screenwriters may dispatch only inside explicitly assigned scenes.
    // Editors and lead performers are not official issuers; they raise requests.
    // Empty scene/department lists are not a wildcard, and `lead` alone is not
    // a license to issue official work.
    if (g.crewRole == CrewRole.screenwriter) {
      return g.sceneIds.contains(sceneId);
    }
    return false;
  }

  void claimTask(Acting by, String taskId) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    final task = _task(taskId);
    if (!task.official) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'request-not-issued');
    }
    if (task.phase != TaskPhase.issued && task.phase != TaskPhase.reassigned) {
      throw StudioException('PLAY_TASK_STATE', taskId);
    }
    task.phase = TaskPhase.claimed;
    task.claimedByPersonId = by.personId;
    task.claimedByGrantId = by.grantId;
    task.history.add('claimed by ${by.roleLabel}');
    _record(by, 'claim', taskId);
  }

  void cancelTask(Acting by, String taskId) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    final task = _task(taskId);
    _requireScheduleAuthority(by);
    final previous = task.phase;
    task.phase = TaskPhase.cancelled;
    task.history.add('cancelled from $previous by ${by.roleLabel}');
    _record(by, 'cancel', taskId);
  }

  void reassignTask(Acting by, String taskId, String newPersonId) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    final task = _task(taskId);
    _requireScheduleAuthority(by);
    final previous = '${task.phase}:${task.claimedByPersonId}';
    person(newPersonId);
    task.assigneePersonId = newPersonId;
    task.phase = TaskPhase.reassigned;
    task.history.add(
      'reassigned from $previous to $newPersonId by ${by.roleLabel}',
    );
    _record(by, 'reassign', taskId);
  }

  void _requireScheduleAuthority(Acting by) {
    if (by.assistant) throw StudioException('PLAY_AI_FORBIDDEN');
    final g = grant(by.grantId);
    if (g.crewRole != CrewRole.director &&
        g.crewRole != CrewRole.assistantDirector) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'schedule');
    }
  }

  String submitDelivery(
    Acting by, {
    required String id,
    required String taskId,
    required DeliveryKind kind,
    required String body,
    required String source,
    required String authorizationNote,
    String? supersedesId,
    bool technicalRetry = false,
  }) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    final task = _task(taskId);
    if (task.phase != TaskPhase.claimed &&
        task.phase != TaskPhase.submitted &&
        task.phase != TaskPhase.reviewed) {
      throw StudioException('PLAY_TASK_STATE', taskId);
    }
    if (task.claimedByPersonId != by.personId) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'not-claimer');
    }
    if (supersedesId != null && !deliveries.containsKey(supersedesId)) {
      throw StudioException('PLAY_TASK_STATE', supersedesId);
    }
    final delivery = Delivery(
      id: id,
      taskId: taskId,
      authorPersonId: by.personId,
      authorGrantId: by.grantId,
      kind: kind,
      body: body,
      contentHash: _hash(body),
      source: source,
      scriptVersionId: task.scriptVersionId,
      authorizationNote: authorizationNote,
      supersedesId: supersedesId,
      technicalRetry: technicalRetry,
    );
    deliveries[id] = delivery;
    task.phase = TaskPhase.submitted;
    task.history.add('submitted $id');
    _record(by, 'submit', id);
    return id;
  }

  void markTechnicalQuality(Acting by, String deliveryId, String mark) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    if (by.assistant) throw StudioException('PLAY_AI_FORBIDDEN');
    final g = grant(by.grantId);
    final delivery = deliveries[deliveryId]!;
    final task = _task(delivery.taskId);
    // Technical quality is a craft mark, not creative adoption.
    // Director and assistant director may mark any delivery; a performer
    // may mark only if they are the task assignee (claimer).
    final schedule =
        g.crewRole == CrewRole.director ||
        g.crewRole == CrewRole.assistantDirector;
    final assignee = task.claimedByPersonId == by.personId;
    if (!schedule && !assignee) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'technical');
    }
    delivery.technicalMark = mark;
    task.history.add('technical $mark');
    _record(by, 'technical', '$deliveryId:$mark');
  }

  /// Creative adoption. Offline host records a draft opinion only.
  DecisionRecord adoptDelivery(Acting by, String deliveryId) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    if (by.assistant) throw StudioException('PLAY_AI_FORBIDDEN');
    final g = grant(by.grantId);
    if (g.crewRole != CrewRole.director) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'adopt');
    }
    final delivery = deliveries[deliveryId]!;
    if (delivery.authorPersonId == by.personId) {
      throw StudioException('PLAY_SELF_APPROVAL');
    }
    if (!hostOnline) {
      final draft = _record(
        by,
        'draft-opinion',
        deliveryId,
        draft: true,
        data: {'deliveryId': deliveryId},
      );
      draftOpinions.add(draft);
      return draft;
    }
    final decision = _record(
      by,
      'adopt',
      deliveryId,
      data: {'deliveryId': deliveryId, 'role': by.roleLabel},
    );
    delivery.adoptionId = '${decision.seq}';
    adoptions[deliveryId] = decision;
    _task(delivery.taskId).phase = TaskPhase.reviewed;
    _task(delivery.taskId).history.add('adopted by ${by.roleLabel}');
    return decision;
  }

  /// Single writer + CAS against the play-layer revision. Not LWW. Not v1.5
  /// edit_proposals, and never auto-accepts a stale script version.
  void writerAccept(
    Acting by,
    String deliveryId, {
    required int expectedRevision,
  }) {
    _requireMode(PlayMode.crew);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    if (by.assistant) throw StudioException('PLAY_AI_FORBIDDEN');
    final g = grant(by.grantId);
    if (g.crewRole != CrewRole.director) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'writer');
    }
    if (expectedRevision != projectRevision) {
      throw StudioException('PLAY_STALE_REVISION');
    }
    final delivery = deliveries[deliveryId]!;
    if (delivery.authorPersonId == by.personId) {
      throw StudioException('PLAY_SELF_APPROVAL');
    }
    if (delivery.adoptionId == null) {
      throw StudioException('PLAY_TASK_STATE', 'not-adopted');
    }
    if (lockedScriptVersionId != null &&
        delivery.scriptVersionId != lockedScriptVersionId) {
      throw StudioException('PLAY_STALE_REVISION', 'script');
    }
    projectRevision += 1;
    _task(delivery.taskId).phase = TaskPhase.accepted;
    _task(delivery.taskId).history.add('writer-accepted at r$projectRevision');
    _record(
      by,
      'writer-accept',
      deliveryId,
      data: {'revision': projectRevision, 'role': by.roleLabel},
    );
  }

  CrewTask _task(String id) =>
      tasks[id] ?? (throw StudioException('PLAY_TASK_STATE', id));

  // --- Mystery workflow -----------------------------------------------

  void addSpace(Acting by, SpaceCard space) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    _requireMutable();
    spaces.add(space);
  }

  void addProp(Acting by, PropTag prop) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    _requireMutable();
    props.add(prop);
  }

  void addCharacterSheet(Acting by, PlayCharacter character) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    _requireMutable();
    mysteryCharacters[character.id] = character;
  }

  void addClue(Acting by, MysteryClue clue) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    _requireMutable();
    clues[clue.id] = clue;
  }

  void setTruth(Acting by, String value) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    _requireMutable();
    truth = value;
  }

  void setAtmosphere(Acting by, String value) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    _requireMutable();
    atmosphere = value;
  }

  void publishScenario(Acting by) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    published = true;
    currentAct = 'entry';
    _story(by, 'publish', 'entry', 'public', 'scenario frozen');
  }

  void transitionAct(Acting by, String actId) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    if (!hostOnline) throw StudioException('PLAY_HOST_OFFLINE');
    if (!published) {
      throw StudioException('PLAY_TASK_STATE', 'not-published');
    }
    currentAct = actId;
    _story(by, 'actTransition', actId, 'public', 'entered $actId');
  }

  void deliverPrivateClue(Acting by, String clueId, String characterId) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    if (!hostOnline) throw StudioException('PLAY_HOST_OFFLINE');
    final clue = clues[clueId]!;
    if (clue.characterId != null && clue.characterId != characterId) {
      throw StudioException('PLAY_VISIBILITY_DENIED');
    }
    clue.characterId = characterId;
    clue.delivered = true;
    _story(
      by,
      'clueDelivered',
      currentAct,
      'character.$characterId',
      'private clue $clueId',
      data: {'clueId': clueId, 'characterId': characterId},
    );
    _logs.add('[character.$characterId] clue:$clueId:${clue.body}');
  }

  void requestPublicReveal(Acting by, String clueId) {
    _requireMode(PlayMode.mystery);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    final g = grant(by.grantId);
    final clue = clues[clueId]!;
    if (g.characterId == null || g.characterId != clue.characterId) {
      throw StudioException('PLAY_VISIBILITY_DENIED');
    }
    clue.publicRequested = true;
    _story(
      by,
      'publicRequested',
      currentAct,
      'character.${g.characterId}',
      clueId,
    );
  }

  void publishClueToPublicBoard(Acting by, String clueId) {
    _requireMode(PlayMode.mystery);
    _requireGm(by);
    if (!hostOnline) throw StudioException('PLAY_HOST_OFFLINE');
    final clue = clues[clueId]!;
    if (!clue.publicRequested) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'not-requested');
    }
    clue.published = true;
    _story(by, 'cluePublished', currentAct, 'public', clueId);
    _logs.add('[public] clue:$clueId:${clue.body}');
  }

  void playerAdvancePage(Acting by, int page) {
    _requireMode(PlayMode.mystery);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    playerPage[by.personId] = page;
    _story(
      by,
      'playerPage',
      currentAct,
      'character.${grant(by.grantId).characterId}',
      'page $page',
    );
  }

  void recordMemorialConsent(Acting by, {required bool consented}) {
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    memorialConsents[by.personId] = consented;
  }

  Map<String, Object?> recap({required Acting by, required bool wantVideo}) {
    _requireMode(PlayMode.mystery);
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    final text = storyLog
        .where((e) => e.visibility == 'public')
        .map((e) => e.summary)
        .join('\n');
    if (!wantVideo) {
      return {'kind': 'text-recap', 'text': text, 'video': null};
    }
    // Consent is per person. The GM is a person too and cannot be skipped
    // just because the role is GM.
    final requiredPeople = <String>{};
    for (final g in grants.values) {
      if (g.revoked) continue;
      if (g.mysteryRole == MysteryRole.player ||
          g.mysteryRole == MysteryRole.gm) {
        requiredPeople.add(g.personId);
      }
    }
    final missing = requiredPeople.any((id) => memorialConsents[id] != true);
    if (missing) {
      throw StudioException('PLAY_CONSENT_REQUIRED');
    }
    // MVP A records the permit only; it does not encode video.
    return {
      'kind': 'memorial-permit',
      'text': text,
      'video': 'not-produced-in-mvp-a',
    };
  }

  void _requireGm(Acting by) {
    acting(personId: by.personId, deviceId: by.deviceId, grantId: by.grantId);
    if (by.assistant) throw StudioException('PLAY_AI_FORBIDDEN');
    if (grant(by.grantId).mysteryRole != MysteryRole.gm) {
      throw StudioException('PLAY_PERMISSION_DENIED', 'gm');
    }
  }

  void _requireMutable() {
    if (published) throw StudioException('PLAY_FROZEN');
  }

  void _requireMode(PlayMode expected) {
    if (mode != expected) throw StudioException('PLAY_MODE');
  }

  void _story(
    Acting by,
    String kind,
    String actId,
    String visibility,
    String summary, {
    Map<String, Object?> data = const {},
  }) {
    storyLog.add(
      StoryEvent(
        id: 'story-$_seq',
        kind: kind,
        actId: actId,
        visibility: visibility,
        summary: summary,
        data: data,
      ),
    );
    _record(
      by,
      kind,
      summary,
      data: {'actId': actId, 'visibility': visibility},
    );
  }

  // --- Views ----------------------------------------------------------

  PlayView view({
    required String personId,
    required String deviceId,
    required String grantId,
    String? query,
  }) {
    // Revoked grants cannot access further material.
    final g = grant(grantId);
    final d = device(deviceId);
    person(personId);
    if (g.personId != personId || d.personId != personId) {
      throw StudioException('PLAY_PERMISSION_DENIED');
    }
    if (g.revoked) throw StudioException('PLAY_ROLE_REVOKED');

    final docs = <ViewDocument>[];
    final notes = <ViewDocument>[];
    final publicBoard = <ViewDocument>[];
    final outputs = computeOutputs
        .where((o) => _visibleDocument(d, g, o))
        .toList();

    if (mode == PlayMode.crew) {
      _crewDocuments(d, g, docs);
    } else {
      _mysteryDocuments(d, g, docs, notes, publicBoard);
    }

    final logs = _visibleLogs(d, g);
    final hits = <ViewDocument>[];
    if (query != null && query.isNotEmpty) {
      for (final doc in [...docs, ...notes, ...publicBoard, ...outputs]) {
        if (doc.body.contains(query) ||
            doc.title.contains(query) ||
            doc.thumbnail.contains(query)) {
          hits.add(doc);
        }
      }
      for (final line in logs) {
        if (line.contains(query)) {
          hits.add(ViewDocument(id: 'log', title: 'log', body: line));
        }
      }
    }
    return PlayView(
      personId: personId,
      deviceId: deviceId,
      grantId: grantId,
      documents: docs,
      notifications: notes,
      logs: logs,
      searchHits: hits,
      computeOutputs: outputs,
      publicBoard: publicBoard,
    );
  }

  void _crewDocuments(PlayDevice d, PlayGrant g, List<ViewDocument> docs) {
    if (scripts.isEmpty) return;
    final current = scripts.lastWhere(
      (s) => s.id == (lockedScriptVersionId ?? scripts.last.id),
    );
    final pack = deriveWorkPackage(current.id);
    final canFull =
        d.allows(TrustScope.crewConfidential) &&
        g.crewRole != CrewRole.performer;
    if (canFull) {
      docs.add(
        ViewDocument(
          id: 'script-${current.id}',
          title: 'full-script',
          body: current.scenes.map((s) => s.body).join('\n'),
          scope: 'crew.confidential',
        ),
      );
    }
    if (g.crewRole == CrewRole.performer) {
      // Performers only see sides for characters they play, not the full script.
      for (final other in current.characters) {
        final grantFor = grants.values.any(
          (x) =>
              x.personId == g.personId &&
              !x.revoked &&
              x.characterId == other.id,
        );
        if (grantFor || g.characterId == other.id) {
          docs.add(
            ViewDocument(
              id: 'sides-${other.id}',
              title: 'sides',
              body: pack.sides[other.id] ?? '',
              scope: 'sides.${other.id}',
            ),
          );
        }
      }
    } else if (canFull) {
      for (final e in pack.sides.entries) {
        docs.add(
          ViewDocument(
            id: 'sides-${e.key}',
            title: 'sides',
            body: e.value,
            scope: 'sides.${e.key}',
          ),
        );
      }
    }
    for (final e in pack.bible.entries) {
      if (canFull || g.characterId == e.key) {
        docs.add(
          ViewDocument(
            id: 'bible-${e.key}',
            title: 'bible',
            body: 'sourceVersion=${e.value['sourceVersion']};${e.value}',
            scope: 'bible',
          ),
        );
      }
    }
  }

  void _mysteryDocuments(
    PlayDevice d,
    PlayGrant g,
    List<ViewDocument> docs,
    List<ViewDocument> notes,
    List<ViewDocument> publicBoard,
  ) {
    final gmPrivate =
        g.mysteryRole == MysteryRole.gm &&
        d.allows(TrustScope.mysteryTruth) &&
        !d.forcedAudience;
    if (gmPrivate && truth.isNotEmpty) {
      docs.add(
        ViewDocument(
          id: 'truth',
          title: 'truth',
          body: truth,
          thumbnail: 'thumb:$truth',
          scope: 'mystery.truth',
        ),
      );
      for (final c in mysteryCharacters.values) {
        docs.add(
          ViewDocument(
            id: 'character-${c.id}',
            title: c.name,
            body: '${c.name}:${c.bible}',
            scope: 'mystery.truth',
          ),
        );
      }
    }
    if (g.mysteryRole == MysteryRole.player && g.characterId != null) {
      final c = mysteryCharacters[g.characterId];
      if (c != null && d.allows(TrustScope.character(c.id))) {
        docs.add(
          ViewDocument(
            id: 'character-${c.id}',
            title: c.name,
            body: '${c.name}:${c.bible}',
            scope: 'character.${c.id}',
          ),
        );
      }
    }
    if (atmosphere.isNotEmpty) {
      docs.add(
        ViewDocument(
          id: 'atmosphere',
          title: 'atmosphere',
          body: atmosphere,
          scope: 'public',
        ),
      );
    }
    for (final space in spaces) {
      docs.add(
        ViewDocument(
          id: 'space-${space.id}',
          title: space.title,
          body: space.body,
          scope: 'public',
        ),
      );
    }
    for (final clue in clues.values) {
      final doc = ViewDocument(
        id: 'clue-${clue.id}',
        title: clue.title,
        body: clue.body,
        thumbnail: clue.thumbnail,
        scope: clue.published
            ? 'public'
            : (clue.characterId != null
                  ? 'character.${clue.characterId}'
                  : 'mystery.truth'),
      );
      if (clue.published) {
        publicBoard.add(doc);
        docs.add(doc);
        notes.add(
          ViewDocument(
            id: 'note-${clue.id}',
            title: 'published',
            body: 'public:${clue.title}',
            thumbnail: clue.thumbnail,
            scope: 'public',
          ),
        );
        continue;
      }
      final privateOk =
          clue.delivered &&
          clue.characterId != null &&
          ((g.characterId == clue.characterId &&
                  d.allows(TrustScope.character(clue.characterId!))) ||
              gmPrivate);
      if (privateOk) {
        docs.add(doc);
        notes.add(
          ViewDocument(
            id: 'note-${clue.id}',
            title: 'private-clue',
            body: 'private:${clue.body}',
            thumbnail: clue.thumbnail,
            scope: 'character.${clue.characterId}',
          ),
        );
      }
    }
  }

  bool _visibleDocument(PlayDevice d, PlayGrant g, ViewDocument doc) {
    if (doc.scope == 'public') return true;
    if (d.forcedAudience) return false;
    if (doc.scope == 'mystery.truth') {
      return g.mysteryRole == MysteryRole.gm &&
          d.allows(TrustScope.mysteryTruth);
    }
    if (doc.scope.startsWith('character.')) {
      final id = doc.scope.substring('character.'.length);
      return (g.characterId == id && d.allows(TrustScope.character(id))) ||
          (g.mysteryRole == MysteryRole.gm &&
              d.allows(TrustScope.mysteryTruth));
    }
    return false;
  }

  String _hash(String body) {
    // Content addressing stays inside the play package; 64 hex matches harness.
    var n = 0;
    final out = StringBuffer();
    for (final unit in body.codeUnits) {
      n = (n * 33 + unit) & 0xffffffff;
      out.write((n & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    final raw = out.toString().padRight(64, '0');
    return raw.substring(0, 64);
  }
}
