import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, sleep;
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:nfcreader/emoneyUtils.dart';
import 'package:string_to_hex/string_to_hex.dart';

import 'record-setting/raw_record_setting.dart';
import 'record-setting/text_record_setting.dart';
import 'record-setting/uri_record_setting.dart';

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(MaterialApp(theme: ThemeData(useMaterial3: true), home: Sensors()));
}

class Sensors extends StatefulWidget {
  const Sensors({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<Sensors> with SingleTickerProviderStateMixin {
  String _platformVersion = '';
  NFCAvailability _availability = NFCAvailability.not_supported;
  NFCTag? _tag;
  String? _result, _writeResult;
  late TabController _tabController;
  List<ndef.NDEFRecord>? _records;
  late EmoneyUtils em;
  IsoDep? tag2;
  ValueNotifier<dynamic> result = ValueNotifier(null);

  get cardTag => null;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb)
      _platformVersion =
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    else
      _platformVersion = 'Web';
    initPlatformState();
    _tabController = TabController(length: 2, vsync: this);
    _records = [];
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    NFCAvailability availability;
    try {
      availability = await FlutterNfcKit.nfcAvailability;
    } on PlatformException {
      availability = NFCAvailability.not_supported;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      // _platformVersion = platformVersion;
      _availability = availability;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
            title: const Text('NFC Flutter Kit Example App'),
            bottom: TabBar(
              tabs: <Widget>[
                const Tab(text: 'Read'),
                const Tab(text: 'Write'),
              ],
              controller: _tabController,
            )),
        body: TabBarView(controller: _tabController, children: <Widget>[
          Scrollbar(
              child: SingleChildScrollView(
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                const SizedBox(height: 20),
                Text('Running on: $_platformVersion\nNFC: $_availability'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      NFCTag tag = await FlutterNfcKit.poll();

                      setState(() {
                        _tag = tag;
                      });
                      await FlutterNfcKit.setIosAlertMessage(
                          "Working on it...");
                          //start edit
                      if (tag.standard == "ISO 14443-4 (Type A)") {
                        String result1 =
                            await FlutterNfcKit.transceive('00B300003F');
                        String result2 =
                            await FlutterNfcKit.transceive('00B500000A');
                        var resultNumber = getCardNumber(result1);

                        var result2utf = Uint8List.fromList(result2.codeUnits);
                        var balance = getHexString(result2utf);
                        var saldo = readSaldo(result2);
                        setState(() {
                          _result =
                              '1: $balance\n2: $saldo\n3: $resultNumber ';
                        });
                      }
                    } catch (e) {
                      setState(() {
                        _result = 'error: $e';
                      });
                    }
                    // end edit
                    // Pretend that we are working
                    if (!kIsWeb) sleep(const Duration(seconds: 1));
                    await FlutterNfcKit.finish(iosAlertMessage: "Finished!");
                  },
                  child: const Text('Start polling'),
                ),
                const SizedBox(height: 10),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _tag != null
                        ? Text(
                            'ID: ${_tag!.id}\nStandard: ${_tag!.standard}\nType: ${_tag!.type}\nATQA: ${_tag!.atqa}\nSAK: ${_tag!.sak}\nHistorical Bytes: ${_tag!.historicalBytes}\nProtocol Info: ${_tag!.protocolInfo}\nApplication Data: ${_tag!.applicationData}\nHigher Layer Response: ${_tag!.hiLayerResponse}\nManufacturer: ${_tag!.manufacturer}\nSystem Code: ${_tag!.systemCode}\nDSF ID: ${_tag!.dsfId}\nNDEF Available: ${_tag!.ndefAvailable}\nNDEF Type: ${_tag!.ndefType}\nNDEF Writable: ${_tag!.ndefWritable}\nNDEF Can Make Read Only: ${_tag!.ndefCanMakeReadOnly}\nNDEF Capacity: ${_tag!.ndefCapacity}\n\n Transceive Result:\n$_result')
                        : const Text('No tag polled yet.')),
              ])))),
          Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: () async {
                          if (_records!.length != 0) {
                            try {
                              NFCTag tag = await FlutterNfcKit.poll();
                              setState(() {
                                _tag = tag;
                              });
                              if (tag.type == NFCTagType.mifare_ultralight ||
                                  tag.type == NFCTagType.mifare_classic ||
                                  tag.type == NFCTagType.iso15693) {
                                await FlutterNfcKit.writeNDEFRecords(_records!);
                                setState(() {
                                  _writeResult = 'OK';
                                });
                              } else {
                                setState(() {
                                  _writeResult =
                                      'error: NDEF not supported: ${tag.type}';
                                });
                              }
                            } catch (e, stacktrace) {
                              setState(() {
                                _writeResult = 'error: $e';
                              });
                              print(stacktrace);
                            } finally {
                              await FlutterNfcKit.finish();
                            }
                          } else {
                            setState(() {
                              _writeResult = 'error: No record';
                            });
                          }
                        },
                        child: const Text("Start writing"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return SimpleDialog(
                                    title: const Text("Record Type"),
                                    children: <Widget>[
                                      SimpleDialogOption(
                                        child: const Text("Text Record"),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final result = await Navigator.push(
                                              context, MaterialPageRoute(
                                                  builder: (context) {
                                            return TextRecordSetting();
                                          }));
                                          if (result != null) {
                                            if (result is ndef.TextRecord) {
                                              setState(() {
                                                _records!.add(result);
                                              });
                                            }
                                          }
                                        },
                                      ),
                                      SimpleDialogOption(
                                        child: const Text("Uri Record"),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final result = await Navigator.push(
                                              context, MaterialPageRoute(
                                                  builder: (context) {
                                            return UriRecordSetting();
                                          }));
                                          if (result != null) {
                                            if (result is ndef.UriRecord) {
                                              setState(() {
                                                _records!.add(result);
                                              });
                                            }
                                          }
                                        },
                                      ),
                                      SimpleDialogOption(
                                        child: const Text("Raw Record"),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final result = await Navigator.push(
                                              context, MaterialPageRoute(
                                                  builder: (context) {
                                            return NDEFRecordSetting();
                                          }));
                                          if (result != null) {
                                            if (result is ndef.NDEFRecord) {
                                              setState(() {
                                                _records!.add(result);
                                              });
                                            }
                                          }
                                        },
                                      ),
                                    ]);
                              });
                        },
                        child: const Text("Add record"),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Result: $_writeResult'),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 1,
                    child: ListView(
                        shrinkWrap: true,
                        children: List<Widget>.generate(
                            _records!.length,
                            (index) => GestureDetector(
                                  child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Text(
                                          'id:${_records![index].idString}\ntnf:${_records![index].tnf}\ntype:${_records![index].type?.toHexString()}\npayload:${_records![index].payload?.toHexString()}\n')),
                                  onTap: () async {
                                    final result = await Navigator.push(context,
                                        MaterialPageRoute(builder: (context) {
                                      return NDEFRecordSetting(
                                          record: _records![index]);
                                    }));
                                    if (result != null) {
                                      if (result is ndef.NDEFRecord) {
                                        setState(() {
                                          _records![index] = result;
                                        });
                                      } else if (result is String &&
                                          result == "Delete") {
                                        _records!.removeAt(index);
                                      }
                                    }
                                  },
                                ))),
                  ),
                ]),
          )
        ]),
      ),
    );
  }

  int? readSaldo(String d) {
    try {
      String data = d.substring(0,11);
      List<String> ary = data.split(" ");
      ary = reverse(ary);

      String balance = "";
      for (String kaka in ary) {
        balance += kaka;
      }
      return int.parse(balance, radix: 16);
    } catch (e) {
      print("READ SALDO: FAILED!");
      return null;
    }
  }

  List<String> reverse(List<String> arr) {
    String reversed = "";
    for (int i = arr.length; i > 0; i--) {
      reversed += "${arr[i - 1]} ";
    }
    List<String> reversedArray = reversed.trim().split(" ");

    return reversedArray;
  }

  String getHexString(Uint8List data) {
    String szDataStr = '';
    for (int b in data) {
      szDataStr += '${(b & 0xFF).toRadixString(16).padLeft(2, '0')} ';
    }
    return szDataStr;
  }

  Uint8List stringToHex(String data) {
    print("CARD COMMAND: $data");
    String hexChars = "0123456789ABCDEF";
    Uint8List tempData =
        Uint8List.fromList(utf8.encode(data.toLowerCase().replaceAll(" ", "")));
    Uint8List hex = Uint8List(tempData.length ~/ 2);

    int i = 0;
    while (i < tempData.length) {
      int i1 = hexChars.indexOf(String.fromCharCode(tempData[i]));
      int i2 = hexChars.indexOf(String.fromCharCode(tempData[i + 1]));
      hex[i ~/ 2] = ((i1 << 4 | i2));
      i += 2;
    }

    return hex;
  }

  String getCardNumber(String cardNum) {
    String card_number = "FAILED!";
    try {
      cardNum = cardNum.substring(0, 16);
      print("CARD INFO: $cardNum");
      card_number = 1 == 1
          ? // formatted parse by 4 char
          cardNum
              .replaceAllMapped(
                  RegExp(r"(.{4})"), (match) => "${match.group(1)} ")
              .trim()
          : cardNum;
    } catch (e) {
      print(e.toString());
    }
    return card_number;
  }

  Uint8List convertStringToUint8List(String str) {
    final List<int> codeUnits = str.codeUnits;
    final Uint8List unit8List = Uint8List.fromList(codeUnits);

    return unit8List;
  }
}
