import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/call/bloc/call_bloc.dart';
import 'package:omni_chat/features/call/data/call_models.dart';
import 'package:omni_chat/features/call/data/ringer/call_ringer.dart';
import 'package:omni_chat/features/call/data/signaling_repository.dart';
import 'package:omni_chat/features/call/data/webrtc_service.dart';
import 'package:omni_chat/features/chat/data/chat_repository.dart';
import 'package:omni_chat/features/contacts/data/contact.dart';

class _MockSignaling extends Mock implements SignalingRepository {}

class _MockWebRtc extends Mock implements WebRtcService {}

class _MockRinger extends Mock implements CallRinger {}

class _MockChat extends Mock implements ChatRepository {}

class _MockStream extends Mock implements MediaStream {}

Matcher _phase(CallPhase p) => isA<CallState>().having((s) => s.phase, 'phase', p);

Matcher _ended(CallEndReason r) => isA<CallState>()
    .having((s) => s.phase, 'phase', CallPhase.ended)
    .having((s) => s.endReason, 'endReason', r);

void main() {
  final bob = Contact(uid: 'bob', name: 'Bob', email: 'bob@x', updatedAt: DateTime(2026));
  const offer = SessionDescription(sdp: 'o', type: 'offer');
  const answer = SessionDescription(sdp: 'a', type: 'answer');
  final now = DateTime(2026, 10, 15, 12);

  CallDoc doc({CallStatus status = CallStatus.ringing, SessionDescription? ans}) => CallDoc(
    id: 'c1',
    callerId: 'bob',
    calleeId: 'me',
    callerName: 'Bob',
    calleeName: 'Me',
    status: status,
    offer: offer,
    answer: ans,
  );

  late _MockSignaling signaling;
  late _MockWebRtc webRtc;
  late _MockRinger ringer;
  late _MockChat chat;
  late StreamController<IncomingCall?> incoming;
  late StreamController<CallDoc?> callDoc;
  late StreamController<PeerState> peerStates;
  late StreamController<RingerAction> ringerActions;
  late MediaStream local;

  setUpAll(() {
    registerFallbackValue(bob);
    registerFallbackValue(offer);
    registerFallbackValue(CallStatus.ended);
    registerFallbackValue(const IceCandidateData(candidate: 'c'));
  });

  setUp(() {
    signaling = _MockSignaling();
    webRtc = _MockWebRtc();
    ringer = _MockRinger();
    chat = _MockChat();
    incoming = StreamController<IncomingCall?>.broadcast();
    callDoc = StreamController<CallDoc?>.broadcast();
    peerStates = StreamController<PeerState>.broadcast();
    ringerActions = StreamController<RingerAction>.broadcast();
    local = _MockStream();

    when(() => webRtc.localCandidates).thenAnswer((_) => const Stream.empty());
    when(() => webRtc.remoteStreams).thenAnswer((_) => const Stream.empty());
    when(() => webRtc.peerStates).thenAnswer((_) => peerStates.stream);
    when(() => webRtc.openMedia()).thenAnswer((_) async => local);
    when(() => webRtc.createPeer()).thenAnswer((_) async {});
    when(() => webRtc.createOffer()).thenAnswer((_) async => offer);
    when(() => webRtc.createAnswer(any())).thenAnswer((_) async => answer);
    when(() => webRtc.acceptAnswer(any())).thenAnswer((_) async {});
    when(() => webRtc.hasRemoteDescription).thenReturn(false);
    when(() => webRtc.close()).thenAnswer((_) async {});

    when(() => ringer.actions).thenAnswer((_) => ringerActions.stream);
    when(() => ringer.startRingback()).thenAnswer((_) async {});
    when(
      () => ringer.startIncoming(
        callId: any(named: 'callId'),
        callerName: any(named: 'callerName'),
      ),
    ).thenAnswer((_) async {});
    when(() => ringer.stop()).thenAnswer((_) async {});
    when(() => ringer.connected()).thenAnswer((_) async {});
    when(() => ringer.ended()).thenAnswer((_) async {});
    when(() => ringer.dispose()).thenAnswer((_) async {});

    when(() => signaling.incomingCalls()).thenAnswer((_) => incoming.stream);
    when(() => signaling.createCall(any())).thenAnswer((_) async => 'c1');
    when(() => signaling.setOffer(any(), any())).thenAnswer((_) async {});
    when(() => signaling.setAnswer(any(), any())).thenAnswer((_) async {});
    when(() => signaling.setStatus(any(), any())).thenAnswer((_) async {});
    when(
      () => signaling.ring(
        calleeId: any(named: 'calleeId'),
        callId: any(named: 'callId'),
      ),
    ).thenAnswer((_) async {});
    when(() => signaling.cancelRing(any())).thenAnswer((_) async {});
    when(() => signaling.clearIncoming()).thenAnswer((_) async {});
    when(() => signaling.armDisconnectEnd(any())).thenAnswer((_) async {});
    when(() => signaling.disarmDisconnectEnd(any())).thenAnswer((_) async {});
    when(() => signaling.deleteCall(any())).thenAnswer((_) async {});
    when(() => signaling.watchCall(any())).thenAnswer((_) => callDoc.stream);
    when(() => signaling.getCall(any())).thenAnswer((_) async => doc());
    when(() => signaling.remoteCandidates(any(), fromCaller: any(named: 'fromCaller')))
        .thenAnswer((_) => const Stream.empty());

    when(
      () => chat.addCallLog(
        callId: any(named: 'callId'),
        peerId: any(named: 'peerId'),
        text: any(named: 'text'),
        outgoing: any(named: 'outgoing'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await incoming.close();
    await callDoc.close();
    await peerStates.close();
    await ringerActions.close();
  });

  CallBloc build({Duration ringTimeout = const Duration(seconds: 45)}) => CallBloc(
    signaling: signaling,
    webRtc: webRtc,
    ringer: ringer,
    chatRepository: chat,
    ringTimeout: ringTimeout,
    endedDisplay: const Duration(milliseconds: 50),
    clock: () => now,
  );

  void verifyLog(String text, {required bool outgoing}) =>
      verify(() => chat.addCallLog(callId: 'c1', peerId: 'bob', text: text, outgoing: outgoing))
          .called(1);

  group('outgoing', () {
    blocTest<CallBloc, CallState>(
      'opens media, creates the call, sends the offer and rings the callee',
      build: build,
      act: (b) => b.add(CallStarted(bob)),
      expect: () => [
        isA<CallState>()
            .having((s) => s.phase, 'phase', CallPhase.outgoing)
            .having((s) => s.isCaller, 'isCaller', true)
            .having((s) => s.peerName, 'peerName', 'Bob'),
        isA<CallState>().having((s) => s.localStream, 'local', local),
        isA<CallState>().having((s) => s.callId, 'callId', 'c1'),
      ],
      verify: (_) {
        verifyInOrder([
          () => webRtc.openMedia(),
          () => signaling.createCall(bob),
          () => webRtc.createPeer(),
          () => webRtc.createOffer(),
          () => signaling.setOffer('c1', offer),
          () => signaling.ring(calleeId: 'bob', callId: 'c1'),
          () => ringer.startRingback(),
        ]);
      },
    );

    blocTest<CallBloc, CallState>(
      'answer → connecting, peer connected → active',
      build: build,
      act: (b) async {
        b.add(CallStarted(bob));
        await Future<void>.delayed(Duration.zero);
        callDoc.add(doc(status: CallStatus.accepted, ans: answer));
        await Future<void>.delayed(Duration.zero);
        peerStates.add(PeerState.connected);
      },
      skip: 3,
      expect: () => [
        _phase(CallPhase.connecting),
        isA<CallState>()
            .having((s) => s.phase, 'phase', CallPhase.active)
            .having((s) => s.connectedAt, 'connectedAt', now),
      ],
      verify: (_) {
        verify(() => webRtc.acceptAnswer(answer)).called(1);
        verify(() => ringer.stop()).called(greaterThanOrEqualTo(1));
      },
    );

    blocTest<CallBloc, CallState>(
      'no answer within the ring timeout → missed, ring pointer removed, logged',
      build: () => build(ringTimeout: const Duration(milliseconds: 20)),
      act: (b) => b.add(CallStarted(bob)),
      wait: const Duration(milliseconds: 40),
      skip: 3,
      expect: () => [_ended(CallEndReason.noAnswer)],
      verify: (_) {
        verify(() => signaling.setStatus('c1', CallStatus.missed)).called(1);
        verify(() => signaling.cancelRing('bob')).called(1);
        verify(() => webRtc.close()).called(greaterThanOrEqualTo(1));
        verifyLog('No answer', outgoing: true);
      },
    );

    blocTest<CallBloc, CallState>(
      'callee declines → declinedByPeer',
      build: build,
      act: (b) async {
        b.add(CallStarted(bob));
        await Future<void>.delayed(Duration.zero);
        callDoc.add(doc(status: CallStatus.rejected));
      },
      skip: 3,
      expect: () => [_ended(CallEndReason.declinedByPeer)],
      verify: (_) => verifyLog('Call declined', outgoing: true),
    );

    blocTest<CallBloc, CallState>(
      'callee busy → busy',
      build: build,
      act: (b) async {
        b.add(CallStarted(bob));
        await Future<void>.delayed(Duration.zero);
        callDoc.add(doc(status: CallStatus.busy));
      },
      skip: 3,
      expect: () => [_ended(CallEndReason.busy)],
    );

    blocTest<CallBloc, CallState>(
      'caller cancels while ringing',
      build: build,
      act: (b) async {
        b.add(CallStarted(bob));
        await Future<void>.delayed(Duration.zero);
        b.add(const CallHungUp());
      },
      skip: 3,
      expect: () => [_ended(CallEndReason.cancelled)],
      verify: (_) {
        verify(() => signaling.cancelRing('bob')).called(1);
        verify(() => signaling.setStatus('c1', CallStatus.cancelled)).called(1);
        verifyLog('Cancelled call', outgoing: true);
      },
    );

    blocTest<CallBloc, CallState>(
      'camera/mic denied → mediaDenied and no call is created',
      setUp: () => when(() => webRtc.openMedia()).thenThrow(const MediaAccessFailure('denied')),
      build: build,
      act: (b) => b.add(CallStarted(bob)),
      expect: () => [_phase(CallPhase.outgoing), _ended(CallEndReason.mediaDenied)],
      verify: (_) {
        verifyNever(() => signaling.createCall(any()));
        verifyNever(
          () => chat.addCallLog(
            callId: any(named: 'callId'),
            peerId: any(named: 'peerId'),
            text: any(named: 'text'),
            outgoing: any(named: 'outgoing'),
          ),
        );
      },
    );

    blocTest<CallBloc, CallState>(
      'resets to idle after the ended screen',
      build: build,
      act: (b) async {
        b.add(CallStarted(bob));
        await Future<void>.delayed(Duration.zero);
        b.add(const CallHungUp());
      },
      wait: const Duration(milliseconds: 100),
      skip: 4,
      expect: () => [const CallState()],
    );
  });

  group('incoming', () {
    final ring = IncomingCall(callId: 'c1', callerId: 'bob', callerName: 'Bob', createdAt: now);

    blocTest<CallBloc, CallState>(
      'rings when idle',
      build: build,
      act: (b) async {
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(ring);
      },
      expect: () => [
        isA<CallState>()
            .having((s) => s.phase, 'phase', CallPhase.incoming)
            .having((s) => s.isCaller, 'isCaller', false)
            .having((s) => s.peerName, 'peerName', 'Bob'),
      ],
      verify: (_) => verify(() => ringer.startIncoming(callId: 'c1', callerName: 'Bob')).called(1),
    );

    blocTest<CallBloc, CallState>(
      'accept answers the offer',
      build: build,
      act: (b) async {
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(ring);
        await Future<void>.delayed(Duration.zero);
        b.add(const CallAccepted());
      },
      skip: 1,
      expect: () => [
        _phase(CallPhase.connecting),
        isA<CallState>().having((s) => s.localStream, 'local', local),
      ],
      verify: (_) {
        verify(() => signaling.clearIncoming()).called(1);
        verify(() => webRtc.createAnswer(offer)).called(1);
        verify(() => signaling.setAnswer('c1', answer)).called(1);
      },
    );

    blocTest<CallBloc, CallState>(
      'decline rejects and logs',
      build: build,
      act: (b) async {
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(ring);
        await Future<void>.delayed(Duration.zero);
        b.add(const CallDeclined());
      },
      skip: 1,
      expect: () => [_ended(CallEndReason.declined)],
      verify: (_) {
        verify(() => signaling.setStatus('c1', CallStatus.rejected)).called(1);
        verifyLog('Declined call', outgoing: false);
      },
    );

    blocTest<CallBloc, CallState>(
      'caller gives up while ringing → missed',
      build: build,
      act: (b) async {
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(ring);
        await Future<void>.delayed(Duration.zero);
        callDoc.add(doc(status: CallStatus.cancelled));
      },
      skip: 1,
      expect: () => [_ended(CallEndReason.missed)],
      verify: (_) => verifyLog('Missed video call', outgoing: false),
    );

    blocTest<CallBloc, CallState>(
      'a second call while busy gets a busy reply and does not interrupt',
      build: build,
      act: (b) async {
        b.add(CallStarted(bob));
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(
          IncomingCall(callId: 'c2', callerId: 'carol', callerName: 'Carol', createdAt: now),
        );
      },
      skip: 3,
      expect: () => <Matcher>[],
      verify: (b) {
        expect(b.state.phase, CallPhase.outgoing);
        verify(() => signaling.setStatus('c2', CallStatus.busy)).called(1);
      },
    );

    blocTest<CallBloc, CallState>(
      'a stale ring pointer is cleared and logged as missed, without ringing',
      build: build,
      act: (b) async {
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(
          IncomingCall(
            callId: 'c1',
            callerId: 'bob',
            callerName: 'Bob',
            createdAt: now.subtract(const Duration(minutes: 5)),
          ),
        );
      },
      expect: () => <Matcher>[],
      verify: (_) {
        verify(() => signaling.clearIncoming()).called(1);
        verifyNever(
          () => ringer.startIncoming(
            callId: any(named: 'callId'),
            callerName: any(named: 'callerName'),
          ),
        );
        verifyLog('Missed video call', outgoing: false);
      },
    );

    blocTest<CallBloc, CallState>(
      'remote hang-up during an active call logs the duration',
      build: build,
      act: (b) async {
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(ring);
        await Future<void>.delayed(Duration.zero);
        b.add(const CallAccepted());
        await Future<void>.delayed(Duration.zero);
        peerStates.add(PeerState.connected);
        await Future<void>.delayed(Duration.zero);
        callDoc.add(doc(status: CallStatus.ended));
      },
      skip: 4,
      expect: () => [_ended(CallEndReason.remoteHungUp)],
      verify: (_) => verifyLog('Incoming video call · 0:00', outgoing: false),
    );
  });

  group('system call UI (CallKit / Android)', () {
    final ring = IncomingCall(callId: 'c1', callerId: 'bob', callerName: 'Bob', createdAt: now);

    blocTest<CallBloc, CallState>(
      'accept from the system UI answers the call',
      build: build,
      act: (b) async {
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(ring);
        await Future<void>.delayed(Duration.zero);
        ringerActions.add(RingerAction.accepted);
      },
      skip: 1,
      expect: () => [
        _phase(CallPhase.connecting),
        isA<CallState>().having((s) => s.localStream, 'local', local),
      ],
      verify: (_) => verify(() => signaling.setAnswer('c1', answer)).called(1),
    );

    blocTest<CallBloc, CallState>(
      'decline from the system UI rejects the call',
      build: build,
      act: (b) async {
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(ring);
        await Future<void>.delayed(Duration.zero);
        ringerActions.add(RingerAction.declined);
      },
      skip: 1,
      expect: () => [_ended(CallEndReason.declined)],
      verify: (_) => verify(() => signaling.setStatus('c1', CallStatus.rejected)).called(1),
    );

    blocTest<CallBloc, CallState>(
      'ending from the system UI mid-call hangs up and tells the ringer when connected',
      build: build,
      act: (b) async {
        b.add(const CallSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        incoming.add(ring);
        await Future<void>.delayed(Duration.zero);
        ringerActions.add(RingerAction.accepted);
        await Future<void>.delayed(Duration.zero);
        peerStates.add(PeerState.connected);
        await Future<void>.delayed(Duration.zero);
        ringerActions.add(RingerAction.ended);
      },
      skip: 4,
      expect: () => [_ended(CallEndReason.hungUp)],
      verify: (_) {
        verify(() => ringer.connected()).called(1);
        verify(() => signaling.setStatus('c1', CallStatus.ended)).called(1);
        verify(() => ringer.ended()).called(1);
      },
    );
  });

  test('formatCallDuration', () {
    expect(formatCallDuration(const Duration(seconds: 7)), '0:07');
    expect(formatCallDuration(const Duration(minutes: 3, seconds: 12)), '3:12');
    expect(formatCallDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });
}
