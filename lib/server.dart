import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:data8/index.dart';
import 'package:data8/utils/random.dart';

class FServer {
  static const path = '../';
  final uploadDir = join(path, 'uploads');

  listen() async {
    var server = await HttpServer.bind(
      host,
      port,
    );

    print('Listening on ${server.address.host}:${server.port}');

    server.listen(
      (HttpRequest req) async {
        print(
          'Request ${req.uri.path} by ${req.connectionInfo?.remoteAddress ?? req.headers['X-Forwarded-For']}',
        );

        if (req.uri.path.startsWith('/uploads/')) {
          final hash = basename(req.uri.path);

          final f = File('$uploadDir/$hash');

          if (f.existsSync()) {
            final bytes = f.readAsBytesSync();
            final mimeType = 'application/octet-stream';
            //lookupMimeType(hash);
            req.response
              ..headers.contentType = ContentType.parse(mimeType)
              ..add(bytes)
              ..close();
          } else {
            req.response
              ..statusCode = HttpStatus.notFound
              ..write('File not found')
              ..close();
          }
          return;
        }

        if (req.uri.path.startsWith('/upload')) {
          try {
            upload(req);
          } catch (e) {
            print(e);
            req.response
              ..statusCode = HttpStatus.internalServerError
              ..write('Error')
              ..close();
          }
          return;
        }

        if (req.uri.path.startsWith('/')) {
          socket(req);
          //socket.ready(this);
          // distribute messages to the sockets
          //Communication.catalog.doListen(distributor);
        }
      },
      onError: (e) {
        print('Error: $e');
      },
      cancelOnError: false,
    );
  }

  upload(HttpRequest req) async {
    List<int> dataBytes = [];

    await for (var data in req) {
      dataBytes.addAll(data);
    }

    final boundary = req.headers.contentType!.parameters['boundary'];
    final transformer = MimeMultipartTransformer(boundary!);

    final bodyStream = Stream.fromIterable([dataBytes]);
    final parts = await transformer.bind(bodyStream).toList();
    dataBytes.clear();

    if (!Directory(uploadDir).existsSync()) {
      await Directory(uploadDir).create();
    }

    final bytes = <int>[];
    for (var part in parts) {
      final content = await part.toList();
      bytes.addAll(content[0]);
    }
    parts.clear();

    final hash = sha256.convert(bytes).toString();
    final fw = File('$uploadDir/$hash');
    fw.writeAsBytes(bytes);

    // Send a response to the client
    req.response
      ..statusCode = HttpStatus.ok
      ..write('File uploaded successfully')
      ..close();
  }

  socket(HttpRequest req) async {
    final name = getRandomString(5);
    final connection = await WebSocketTransformer.upgrade(req);
    final socket = FSocket(
      name: name,
      spread: spread,
    );

    sockets[name] = socket;

    // send messages to the client
    socket.stream.listen(
      (d) {
        if (connection.readyState == WebSocket.open) {
          if (d is Map<String, dynamic>) {
            final r = connection.add(jsonEncode(d));
          }
        } else {
          // Remove socket if the connection is already closed
          sockets.remove(name);
        }
      },
      onError: (e) {
        print('socket error: $e');
        sockets.remove(name);
      },
      cancelOnError: false,
    );

    // receive messages from the client
    connection.listen(
      (d) async {
        print('received: $d');
        try {
          final fractal = socket.receive(d);

          /*
          final to = fractal.fm[FractalSchema.to]?.value;
          if (to is String) {
            final path = FractalPath.fromString(to);
            path.word?.take(path.id).input(fractal);
          }
          */

          if (fractal is FractalSessionAbs && socket.session != null) {
            print('session');
            fractal.handle(socket.session!);
          }
        } catch (e) {
          print('ws error: $e');
        }
      },
      onDone: () {
        socket.active = false;
        sockets.remove(name);
        //Communication.catalog.unListen(distributor);
        connection.close();
        print(
          'Disconnected ${connection.closeCode}#${connection.closeReason}',
        );
      },
      onError: (e) {
        print('ws error: $e');
      },
    );
  }

  notFound(HttpRequest req) {
    req.response
      ..statusCode = HttpStatus.notFound
      ..write('File not found')
      ..close();
  }

  static const local = '127.0.0.1';
  static const lPort = 8800;

  var host = local;
  var port = lPort;

  FServer({this.host = local, this.port = lPort}) {
    listen();
  }

  final Map<String, FSocket> sockets = {};

  //final Map<String, FSocket> sockets = {};

  spread(
    Map<String, dynamic> msg, [
    List<String> exclude = const [],
  ]) {
    for (final s in sockets.entries) {
      if (exclude.contains(s.key)) continue;
      s.value.sink(msg);
    }
  }

  @override
  handle(socket) {
    print('server');
    socket.sink(
        //Acc.requestSession(),
        );
  }
}
