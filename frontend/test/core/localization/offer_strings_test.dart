import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('offer interface strings are localized', () {
    final en = AppStrings('en');
    final es = AppStrings('es');
    expect(en.incomingOffers, 'Incoming Offers');
    expect(es.incomingOffers, 'Ofertas recibidas');
    expect(en.submitOffer, 'Submit Offer');
    expect(es.submitOffer, 'Enviar oferta');
    expect(en.offerStatus(en.offerPending), 'Status: Pending');
    expect(es.offerStatus(es.offerPending), 'Estado: Pendiente');
    expect(en.acceptOffer, 'Accept Offer');
    expect(es.acceptOffer, 'Aceptar oferta');
    expect(en.offerNumber(2), 'Offer 2');
    expect(es.offerNumber(2), 'Oferta 2');
  });
}
