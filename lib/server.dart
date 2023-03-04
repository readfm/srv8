import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';

class FServer {
  static const path = '../';
  final uploadDir = join(path, 'uploads');

  listen() async {
    var server = await HttpServer.bind(
      '0.0.0.0',
      port,
    );

    print('Listening on ${server.address.host}:${server.port}');

    server.listen((HttpRequest req) async {
      print(
        'Request ${req.uri.path} by ${req.headers['X-Forwarded-For']}',
      );

      if (req.uri.path.startsWith('/uploads/')) {
        final hash = basename(req.uri.path);

        final f = File('$uploadDir/$hash');

        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          //final mimeType = lookupMimeType(hash);
          req.response
            //..headers.contentType = ContentType.parse(mimeType!)
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
        return;
      }

      // responds with files parent directory
      final host = req.headers['host']!.first.split(':')[0];
      final f = File(
        '$path/sites/${host}/' + req.uri.path.replaceAll('..', ''),
      );

      final stat = f.statSync();
      if (f.existsSync() && stat.type == FileSystemEntityType.file) {
        final bytes = f.readAsBytesSync();
        final mimeType = lookupMimeType(f.path);
        req.response
          ..headers.contentType = ContentType.parse(mimeType!)
          ..add(bytes)
          ..close();
      } else {
        final fIndex = File(
          '$path/sites/${host}/index.html',
        );
        req.response
          ..headers.contentType = ContentType.html
          //..statusCode = HttpStatus.notFound
          ..write(fIndex.readAsStringSync())
          ..close();
      }

      /*
      if (req.uri.path.startsWith('/')) {
        final connection = await WebSocketTransformer.upgrade(req);
        final socket = FSocket();

        final name = getRandomString(5);

        sockets[name] = socket;

        distributor(Map<String, dynamic> msg) {
          for (final s in sockets.entries) {
            if (s.key == name) continue;
            s.value.sink(msg);
          }
        }

        // send messages to the client
        socket.stream.listen((d) {
          if (connection.readyState == WebSocket.open) {
            if (d is Map<String, dynamic>) {
              final r = connection.add(jsonEncode(d));
            }
          } else {
            // Remove socket if the connection is already closed
            sockets.remove(name);
          }
        });

        // receive messages from the client
        connection.listen((d) async {
          print('received: $d');
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
        }, onDone: () {
          socket.active = false;
          sockets.remove(name);
          //Communication.catalog.unListen(distributor);
          connection.close();

          print(
            'Disconnected ${connection.closeCode}#${connection.closeReason}',
          );
        });

        //socket.ready(this);
        // distribute messages to the sockets
        //Communication.catalog.doListen(distributor);
      }
      */
    });
  }

  static const local = '127.0.0.1';
  static const lPort = 8800;

  var host = local;
  var port = lPort;

  FServer({this.host = local, this.port = lPort}) {
    listen();
  }

  //final Map<String, FSocket> sockets = {};

  distribute(msg) {}

  @override
  handle(socket) {
    print('server');
    socket.sink(
        //Acc.requestSession(),
        );
  }
}
