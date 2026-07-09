import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../constants/app_constants.dart';
import '../models/watch_party_models.dart';
import 'auth_service.dart';
import 'auth_storage.dart';
import 'watch_party_logger.dart';

class WatchPartySocketService {
  StompClient? _client;
  final StreamController<SyncAction> _actionsController =
      StreamController<SyncAction>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  String? _partyId;
  bool _connected = false;

  Stream<SyncAction> get actions => _actionsController.stream;
  Stream<bool> get connectionChanges => _connectionController.stream;
  bool get isConnected => _connected;
  String? get partyId => _partyId;

  Future<void> connect(String partyId) async {
    if (_partyId == partyId && _connected) {
      return;
    }

    await disconnect();

    await AuthService.ensureFreshAccessToken();

    final token =
        AuthService.accessToken ?? await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please log in to join a watch party');
    }

    _partyId = partyId;
    final wsBase = _toWebSocketUrl(AppConstants.watchPartyWsUrl);
    final url =
        '$wsBase?token=${Uri.encodeQueryComponent(token)}&partyId=${Uri.encodeQueryComponent(partyId)}';

    if (kDebugMode) {
      WatchPartyLogger.info('connecting to $wsBase for party $partyId');
    }

    final completer = Completer<void>();
    StompClient? client;

    client = StompClient(
      config: StompConfig(
        url: url,
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        stompConnectHeaders: {'partyId': partyId},
        onDebugMessage: (msg) {
          if (kDebugMode) {
            WatchPartyLogger.info('stomp: $msg');
          }
        },
        onConnect: (frame) {
          _connected = true;
          _connectionController.add(true);

          client?.subscribe(
            destination: '/topic/party/$partyId',
            callback: (frame) {
              final body = frame.body;
              if (body == null || body.isEmpty) return;
              try {
                final decoded = jsonDecode(body);
                if (decoded is Map) {
                  final action = SyncAction.fromJson(
                    Map<String, dynamic>.from(decoded),
                  );
                  if (kDebugMode) {
                    WatchPartyLogger.info(
                      'received ${action.action.apiValue} videoUrl=${action.videoUrl} '
                      'from=${action.senderUsername}',
                    );
                  }
                  _actionsController.add(action);
                }
              } catch (e) {
                WatchPartyLogger.warn('failed to parse sync action: $e body=$body');
              }
            },
          );

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onDisconnect: (frame) {
          _connected = false;
          _connectionController.add(false);
        },
        onWebSocketError: (dynamic error) {
          WatchPartyLogger.warn('WebSocket error: $error');
          client?.deactivate();
          if (!completer.isCompleted) {
            completer.completeError(error ?? Exception('WebSocket error'));
          }
        },
        onStompError: (frame) {
          final message = frame.headers['message'] ??
              frame.headers['MESSAGE'] ??
              frame.body ??
              'STOMP connection failed';
          WatchPartyLogger.warn('STOMP error: $message headers=${frame.headers}');
          client?.deactivate();
          if (!completer.isCompleted) {
            completer.completeError(Exception(message.toString()));
          }
        },
        reconnectDelay: Duration.zero,
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
      ),
    );

    _client = client;
    client.activate();

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        client?.deactivate();
        throw Exception('Timed out connecting to watch party');
      },
    );
  }

  bool sendSync(SyncAction action) {
    final partyId = _partyId;
    final client = _client;
    if (partyId == null || client == null || !_connected) {
      WatchPartyLogger.warn(
        'sendSync dropped ${action.action.apiValue}: partyId=$partyId '
        'connected=$_connected client=${client != null}',
      );
      return false;
    }

    client.send(
      destination: '/app/party/$partyId/sync',
      body: jsonEncode(action.toJson()),
    );
    WatchPartyLogger.info(
      'sent ${action.action.apiValue} to /app/party/$partyId connected=$_connected',
    );
    return true;
  }

  Future<void> disconnect() async {
    _connected = false;
    _connectionController.add(false);
    _partyId = null;

    final client = _client;
    _client = null;
    if (client != null) {
      client.deactivate();
    }
  }

  void dispose() {
    disconnect();
    _actionsController.close();
    _connectionController.close();
  }

  String _toWebSocketUrl(String url) {
    final uri = Uri.parse(url);
    final scheme = switch (uri.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      'wss' || 'ws' => uri.scheme,
      _ => throw ArgumentError('Unsupported WebSocket URL scheme: ${uri.scheme}'),
    };
    return uri.replace(scheme: scheme).toString();
  }
}
