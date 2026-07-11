import 'dart:async';

import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../models/message_model.dart';

/// Remote datasource for chat message operations using Appwrite.
class ChatRemoteDatasource {
  final Databases databases;
  final Realtime realtime;

  ChatRemoteDatasource(this.databases, this.realtime);

  String get _db => AppwriteConfig.databaseId;
  String get _col => AppwriteConfig.collectionMessages;

  Future<List<MessageModel>> getMessagesByTrip(String tripId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('trip_id', tripId),
          Query.orderAsc(r'$createdAt'),
          Query.limit(100),
        ],
      );
      return response.documents
          .map((d) => MessageModel.fromJson(normalizeDocument(d)))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<MessageModel> sendMessage(
    String tripId,
    String senderId,
    String content,
  ) async {
    try {
      final doc = await databases.createDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: ID.unique(),
        data: {
          'trip_id': tripId,
          'sender_id': senderId,
          'content': content,
          'is_system': false,
        },
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.user(senderId)),
          Permission.delete(Role.any()),
        ],
      );
      return MessageModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<MessageModel> sendSystemMessage(String tripId, String content) async {
    try {
      final doc = await databases.createDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: ID.unique(),
        data: {
          'trip_id': tripId,
          'sender_id': 'system',
          'content': content,
          'is_system': true,
        },
        permissions: [
          Permission.read(Role.any()),
          Permission.delete(Role.any()),
        ],
      );
      return MessageModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Deletes all messages for a trip (best-effort).
  Future<int> deleteMessagesForTrip(String tripId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('trip_id', tripId),
          Query.limit(100),
        ],
      );
      var deleted = 0;
      for (final doc in response.documents) {
        try {
          await databases.deleteDocument(
            databaseId: _db,
            collectionId: _col,
            documentId: doc.$id,
          );
          deleted++;
        } catch (_) {}
      }
      return deleted;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Realtime subscription on messages collection, filtered by [tripId].
  /// Falls back to polling every 2 seconds if realtime is unavailable.
  Stream<List<MessageModel>> messagesStream(String tripId) {
    final controller = StreamController<List<MessageModel>>();
    Timer? pollTimer;
    RealtimeSubscription? subscription;

    Future<void> emit() async {
      if (controller.isClosed) return;
      try {
        final messages = await getMessagesByTrip(tripId);
        if (!controller.isClosed) controller.add(messages);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    void startPolling() {
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => emit());
    }

    controller.onListen = () {
      emit();
      try {
        final channel = 'databases.$_db.collections.$_col.documents';
        subscription = realtime.subscribe([channel]);
        subscription!.stream.listen((event) {
          final payloadTripId = event.payload['trip_id'];
          if (payloadTripId == null || payloadTripId == tripId) {
            emit();
          }
        }, onError: (_) => startPolling());
        // Safety poll in case some events are missed.
        startPolling();
      } catch (_) {
        startPolling();
      }
    };

    controller.onCancel = () async {
      pollTimer?.cancel();
      await subscription?.close();
    };

    return controller.stream;
  }
}
