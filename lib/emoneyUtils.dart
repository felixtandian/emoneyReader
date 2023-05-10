import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:nfc_manager/platform_tags.dart';

class EmoneyUtils {
  String selectBalance = "00B500000A";
  String selectEmoney = "00A40400080000000000000001";
  String cardAttribute = "00F210000B";
  String cardInfo = "00B300003F";

  late Uint8List byteAPDU;
  late IsoDep myTag;

  EmoneyUtils(IsoDep tags) {
    myTag = myTag;
  }

  bool getCardValidation() {
    return isCardValid(getAllCardData(selectEmoney));
  }

  bool isCardValid(String cardResult) {
    if (cardResult.replaceAll(" ", "")=="6A82" ||
        cardResult.replaceAll(" ", "")=="6D00") {
      return false;
    }
    return true;
  }

  int? getSaldo() {
    int? ret = readSaldo(getAllCardData(selectBalance));
    // Log.e("CARD SALDO", String.valueOf(ret));
    return ret;
  }

  String getCardAttribute() {
    String ret = getAllCardData(cardAttribute).replaceAll(" ", "");
    print("CARD ATTRIBUTE: $ret");
    return ret;
  }

  String getCardNumber(int format) {
    String cardNum = getAllCardData(cardInfo).replaceAll(" ", "");

    String card_number = "FAILED!";
    try {
      cardNum = cardNum.substring(0, 16);
      print("CARD INFO: $cardNum");
      card_number = format == 1
          ? // formatted parse by 4 char
          cardNum.replaceAllMapped(RegExp(r"(.{4})"), (match) => "${match.group(1)} ").trim()
          : cardNum;
    } catch (e) {
      print(e.toString());
    }
    return card_number;
  }

  int? readSaldo(String d) {
    try {
      String data = d.substring(0, 11);
      List<String> ary = data.split(" ");
      ary = reverse(ary);
      print("REVERSE: $ary");

      String balance = "";
      for (String kaka in ary) {
        balance += kaka;
      }
      print("READ SALDO: $balance");
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

  String getAllCardData(String cmd) {
    String data = '';
    try {
      byteAPDU = stringToHex(cmd);
      print("APDU: $byteAPDU");
      Uint8List ra = myTag.transceive(data: byteAPDU) as Uint8List;
      print("TRANSCEIVE: $ra");
      data = getHexString(ra);
    } catch (e) {
      print(e.toString());
    }
    return data;
  }

  String getHexString(Uint8List data) {
    String szDataStr = "";
    for (int b in data) {
      szDataStr += b.toRadixString(16).padLeft(2, '0').toUpperCase() + " ";
    }
    return szDataStr.trim();
  }

  Uint8List stringToHex(String data) {
    print("CARD COMMAND: $data");
    String hexChars = "0123456789ABCDEF";
    Uint8List tempData = Uint8List.fromList(utf8.encode(data.toLowerCase().replaceAll(" ", "")));
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

  
}

