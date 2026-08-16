import 'dart:io';

import 'package:budget/struct/upiParser.dart';

void main() {
  for (int i = 1; i <= 4; i++) {
    String ocr = File('/tmp/opencode/upi_ocr_$i.txt').readAsStringSync();
    print('===== test $i =====');
    final parsed = parseUPITransaction(ocr);
    if (parsed == null) {
      print('  PARSE FAILED');
    } else {
      print('  amount:    ${parsed.amount}');
      print('  isIncome:  ${parsed.isIncome}');
      print('  merchant:  ${parsed.merchant}');
      print('  upiId:     ${parsed.upiId}');
      print('  dateTime:  ${parsed.dateTime}');
      print('  upiRef:    ${parsed.upiRef}');
    }
    print('');
  }
}
