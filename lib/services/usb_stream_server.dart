import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class UsbStreamItem {
  final String releaseId;
  final String filePath;
  final String title;

  const UsbStreamItem({
    required this.releaseId,
    required this.filePath,
    required this.title,
  });

  String get displayFileName {
    final dot = filePath.lastIndexOf('.');
    final ext = dot == -1 ? 'mkv' : filePath.substring(dot + 1);
    final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
    return '$safe.$ext';
  }

  String get url =>
      'http://127.0.0.1:${UsbStreamServer.port}/${Uri.encodeComponent(displayFileName)}';
}

/// Serves each episode as its own URL and loads the show into VLC as a playlist.
class UsbStreamServer {
  static const int port = 8765;
  static const int vlcControlPort = 8766;
  static const String vlcPassword = 'anime';
  static const String playlistUrl = 'http://127.0.0.1:$port/playlist.m3u';
  static const String pcCommand =
      'adb forward tcp:$port tcp:$port && '
      'adb reverse tcp:$vlcControlPort tcp:$vlcControlPort && '
      'vlc --extraintf http --http-password $vlcPassword '
      '--http-host 127.0.0.1 --http-port $vlcControlPort --loop $playlistUrl';

  final ValueNotifier<int> clientCount = ValueNotifier<int>(0);
  final ValueNotifier<String?> playingReleaseId = ValueNotifier<String?>(null);

  HttpServer? _server;
  final Map<String, UsbStreamItem> _items = {};
  final Map<String, String> _vlcItemIds = {};
  String? _currentReleaseId;
  final Set<HttpResponse> _clients = <HttpResponse>{};
  Future<void> _switchQueue = Future<void>.value();
  Timer? _vlcPollTimer;
  Timer? _vlcPushTimer;
  bool _ignoreVlcPoll = false;

  bool get isRunning => _server != null;

  String? filePathFor(String releaseId) => _items[releaseId]?.filePath;

  UsbStreamItem? _itemForUri(Uri? uri) {
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final name = Uri.decodeComponent(uri.pathSegments.last);
    for (final item in _items.values) {
      if (item.displayFileName == name) return item;
    }
    return null;
  }

