import 'package:budget/colors.dart';
import 'package:budget/functions.dart';
import 'package:budget/widgets/exportCSV.dart';
import 'package:budget/widgets/exportDB.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/importCSV.dart';
import 'package:budget/widgets/importDB.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({Key? key}) : super(key: key);

  @override
  State<AccountsPage> createState() => AccountsPageState();
}

class AccountsPageState extends State<AccountsPage> {
  void refreshState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      horizontalPaddingConstrained: true,
      dragDownToDismiss: true,
      expandedHeight: 56,
      title: getPlatform() == PlatformOS.isIOS
          ? "backup".tr()
          : "data-backup".tr(),
      appBarBackgroundColor: getPlatform() == PlatformOS.isIOS
          ? null
          : Theme.of(context).colorScheme.secondaryContainer,
      appBarBackgroundColorStart: getPlatform() == PlatformOS.isIOS
          ? null
          : Theme.of(context).colorScheme.secondaryContainer,
      bottomPadding: false,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 15),
                TextFont(
                  text: "local-backup-description".tr(),
                  fontSize: 14,
                  textAlign: TextAlign.center,
                  textColor: getColor(context, "textLight"),
                ),
                SizedBox(height: 15),
                ExportDB(),
                ImportDB(),
                SizedBox(height: 5),
                ExportCSV(),
                ImportCSV(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
