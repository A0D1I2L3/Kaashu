import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/upiParser.dart';
import 'package:budget/struct/upiOcr.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/globalLoadingProgress.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const MethodChannel upiMethodChannel = MethodChannel("kashu.upi");

/// Picks an image from the gallery and returns its path, or null if cancelled.
Future<String?> pickUpiScreenshotPath() async {
  final XFile? image =
      await ImagePicker().pickImage(source: ImageSource.gallery);
  return image?.path;
}

/// Runs the full OCR pipeline (validation → preprocessing → ML Kit v2) on the
/// given image and returns the structured result.
Future<UpiOcrResult> recognizeTextInImage(String imagePath) {
  return recognizeUpiScreenshot(imagePath);
}

/// Scans a UPI payment screenshot (either picked from the gallery or shared
/// into the app), parses the details and offers to add a transaction.
Future<void> scanUpiScreenshot(BuildContext context,
    {String? imagePath}) async {
  loadingIndeterminateKey.currentState?.setVisibility(true);

  String? path = imagePath;
  UPITransaction? parsed;
  String? error;

  try {
    if (path == null) {
      path = await pickUpiScreenshotPath();
      if (path == null) return; // User cancelled
    }
    final UpiOcrResult ocrResult = await recognizeTextInImage(path);
    final String ocrText = ocrResult.rawText;
    if (ocrText.trim().isEmpty) {
      error = "upi-scan-failed-description".tr();
    } else {
      parsed = parseUPITransaction(ocrText);
      if (parsed == null) {
        error = "upi-scan-failed-description".tr();
      }
    }
  } catch (e) {
    error = "upi-scan-failed-description".tr();
    print("Error scanning UPI screenshot: " + e.toString());
  } finally {
    loadingIndeterminateKey.currentState?.setVisibility(false);
  }

  if (!context.mounted) return;

  if (error != null) {
    await openPopup(
      context,
      icon: appStateSettings["outlinedIcons"]
          ? Icons.document_scanner_outlined
          : Icons.document_scanner_rounded,
      title: "upi-scan-failed".tr(),
      description: error,
      onCancel: () => popRoute(context),
      onCancelLabel: "close".tr(),
      onSubmit: () => popRoute(context),
      onSubmitLabel: "ok".tr(),
    );
    return;
  }

  await showUpiResultBottomSheet(context, parsed!);
}

/// Shows the parsed UPI details and lets the user add a transaction.
Future<void> showUpiResultBottomSheet(
    BuildContext context, UPITransaction upi) async {
  final String amountString = convertToMoney(
    Provider.of<AllWallets>(context),
    upi.amount,
  );

  Widget detailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TextFont(
              text: label,
              fontSize: 14,
              textColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextFont(
              text: value,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  final String merchant = upi.merchantDisplayName ?? "—";
  final String direction =
      upi.isIncome ? "upi-type-income".tr() : "upi-type-expense".tr();
  final String dateString = upi.dateTime == null
      ? "—"
      : DateFormat("d MMM yyyy, h:mm a").format(upi.dateTime!);

  await openBottomSheet(
    context,
    PopupFramework(
      icon: Icon(appStateSettings["outlinedIcons"]
          ? Icons.document_scanner_outlined
          : Icons.document_scanner_rounded),
      title: "upi-scan-result".tr(),
      customSubtitleWidget: TextFont(
        text: "upi-scan-result-description".tr(),
        fontSize: 14,
        maxLines: 5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          detailsRow("upi-amount".tr(), amountString),
          detailsRow("upi-merchant".tr(), merchant),
          if (upi.dateTime != null) detailsRow("upi-date".tr(), dateString),
          detailsRow("upi-type".tr(), direction),
          if (upi.upiRef != null) detailsRow("upi-ref".tr(), upi.upiRef!),
          SizedBox(height: 10),
          Button(
            label: "upi-add-transaction".tr(),
            icon: appStateSettings["outlinedIcons"]
                ? Icons.add_outlined
                : Icons.add_rounded,
            onTap: () async {
              popRoute(context);
              await pushRoute(
                context,
                AddTransactionPage(
                  routesToPopAfterDelete: RoutesToPopAfterDelete.None,
                  selectedAmount: upi.amount,
                  selectedIncome: upi.isIncome,
                  selectedTitle: upi.merchantDisplayName,
                  selectedNotes: upi.note,
                  selectedDate: upi.dateTime,
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Reads a pending shared UPI screenshot path handed over by the Android
/// share sheet (ACTION_SEND), clearing it in the process.
Future<String?> getPendingSharedUpiImage() async {
  try {
    final String? path =
        await upiMethodChannel.invokeMethod<String>("getPendingSharedUpiImage");
    return path;
  } catch (e) {
    return null;
  }
}

/// Called after the app has loaded (and on resume) to handle a UPI screenshot
/// that was shared into the app via the Android share sheet.
Future<void> handlePendingSharedUpiImage(BuildContext context) async {
  if (appStateSettings["scan-upi-on-share"] != true) return;
  if (appStateSettings["hasOnboarded"] != true) return;
  final String? path = await getPendingSharedUpiImage();
  if (path == null) return;
  await scanUpiScreenshot(context, imagePath: path);
}
