import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_vertical/studio_vertical.dart';
import 'package:test/test.dart';

/// Increment 2.43 official I-038 leftover hug@1.0.0 PlayRecipe
/// slot/route refusals at the already-specified s8l bound. This file
/// does not invent auto-segmentation or paid generation, does not
/// open miniature / animalHumanized / babyDance library entries,
/// does not invent a PlanGraph manual-lock API, does not mark I-037
/// complete, and does not rewrite the Increment 2.42 fixture suite
/// or the frozen I-036 fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

HugSubject lan({
  bool hasImage = true,
  bool portraitConsent = true,
  String filename = 'z-lan.png',
  int peopleInImage = 1,
  bool fictional = true,
  bool isMinor = false,
  bool providerChildPolicyVerified = false,
}) => HugSubject(
  id: 'subject-lan',
  identity: hugLanIdentity,
  fictional: fictional,
  portraitConsent: portraitConsent,
  filename: filename,
  hasImage: hasImage,
  peopleInImage: peopleInImage,
  isMinor: isMinor,
  providerChildPolicyVerified: providerChildPolicyVerified,
);

HugSubject he({
  bool hasImage = true,
  bool portraitConsent = true,
  String filename = 'a-he.png',
  int peopleInImage = 1,
  bool fictional = true,
  bool isMinor = false,
  bool providerChildPolicyVerified = false,
}) => HugSubject(
  id: 'subject-he',
  identity: hugHeIdentity,
  fictional: fictional,
  portraitConsent: portraitConsent,
  filename: filename,
  hasImage: hasImage,
  peopleInImage: peopleInImage,
  isMinor: isMinor,
  providerChildPolicyVerified: providerChildPolicyVerified,
);

void main() {
  test('hug twoImages compiles the official R2V golden, keeps stable subject order, and does not submit or auto-segment', () {
    final compiler = PlayRecipeCompiler();
    final shot = compiler.compileHug(
      HugRequest(
        variant: HugVariant.twoImages,
        leftSubjectId: 'subject-lan',
        rightSubjectId: 'subject-he',
        // Filenames would sort 禾 before 岚; order stays the requested IDs.
        subjects: [
          lan(filename: 'z-lan.png'),
          he(filename: 'a-he.png'),
        ],
      ),
    );
    expect(shot.prompt, hugTwoImagesPrompt);
    expect(shot.recipeId, 'hug@1.0.0');
    expect(shot.route, 'r2v');
    expect(shot.leftSubjectId, 'subject-lan');
    expect(shot.rightSubjectId, 'subject-he');
    expect(shot.disclaimer, hugDisclaimer);
    expect(shot.overlayText, hugOverlayText);
    expect(shot.submitted, isFalse);
    expect(shot.documentWrites, 0);
    expect(compiler.documentWrites, 0);

    final locked = compiler.compileHug(
      HugRequest(
        variant: HugVariant.twoImages,
        leftSubjectId: 'subject-lan',
        rightSubjectId: 'subject-he',
        subjects: [lan(), he()],
        lockedDisclaimer: '已锁声明，不得被配方覆盖',
      ),
    );
    expect(locked.disclaimer, '已锁声明，不得被配方覆盖');
    expect(locked.submitted, isFalse);
  });

  test('a single 岚 still cannot pretend the twoImages template has a second photo; an explicit fictional partner changes the route', () {
    final compiler = PlayRecipeCompiler();
    expect(
      () => compiler.compileHug(
        HugRequest(
          variant: HugVariant.twoImages,
          leftSubjectId: 'subject-lan',
          rightSubjectId: 'subject-he',
          subjects: [lan(), he(hasImage: false)],
        ),
      ),
      code(slotCount),
    );
    expect(compiler.documentWrites, 0);

    final imagined = compiler.compileHug(
      HugRequest(
        variant: HugVariant.onePersonImaginedPartner,
        leftSubjectId: 'subject-lan',
        rightSubjectId: 'subject-he',
        subjects: [lan(), he(hasImage: false, fictional: true)],
      ),
    );
    expect(imagined.route, 'onePersonImaginedPartner');
    expect(imagined.route, isNot('r2v'));
    expect(imagined.prompt.contains('不假装第二张参考图存在'), isTrue);
    expect(imagined.leftSubjectId, 'subject-lan');
    expect(imagined.rightSubjectId, 'subject-he');
    expect(imagined.disclaimer, hugDisclaimer);
    expect(imagined.submitted, isFalse);
  });

  test('missing portrait, a real stranger auto-pair, a dual-person still, auto-segmentation, and an unverified child policy are refused without submit', () {
    final compiler = PlayRecipeCompiler();
    expect(
      () => compiler.compileHug(
        HugRequest(
          variant: HugVariant.twoPeoplePhoto,
          leftSubjectId: 'subject-lan',
          rightSubjectId: 'subject-he',
          subjects: [
            lan(fictional: false, portraitConsent: true),
            he(fictional: false, portraitConsent: false, hasImage: false),
          ],
        ),
      ),
      code(portraitConsentRequired),
    );
    expect(
      () => compiler.compileHug(
        HugRequest(
          variant: HugVariant.onePersonImaginedPartner,
          leftSubjectId: 'subject-lan',
          rightSubjectId: 'subject-he',
          subjects: [
            lan(fictional: false),
            he(hasImage: false, fictional: false),
          ],
        ),
      ),
      code(mediaCombination),
    );
    expect(
      () => compiler.compileHug(
        HugRequest(
          variant: HugVariant.twoImages,
          leftSubjectId: 'subject-lan',
          rightSubjectId: 'subject-he',
          subjects: [lan(peopleInImage: 2), he()],
        ),
      ),
      code(mediaCombination),
    );
    expect(
      () => compiler.compileHug(
        HugRequest(
          variant: HugVariant.twoImages,
          leftSubjectId: 'subject-lan',
          rightSubjectId: 'subject-he',
          subjects: [lan(), he()],
          requestAutoSegmentation: true,
        ),
      ),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileHug(
        HugRequest(
          variant: HugVariant.twoImages,
          leftSubjectId: 'subject-lan',
          rightSubjectId: 'subject-he',
          subjects: [
            lan(isMinor: true, providerChildPolicyVerified: false),
            he(),
          ],
        ),
      ),
      code(providerChildPolicyUnverified),
    );
    expect(compiler.documentWrites, 0);
  });
}
