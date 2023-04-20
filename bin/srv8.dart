import 'dart:ffi';
import 'package:data8/index.dart';
import 'package:srv8/server.dart';
import 'package:srv8/srv8.dart' as srv8;

void main(List<String> arguments) {
  FData.path = '../data/';
  FServer();
}
