library speech_to_text_aliyun;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';

enum MODEL_TYPE { DEFAULT }
const int CHUNK_SIZE = 3200;

class SpeechToText {
  static const String wsURL =
      "wss://nls-gateway.cn-shanghai.aliyuncs.com/ws/v1";
  IOWebSocketChannel channel;
  String token;
  String appKey;
  SpeechToText.initWithFetchedToken({Map fetchedToken}) {
    this.token = fetchedToken["token"];
    this.appKey = fetchedToken["appKey"];
  }
  Stream<Map> convert(Stream<List<int>> audioStream,
      {int sampleRate = 16000,
      String langCode = 'zh-CN',
      MODEL_TYPE modelType = MODEL_TYPE.DEFAULT,
      useEnhanced = false}) {
    var controller = StreamController<Map>();
    channel =
        IOWebSocketChannel.connect(wsURL, headers: {"X-NLS-Token": token});

    channel.stream.listen((_resp) {
      print(_resp);
      var resp = jsonDecode(_resp);
      Map header = resp["header"];
      Map payload = resp["payload"];
      if (header["status"] == 20000000 &&
          payload != null &&
          payload["result"] != null) {
        controller.add({
          "transcript": payload["result"],
          "isFinal": header["name"] == "SentenceEnd"
        });
      }
    }, onDone: () {
      controller.close();
    });
    channel.sink.add(getStartPayload(sampleRate: sampleRate));
    // patchStream(audioStream, CHUNK_SIZE).listen((audio) {
    audioStream.listen((audio) {
      channel.sink.add(audio);
    });
    return controller.stream;
  }

  Stream<List<int>> patchStream(
      Stream<List<int>> inputStream, int chunkSize) async* {
    List<int> temp = [];
    await for (var chunk in inputStream) {
      temp.addAll(chunk);
      while (true) {
        if (temp.length < chunkSize) {
          break;
        }
        List<int> outputChunk = temp.getRange(0, chunkSize).toList();
        temp.removeRange(0, chunkSize);
        yield outputChunk;
      }
    }
  }

  String _getUUIDhex() {
    return Uuid().v4().replaceAll("-", "");
  }

  String getStartPayload({int sampleRate = 16000}) {
    Map payload = {
      "header": {
        "appkey": this.appKey,
        "namespace": "SpeechTranscriber",
        "name": "StartTranscription",
        "task_id": _getUUIDhex(),
        "message_id": _getUUIDhex()
      },
      "payload": {
        "enable_punctuation_prediction": true,
        "sample_rate": sampleRate,
        "enable_intermediate_result": true
      }
    };
    return jsonEncode(payload);
  }
}
