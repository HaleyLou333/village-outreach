import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('private messaging strings have English and Spanish translations', () {
    final en = AppStrings('en');
    final es = AppStrings('es');
    expect(en.conversationTitle, 'Private Conversation');
    expect(es.conversationTitle, 'Conversación privada');
    expect(en.refreshMessages, 'Refresh messages');
    expect(es.refreshMessages, 'Actualizar mensajes');
    expect(en.messagesLoadFailed, 'Unable to load messages. Please try again.');
    expect(
      es.messagesLoadFailed,
      'No se pudieron cargar los mensajes. Inténtalo de nuevo.',
    );
    expect(en.messagesMoreFailed, 'Unable to load more messages.');
    expect(es.messagesMoreFailed, 'No se pudieron cargar más mensajes.');
    expect(en.messagesAccessDenied, 'Access denied');
    expect(es.messagesAccessDenied, 'Acceso denegado');
    expect(
      en.messagesClosed,
      'This request is closed. Messages are read-only.',
    );
    expect(
      es.messagesClosed,
      'Esta solicitud está cerrada. Los mensajes son de solo lectura.',
    );
    expect(en.messagesLoading, 'Loading...');
    expect(es.messagesLoading, 'Cargando...');
    expect(en.messagesLoadMore, 'Load more messages');
    expect(es.messagesLoadMore, 'Cargar más mensajes');
    expect(en.messagesEmpty, 'No messages yet.');
    expect(es.messagesEmpty, 'Aún no hay mensajes.');
    expect(en.messagesWrite, 'Write a message');
    expect(es.messagesWrite, 'Escribe un mensaje');
    expect(en.messagesSend, 'Send message');
    expect(es.messagesSend, 'Enviar mensaje');
    expect(en.messagesSending, 'Sending...');
    expect(es.messagesSending, 'Enviando...');
    expect(en.messagesFailed, 'Failed');
    expect(es.messagesFailed, 'Fallido');
    expect(en.messagesSent, 'Sent');
    expect(es.messagesSent, 'Enviado');
    expect(en.messagesRetry, 'Retry');
    expect(es.messagesRetry, 'Reintentar');
  });
}
