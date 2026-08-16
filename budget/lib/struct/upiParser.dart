import 'package:intl/intl.dart';

/// Parsed details from a UPI payment screenshot.
class UPITransaction {
  const UPITransaction({
    required this.amount,
    this.merchant,
    this.upiId,
    this.dateTime,
    required this.isIncome,
    this.upiRef,
  });

  final double amount;
  final String? merchant;
  final String? upiId;
  final DateTime? dateTime;
  final bool isIncome;
  final String? upiRef;

  /// Human readable note that can be stored with the transaction.
  String? get note {
    final StringBuffer buffer = StringBuffer();
    if (upiRef != null && upiRef!.isNotEmpty) {
      buffer.write("UPI Ref: $upiRef");
    }
    String result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }

  String? get merchantDisplayName => merchant ?? upiId;
}

/// Attempts to parse a UPI payment screenshot OCR result.
/// Returns null if no amount could be found.
UPITransaction? parseUPITransaction(String ocrText) {
  if (ocrText.trim().isEmpty) return null;

  double? amount = _extractAmount(ocrText);
  if (amount == null || amount <= 0) return null;

  bool isIncome = _isIncome(ocrText);
  String? merchant = _extractMerchant(ocrText, isIncome);
  String? upiId = _extractUpiId(ocrText);
  DateTime? dateTime = _extractDateTime(ocrText);
  String? upiRef = _extractUpiRef(ocrText);

  return UPITransaction(
    amount: amount,
    merchant: merchant,
    upiId: upiId,
    dateTime: dateTime,
    isIncome: isIncome,
    upiRef: upiRef,
  );
}

/// OCR frequently mangles the rupee symbol (₹ -> %, ©, €, $, X, R, 3, 2) or
/// drops it entirely, so the symbol is treated as a hint rather than a
/// requirement. Note: a leading misread digit (₹98 -> "398") is deliberately
/// NOT stripped, since a genuine "398" is indistinguishable from it.
final RegExp _amountWithSymbol = RegExp(
  r'(?:[₹%©€$XR]|Rs\.?|INR\.?)\s*([\d][\d,]*(?:\.\d{1,2})?)',
  caseSensitive: false,
);

final RegExp _amountAfterLabel = RegExp(
  r'(?:Amount|Amount Paid|Total|Transaction Amount)[\s:\-—]*([\d][\d,]*(?:\.\d{1,2})?)',
  caseSensitive: false,
);

/// A standalone line that is just a number (optionally with a trailing ₹
/// misread like "398 ©"). Ref numbers / UTR / txn IDs are too long to match.
final RegExp _standaloneAmountLine = RegExp(
  r'^\s*(?:[₹%©€$]\s*)?([\d]{1,7}(?:[.,]\d{1,3})?)\s*(?:[©%€$]\s*)?$',
  multiLine: true,
);

final RegExp _plainAmount = RegExp(
  r'(?<!\d)([\d]{1,3}(?:,[\d]{3})+)(?:\.(\d{1,2}))?(?!\d)',
);

double? _parseAmountString(String raw) {
  String cleaned = raw.replaceAll(",", "");
  double? value = double.tryParse(cleaned);
  return value;
}

double? _extractAmount(String text) {
  List<double> candidates = [];

  for (final match in _amountWithSymbol.allMatches(text)) {
    double? value = _parseAmountString(match.group(1)!);
    if (value != null && value > 0) candidates.add(value);
  }

  for (final match in _amountAfterLabel.allMatches(text)) {
    double? value = _parseAmountString(match.group(1)!);
    if (value != null && value > 0) candidates.add(value);
  }

  // Standalone number lines ("250", "398 ©"), which is how the amount
  // typically renders when OCR drops the rupee symbol.
  for (final match in _standaloneAmountLine.allMatches(text)) {
    double? value = _parseAmountString(match.group(1)!);
    if (value != null && value > 0) candidates.add(value);
  }

  // Last resort: any comma grouped amount (e.g. "1,234.56" without symbol).
  for (final match in _plainAmount.allMatches(text)) {
    double? value = _parseAmountString(match.group(0)!);
    if (value != null && value > 0) candidates.add(value);
  }

  if (candidates.isEmpty) return null;
  candidates.sort();
  return candidates.last;
}

final RegExp _incomeKeywords = RegExp(
  r'\b(?:received|credited|credit|added to|money received|payment received|you got|refund)\b',
  caseSensitive: false,
);

final RegExp _expenseKeywords = RegExp(
  r'\b(?:sent|debited|debit|paid to|paid |money sent|payment sent|transferred to|you sent|debited from)\b',
  caseSensitive: false,
);

bool _isIncome(String text) {
  String lower = text.toLowerCase();
  bool hasIncome = _incomeKeywords.hasMatch(lower);
  bool hasExpense = _expenseKeywords.hasMatch(lower);

  // "Successfully debited" is an expense even if "credited" appears in a
  // balance line; prefer whichever keyword appears first in the text.
  if (hasIncome && hasExpense) {
    int incomeIndex = _incomeKeywords.firstMatch(lower)!.start;
    int expenseIndex = _expenseKeywords.firstMatch(lower)!.start;
    return incomeIndex < expenseIndex;
  }
  return hasIncome && !hasExpense;
}

final RegExp _merchantTo = RegExp(
  r'(?:Paid to|Transferred to|\bTo\b)\s*:?\s*\n?\s*([^\n@]{2,40})',
  caseSensitive: false,
);

