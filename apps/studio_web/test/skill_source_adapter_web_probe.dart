// TEST ONLY standalone boundary harness, NOT App UI/importer composition.
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:studio_web/skill_source_web.dart';

import 'package:studio_assets/craft/signed_import/source_capture.dart';

void main() {
  final capture = SkillSourceCapture();
  var state = <String, Object?>{'ready': true};
  void publish() => web.document.querySelector('#status')!.textContent =
      jsonEncode({...state, 'busy': capture.busy});
  void action(String id, void Function() f) {
    web.document
        .querySelector('#$id')!
        .addEventListener(
          'click',
          ((web.Event event) {
            if (event.isTrusted) {
              f();
              publish();
            }
          }).toJS,
        );
  }

  action('choose', () {
    state = {'pending': true};
    try {
      chooseWebSkillSource(capture).then<void>(
        (bytes) {
          var immutable = false;
          if (bytes != null) {
            try {
              bytes[0] = 0;
            } catch (_) {
              immutable = true;
            }
          }
          state = {
            'done': true,
            'length': bytes?.length,
            'sum': bytes?.fold<int>(0, (a, b) => a + b),
            'immutable': immutable,
          };
          publish();
          capture.quiescent.then((_) => publish());
        },
        onError: (Object e) {
          state = {'done': true, 'error': (e as SkillSourceException).reason};
          publish();
        },
      );
    } on SkillSourceException catch (e) {
      state = {'done': true, 'error': e.reason};
    }
  });
  action('cancel', capture.cancel);
  action('dispose', capture.dispose);
  publish();
}
