import 'package:budget/struct/upiParser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseUPITransaction - PhonePe', () {
    test('parses a sent payment', () {
      const ocr = '''
Money sent successfully
Sent to Swiggy
₹249.00
12 Aug 2026, 7:41 pm
UPI Ref: 453128768912
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(249.00, 0.001));
      expect(parsed.merchant, "Swiggy");
      expect(parsed.isIncome, isFalse);
      expect(parsed.upiRef, "453128768912");
      expect(parsed.dateTime, DateTime(2026, 8, 12, 19, 41));
    });

    test('parses a received payment', () {
      const ocr = '''
Received from Rahul Sharma
₹1,500.00
12 Aug 2026, 10:15 am
UPI Ref: 221409876543
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(1500.00, 0.001));
      expect(parsed.merchant, "Rahul Sharma");
      expect(parsed.isIncome, isTrue);
      expect(parsed.upiRef, "221409876543");
    });

    test('parses amount with Rs. prefix', () {
      const ocr = '''
Paid to BigBasket
Rs. 1,234.50
13 Aug 2026, 6:20 pm
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(1234.50, 0.001));
      expect(parsed.merchant, "BigBasket");
      expect(parsed.isIncome, isFalse);
    });
  });

  group('parseUPITransaction - GPay', () {
    test('parses "you sent"', () {
      const ocr = '''
You sent ₹500.00
To: Rohan Gupta
UPI Ref: 998877665544
22 Jul 2026, 9:12 pm
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(500.00, 0.001));
      expect(parsed.merchant, "Rohan Gupta");
      expect(parsed.isIncome, isFalse);
      expect(parsed.upiRef, "998877665544");
    });

    test('parses "you received"', () {
      const ocr = '''
You received ₹2,000.00
From: Priya Verma
23 Jul 2026, 11:30 am
Ref No: 445566778899
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(2000.00, 0.001));
      expect(parsed.merchant, "Priya Verma");
      expect(parsed.isIncome, isTrue);
      expect(parsed.upiRef, "445566778899");
    });
  });

  group('parseUPITransaction - BHIM', () {
    test('parses money sent with amount label', () {
      const ocr = '''
Money Sent
Paid to: Metro Recharge
Amount: ₹450.00
Date: 15-08-2026
Time: 14:25
Txn ID: 123456789012
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(450.00, 0.001));
      expect(parsed.merchant, "Metro Recharge");
      expect(parsed.isIncome, isFalse);
      expect(parsed.upiRef, "123456789012");
    });

    test('parses money received', () {
      const ocr = '''
Money Received
From: Ankit Mehta
Amount Rs. 800
Date: 16/08/2026
Time: 08:05
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(800.00, 0.001));
      expect(parsed.merchant, "Ankit Mehta");
      expect(parsed.isIncome, isTrue);
    });
  });

  group('parseUPITransaction - misc', () {
    test('extracts UPI ID when merchant name unavailable', () {
      const ocr = '''
₹99.00
Successfully Paid
xyz@okhdfcbank
UPI Ref: 789456123123
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(99.00, 0.001));
      expect(parsed.upiId, "xyz@okhdfcbank");
      expect(parsed.merchant, isNull);
      expect(parsed.isIncome, isFalse);
    });

    test('income wins when income keyword appears first', () {
      const ocr = '''
Amount: ₹250.00
Payment received
Your account has been credited
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(250.00, 0.001));
      expect(parsed.isIncome, isTrue);
    });

    test('handles negative case: debited is an expense', () {
      const ocr = '''
Successfully debited ₹320.00 from your account
Paid to: Jio
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(320.00, 0.001));
      expect(parsed.merchant, "Jio");
      expect(parsed.isIncome, isFalse);
    });

    test('returns null when no amount present', () {
      expect(parseUPITransaction("No payment details here"), isNull);
      expect(parseUPITransaction(""), isNull);
    });
  });

  group('parseUPITransaction - real OCR (tesseract)', () {
    test('GPay screenshot: mangled rupee symbol and standalone amount', () {
      // ₹ was OCR'd as %; amount also appears alone on its own line.
      const ocr = '''
To Gani PK
+91 85907 67210
250
& Completed
15 Aug 2026, 7:08 pm
%250 was debited
7:08 pm
%250 sent to Gani PK
UPI transaction ID
622747485101
To: ABDUL GANI P K
Google Pay + abdulganipk21@okaxis
From: ADIL HANEEF M K (State Bank of India)
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(250.00, 0.001));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, "Gani PK");
      expect(parsed.upiId, "abdulganipk21@okaxis");
      expect(parsed.upiRef, "622747485101");
      expect(parsed.dateTime, DateTime(2026, 8, 15, 19, 8));
    });

    test('LIFIY/Yes Bank screenshot: full month and standalone amount', () {
      // Amount line renders without any symbol; date uses full month name.
      const ocr = '''
Payment successful
to Swiggy
3149
You earned 0.6% cashback
15 August 2026 - 05:27PM
UPI Transaction ID: 659325159964
View Details
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(3149.00, 0.001));
      expect(parsed.isIncome, isFalse);
      expect(parsed.upiRef, "659325159964");
      expect(parsed.dateTime, DateTime(2026, 8, 15, 17, 27));
    });

    test('MobiKwik screenshot: trailing mangled symbol and 2-digit year', () {
      // "© 25l" in the header is a false candidate; 398 must win as largest.
      const ocr = '''
3:26 © 25l al €
X © Share ® Help
398 ©
UPI Payment Successful
13 Aug '26 at 3:20AM
Swiggy
upiswiggy@icici
View History Pay Again
From
Adil Haneef M K
9496655461@mbkns
MobiKwik Order ID
OMK27ab7b9f8a79553
UPI Transaction ID
622503439720
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(398.00, 0.001));
      expect(parsed.isIncome, isFalse);
      expect(parsed.upiId, "upiswiggy@icici");
      expect(parsed.merchant, isNull);
      expect(parsed.upiRef, "622503439720");
      expect(parsed.dateTime, DateTime(2026, 8, 13, 3, 20));
    });

    test('expense with only a "From" line does not use own name as merchant',
        () {
      const ocr = '''
Transaction Successful
25 Jul 2026, 6:10 pm
1200
Swiggy
upiswiggy@icici
From
Adil Haneef M K
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(1200.00, 0.001));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, isNull);
    });

    test('PhonePe screenshot: amount absent so it returns null', () {
      const ocr = '''
Transaction Successful
10:28 pm on 31 Jul 2026
Paid to
SWIGGY INSTAMART PRIVATE LIMITED
swiggyinstamartecom@axb
PhonePe Transaction ID
T2607312228201058936319
Debited from
XXXXXX1028
UTR: 540130772358
''';
      final parsed = parseUPITransaction(ocr);
      expect(parsed, isNull);
    });
  });
}
