import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/offers/models/help_offer.dart';
import 'package:village_outreach/features/offers/screens/request_offers_screen.dart';
import 'package:village_outreach/features/offers/services/offer_service.dart';

const requestId = 'request-1';
const ownerId = 'owner-1';
const helperA = 'helper-a';
const helperB = 'helper-b';

void main() {
  late MockOfferRepository repository;

  setUp(() {
    repository = MockOfferRepository();
  });

  Future<HelpOffer> createOffer(
    String helperId, {
    String message = 'I can help with this request.',
  }) {
    return repository.submitOffer(
      requestId: requestId,
      requestOwnerId: ownerId,
      helperId: helperId,
      message: message,
    );
  }

  Widget buildScreen(String currentUserId) {
    return MaterialApp(
      home: RequestOffersScreen(
        requestId: requestId,
        requestOwnerId: ownerId,
        currentUserId: currentUserId,
        repository: repository,
      ),
    );
  }

  group('Offer repository', () {
    test('helper submits one pending offer', () async {
      final offer = await createOffer(helperA);

      expect(offer.status, OfferStatus.pending);

      final saved = await repository.getMyOffer(
        requestId: requestId,
        helperId: helperA,
      );

      expect(saved?.id, offer.id);
    });

    test('self-offer is rejected', () async {
      await expectLater(createOffer(ownerId), throwsA(isA<OfferException>()));
    });

    test('duplicate offer is rejected', () async {
      await createOffer(helperA);

      await expectLater(createOffer(helperA), throwsA(isA<OfferException>()));
    });

    test('nonowner cannot review offers', () async {
      await createOffer(helperA);

      await expectLater(
        repository.getRequestOffers(
          requestId: requestId,
          requesterId: helperB,
          requestOwnerId: ownerId,
        ),
        throwsA(isA<OfferException>()),
      );
    });

    test('nonowner cannot accept an offer', () async {
      final offer = await createOffer(helperA);

      await expectLater(
        repository.acceptOffer(
          requestId: requestId,
          offerId: offer.id,
          requesterId: helperB,
          requestOwnerId: ownerId,
        ),
        throwsA(isA<OfferException>()),
      );
    });

    test('acceptance declines other pending offers', () async {
      final first = await createOffer(helperA);
      await createOffer(helperB);

      final accepted = await repository.acceptOffer(
        requestId: requestId,
        offerId: first.id,
        requesterId: ownerId,
        requestOwnerId: ownerId,
      );

      expect(accepted.status, OfferStatus.accepted);

      final offers = await repository.getRequestOffers(
        requestId: requestId,
        requesterId: ownerId,
        requestOwnerId: ownerId,
      );

      expect(
        offers.where((offer) => offer.status == OfferStatus.accepted).length,
        1,
      );

      expect(
        offers.where((offer) => offer.status == OfferStatus.declined).length,
        1,
      );
    });

    test('stale acceptance is rejected', () async {
      final first = await createOffer(helperA);
      final second = await createOffer(helperB);

      await repository.acceptOffer(
        requestId: requestId,
        offerId: first.id,
        requesterId: ownerId,
        requestOwnerId: ownerId,
      );

      await expectLater(
        repository.acceptOffer(
          requestId: requestId,
          offerId: second.id,
          requesterId: ownerId,
          requestOwnerId: ownerId,
        ),
        throwsA(isA<OfferException>()),
      );
    });
  });

  group('Offer screens', () {
    testWidgets('helper can submit an offer', (tester) async {
      await tester.pumpWidget(buildScreen(helperA));
      await tester.pumpAndSettle();

      expect(find.text('Submit Offer'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('offer-message')),
        'I can help tomorrow morning.',
      );

      await tester.tap(find.byKey(const Key('submit-offer')));
      await tester.pumpAndSettle();

      expect(find.text('Status: Pending'), findsOneWidget);
      expect(find.text('I can help tomorrow morning.'), findsOneWidget);
      expect(find.text('Submit Offer'), findsNothing);
    });

    testWidgets('owner sees offers and acceptance control', (tester) async {
      await createOffer(helperA);

      await tester.pumpWidget(buildScreen(ownerId));
      await tester.pumpAndSettle();

      expect(find.text('Incoming Offers'), findsWidgets);
      expect(find.text('Accept Offer'), findsOneWidget);
      expect(find.text('Submit Offer'), findsNothing);
    });

    testWidgets('nonowner cannot see acceptance control', (tester) async {
      await createOffer(helperA);

      await tester.pumpWidget(buildScreen(helperB));
      await tester.pumpAndSettle();

      expect(find.text('Accept Offer'), findsNothing);
      expect(find.text('Submit Offer'), findsOneWidget);
    });

    testWidgets('owner accepts offer and status refreshes', (tester) async {
      await createOffer(helperA);

      await tester.pumpWidget(buildScreen(ownerId));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept Offer'));
      await tester.pumpAndSettle();

      expect(find.text('Status: Accepted'), findsOneWidget);
      expect(find.text('Accept Offer'), findsNothing);
    });
  });
}