final RegExp _merchantFrom = RegExp(
  r'(?:Received from|Paid by|From)\s*:?\s*\n?\s*([^\n@]{2,40})',
  caseSensitive: false,
);

final RegExp _upiId = RegExp(
  r'\b([a-zA-Z0-9._\-]+@[a-zA-Z0-9._\-]+)\b',
  caseSensitive: false,
);

String? _extractMerchant(String text, bool isIncome) {
  // "Paid to X" / "To X" — the counterparty for an expense.
  for (final match in _merchantTo.allMatches(text)) {
    String? merchant = _cleanMerchantName(match.group(1));
    if (merchant != null) return merchant;
  }
  // "Received from X" — the counterparty for an income. For expenses "From"
  // usually labels the user's own account, so only trust it for income.
  if (isIncome) {
    for (final match in _merchantFrom.allMatches(text)) {
      String? merchant = _cleanMerchantName(match.group(1));
      if (merchant != null) return merchant;
    }
  }
  return null;
}

String? _cleanMerchantName(String? raw) {
  if (raw == null) return null;
  String value = raw.trim().split("\n").first.trim();
  value = value
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'[^\x00-\x7F]'), '')
      .trim();
  // Reject obvious non-names (status / generic labels).
  if (value.isEmpty || value.length > 40) return null;
  if (RegExp(
          r'^(?:successful|success|payment|upi|bank|transferred|sent|received)$',
          caseSensitive: false)
      .hasMatch(value)) {
    return null;
  }
  return value;
}

String? _extractUpiId(String text) {
  String? match = _upiId.firstMatch(text)?.group(1);
  return match;
}

final List<DateFormat> _dateFormats = [
  DateFormat("d MMM yyyy, h:mm a"), // 12 Aug 2026, 7:41 pm
  DateFormat("d MMM yyyy, h:mma"), // 12 Aug 2026, 7:41pm
  DateFormat("d MMM yyyy, HH:mm"), // 12 Aug 2026, 19:41
  DateFormat("d MMM yyyy h:mm a"), // 12 Aug 2026 7:41 pm
  DateFormat("d MMM yyyy h:mma"), // 12 Aug 2026 7:41pm
  DateFormat("d MMM yyyy HH:mm"), // 12 Aug 2026 19:41
  DateFormat("d MMMM yyyy - h:mm a"), // 15 August 2026 - 05:27 PM
  DateFormat("d MMMM yyyy - h:mma"), // 15 August 2026 - 05:27PM
  DateFormat("d MMMM yyyy, h:mm a"), // 15 August 2026, 7:41 pm
  DateFormat("d MMMM yyyy h:mm a"), // 15 August 2026 7:41 pm
  DateFormat("d MMM yyyy 'at' h:mm a"), // 13 Aug 2026 at 3:20 AM
  DateFormat("d MMM yyyy 'at' h:mma"), // 13 Aug 2026 at 3:20AM
  DateFormat("d MMM yyyy, h:mm a"), // 13 Aug 2026, 7:41 pm
  DateFormat("h:mm a 'on' d MMM yyyy"), // 10:28 pm on 31 Jul 2026
  DateFormat("dd-MM-yyyy, h:mm a"), // 12-08-2026, 7:41 pm
  DateFormat("dd-MM-yyyy HH:mm"), // 12-08-2026 19:41
  DateFormat("dd/MM/yyyy, h:mm a"), // 12/08/2026, 7:41 pm
  DateFormat("dd/MM/yyyy HH:mm"), // 12/08/2026 19:41
  DateFormat("dd-MM-yyyy"), // 12-08-2026
  DateFormat("dd/MM/yyyy"), // 12/08/2026
  DateFormat("d MMM yyyy"), // 12 Aug 2026
];

final RegExp _ampm = RegExp(r'\b(am|pm)\b', caseSensitive: false);

/// OCR sometimes renders the year as "13 Aug '26"; intl treats `'` as an
/// escape so normalize it to a full 4-digit year first.
final RegExp _apostropheYear = RegExp(r"'(\d{2})\b");

DateTime? _extractDateTime(String text) {
  for (String line in text.split("\n")) {
    // intl requires uppercase AM/PM markers, OCR may produce lowercase.
    line =
        line.replaceAllMapped(_ampm, (match) => match.group(1)!.toUpperCase());
    line = line.replaceAllMapped(
      _apostropheYear,
      (match) => "20${match.group(1)}",
    );
    String trimmed = line.trim();
    for (final format in _dateFormats) {
      DateTime? parsed = format.tryParse(trimmed);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

final RegExp _upiRef = RegExp(
  r'(?:UPI Ref(?:erence)?|Ref(?:erence)?(?: No|\.|ID)?|Txn ID|Transaction ID)[\s:\-—]*([A-Za-z0-9]{6,})',
  caseSensitive: false,
);

final RegExp _upiRefVpa = RegExp(
  r'\b([A-Z0-9]{12})\b',
);

String? _extractUpiRef(String text) {
  final match = _upiRef.firstMatch(text);
  if (match != null && match.group(1) != null) return match.group(1);
  // Fall back to a standalone 12 character alphanumeric reference.
  final vpaMatch = _upiRefVpa.firstMatch(text);
  if (vpaMatch != null && vpaMatch.group(1) != null) return vpaMatch.group(1);
  return null;
}