  Future<void> start({
    required List<UsbStreamItem> items,
    required String currentReleaseId,
  }) async {
    if (items.isEmpty) {
      throw StateError('No episodes to stream');
    }

    _items
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.releaseId, item)));
    _currentReleaseId = _items.containsKey(currentReleaseId)
        ? currentReleaseId
        : items.first.releaseId;
    playingReleaseId.value = _currentReleaseId;

    if (_server == null) {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server!.listen(_handleRequest, onError: (_) {});
    }

    _startVlcSync();
  }

  Future<void> playRelease(String releaseId) {
    _switchQueue = _switchQueue.then((_) => _playReleaseNow(releaseId));
    return _switchQueue;
  }

  Future<void> _playReleaseNow(String releaseId) async {
    if (!_items.containsKey(releaseId)) return;
    _currentReleaseId = releaseId;
    _ignoreVlcPoll = true;
    playingReleaseId.value = releaseId;
    await _dropClients();
    if (_vlcItemIds.isEmpty) {
      await _ensureVlcPlaylist();
    }
    await _vlcPlayRelease(releaseId);
    _ignoreVlcPoll = false;
  }

  Future<void> stop() async {
    _vlcPollTimer?.cancel();
    _vlcPollTimer = null;
    _vlcPushTimer?.cancel();
    _vlcPushTimer = null;
    await _tellVlcStop();
    await _dropClients();
    _items.clear();
    _vlcItemIds.clear();
    _currentReleaseId = null;
    playingReleaseId.value = null;
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  void _startVlcSync() {
    _vlcPushTimer?.cancel();
    var attempts = 0;
    _vlcPushTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      attempts++;
      final ok = await _ensureVlcPlaylist();
      if (ok) {
        final current = _currentReleaseId;
        if (current != null) {
          await _vlcPlayRelease(current);
        }
        timer.cancel();
        _vlcPushTimer = null;
      } else if (attempts >= 20) {
        timer.cancel();
        _vlcPushTimer = null;
      }
    });

    _vlcPollTimer?.cancel();
    _vlcPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollVlcCurrent());
    });
  }

  Future<void> _dropClients() async {
    final clients = List<HttpResponse>.from(_clients);
    _clients.clear();
    _syncClientCount();
    for (final response in clients) {
      try {
        final socket = await response.detachSocket();
        socket.destroy();
      } catch (_) {
        try {
          await response.close();
        } catch (_) {}
      }
    }
  }

  void _trackClient(HttpResponse response) {
    _clients.add(response);
    _syncClientCount();
    response.done.whenComplete(() {
      if (_clients.remove(response)) {
        _syncClientCount();
      }
    });
  }

  void _syncClientCount() {
    if (clientCount.value != _clients.length) {
      clientCount.value = _clients.length;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.persistentConnection = false;

    try {
      final method = request.method;
      if (method != 'GET' && method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        await response.close();
        return;
      }

      final path = request.uri.path;
      if (path == '/' || path == '/index.html') {
        await _writeLanding(response, method);
        return;
      }

      if (path == '/playlist.m3u') {
        await _writePlaylist(response, method);
        return;
      }

      final item = _itemForUri(request.uri);
      if (item == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }

      _trackClient(response);
      await _writeFile(request, response, method, item);
    } catch (_) {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _writeLanding(HttpResponse response, String method) async {
    const body =
        '<!doctype html><html><body style="font-family:sans-serif;background:#111;color:#eee">'
        '<p>Open this in VLC:</p>'
        '<p><a href="/playlist.m3u" style="color:#8B5CF6">$playlistUrl</a></p>'
        '</body></html>';
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.html;
    response.contentLength = body.length;
    if (method != 'HEAD') {
      response.write(body);
    }
    await response.close();
  }

  Future<void> _writePlaylist(HttpResponse response, String method) async {
    final buffer = StringBuffer('#EXTM3U\n');
    for (final item in _items.values) {
      buffer.writeln('#EXTINF:-1,${item.title}');
      buffer.writeln('#EXTVLCOPT:meta-title=${item.title}');
      buffer.writeln(item.url);
    }
    final body = buffer.toString();
    final bytes = utf8.encode(body);
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.contentTypeHeader, 'audio/x-mpegurl');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store');
    response.contentLength = bytes.length;
    if (method != 'HEAD') {
      response.add(bytes);
    }
    await response.close();
  }

  Future<void> _writeFile(
    HttpRequest request,
    HttpResponse response,
    String method,
    UsbStreamItem item,
  ) async {
    final file = File(item.filePath);
    if (!await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final length = await file.length();
    if (length <= 0) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final fileName = item.displayFileName;
    final encodedName = Uri.encodeComponent(fileName);

    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store');
    response.headers.set(HttpHeaders.contentTypeHeader, _mimeFor(fileName));
    response.headers.set(
      'content-disposition',
      'inline; filename="$fileName"; filename*=UTF-8\'\'$encodedName',
    );

    var start = 0;
    var end = length - 1;
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final spec = rangeHeader.substring(6).split(',').first.trim();
      final parts = spec.split('-');
      if (parts[0].isNotEmpty) {
        start = int.tryParse(parts[0]) ?? 0;
      }
      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = int.tryParse(parts[1]) ?? end;
      } else if (parts[0].isEmpty) {
        final suffix = int.tryParse(parts[1]) ?? 0;
        start = (length - suffix).clamp(0, length - 1);
        end = length - 1;
      }

      if (start >= length || start > end || end >= length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers
            .set(HttpHeaders.contentRangeHeader, 'bytes */$length');
        await response.close();
        return;
      }

      response.statusCode = HttpStatus.partialContent;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$length',
      );
    } else {
      response.statusCode = HttpStatus.ok;
    }

    final contentLength = end - start + 1;
    response.contentLength = contentLength;

    if (method == 'HEAD') {
      await response.close();
      return;
    }

    response.bufferOutput = false;
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      var remaining = contentLength;
      const chunkSize = 64 * 1024;
      while (remaining > 0) {
        final toRead = remaining < chunkSize ? remaining : chunkSize;
        final bytes = await raf.read(toRead);
        if (bytes.isEmpty) break;
        response.add(bytes);
        await response.flush();
        remaining -= bytes.length;
      }
    } finally {
      await raf.close();
    }

    await response.close();
  }

  Future<bool> _ensureVlcPlaylist() async {
    if (_items.isEmpty) return false;
    if (await _refreshVlcItemIds() && _vlcItemIds.length >= _items.length) {
      return true;
    }
    await _tellVlc('pl_empty', retries: 2);
    for (final item in _items.values) {
      final ok = await _tellVlc('in_enqueue', input: item.url, retries: 3);
      if (!ok) return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _refreshVlcItemIds();
  }

  Future<bool> _vlcPlayRelease(String releaseId) async {
    if (_vlcItemIds.isEmpty) {
      await _refreshVlcItemIds();
    }
    final id = _vlcItemIds[releaseId];
    if (id != null) {
      return _tellVlc('pl_play', id: id, retries: 4);
    }
    final item = _items[releaseId];
    if (item == null) return false;
    return _tellVlc('in_play', input: item.url, retries: 4);
  }

  Future<bool> _refreshVlcItemIds() async {
    final xml = await _vlcGet('/requests/playlist.xml');
    if (xml == null) return false;

    _vlcItemIds.clear();
    final leaves = RegExp(r'<leaf\s+([^>]+)/?>').allMatches(xml);
    for (final leaf in leaves) {
      final attrs = leaf.group(1)!;
      final id = RegExp(r'\bid="(\d+)"').firstMatch(attrs)?.group(1);
      final rawUri = RegExp(r'\buri="([^"]+)"').firstMatch(attrs)?.group(1);
      if (id == null || rawUri == null) continue;
      final uri = Uri.tryParse(_unescapeXml(rawUri));
      final item = _itemForUri(uri);
      if (item != null) {
        _vlcItemIds[item.releaseId] = id;
      }
    }
    return _vlcItemIds.isNotEmpty;
  }

  Future<void> _pollVlcCurrent() async {
    if (_ignoreVlcPoll || _server == null) return;
    final xml = await _vlcGet('/requests/playlist.xml');
    if (xml == null) return;

    final leaves = RegExp(r'<leaf\s+([^>]+)/?>').allMatches(xml);
    for (final leaf in leaves) {
      final attrs = leaf.group(1)!;
      if (!attrs.contains('current="current"')) continue;
      final rawUri = RegExp(r'\buri="([^"]+)"').firstMatch(attrs)?.group(1);
      if (rawUri == null) return;
      final uri = Uri.tryParse(_unescapeXml(rawUri));
      final item = _itemForUri(uri);
      if (item == null || item.releaseId == playingReleaseId.value) return;
      _currentReleaseId = item.releaseId;
      playingReleaseId.value = item.releaseId;
      return;
    }
  }

  Future<void> _tellVlcStop() async {
    await _tellVlc('pl_stop', retries: 3);
    await _tellVlc('pl_empty', retries: 2);
  }

  Future<bool> _tellVlc(
    String command, {
    String? input,
    String? id,
    int retries = 4,
  }) async {
    final params = <String, String>{'command': command};
    if (input != null) params['input'] = input;
    if (id != null) params['id'] = id;

    for (var attempt = 0; attempt < retries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final body = await _vlcGet(
        '/requests/status.xml',
        queryParameters: params,
      );
      if (body != null) return true;
    }
    return false;
  }

  Future<String?> _vlcGet(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    for (final user in ['', 'vlc']) {
      final body = await _vlcGetOnce(
        path,
        user: user,
        queryParameters: queryParameters,
      );
      if (body != null) return body;
    }
    return null;
  }

  Future<String?> _vlcGetOnce(
    String path, {
    required String user,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: vlcControlPort,
      path: path,
      queryParameters: queryParameters,
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 500)
      ..idleTimeout = const Duration(milliseconds: 800);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode('$user:$vlcPassword'))}',
      );
      final response = await request
          .close()
          .timeout(const Duration(milliseconds: 800));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) return null;
      return body;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String _unescapeXml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  static String _mimeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'mkv':
        return 'video/x-matroska';
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'ts':
        return 'video/mp2t';
      default:
        return 'application/octet-stream';
    }
  }
}
