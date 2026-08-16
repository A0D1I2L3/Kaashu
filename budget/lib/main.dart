import 'package:budget/functions.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/struct/iconObjects.dart';
import 'package:budget/struct/keyboardIntents.dart';
import 'package:budget/struct/logging.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/struct/languageMap.dart';
import 'package:budget/struct/initializeBiometrics.dart';
import 'package:budget/struct/upiScreenshotScanner.dart';
import 'package:budget/widgets/util/appLinks.dart';
import 'package:budget/widgets/util/onAppResume.dart';
import 'package:budget/widgets/util/watchForDayChange.dart';
import 'package:budget/widgets/watchAllWallets.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/widgets/navigationSidebar.dart';
import 'package:budget/widgets/globalLoadingProgress.dart';
import 'package:budget/struct/scrollBehaviorOverride.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/struct/initializeNotifications.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/restartApp.dart';
import 'package:budget/struct/customDelayedCurve.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:budget/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:easy_localization/easy_localization.dart';

// Requires hot restart when changed
bool allowDebugFlags = true || kIsWeb;
bool allowDangerousDebugFlags = kDebugMode;

void main() async {
  captureLogs(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
    sharedPreferences = await SharedPreferences.getInstance();
    database = await constructDb('db');
    notificationPayload = await initializeNotifications();
    entireAppLoaded = false;
    await loadCurrencyJSON();
    await loadLanguageNamesJSON();
    await initializeSettings();
    tz.initializeTimeZones();
    final String? locationName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(locationName ?? "America/New_York"));
    iconObjects.sort((a, b) => (a.mostLikelyCategoryName ?? a.icon)
        .compareTo((b.mostLikelyCategoryName ?? b.icon)));
    setHighRefreshRate();
    runApp(
      InitializeLocalizations(
        child: RestartApp(
          child: InitializeApp(key: appStateKey),
        ),
      ),
    );
  });
}

GlobalKey<_InitializeAppState> appStateKey = GlobalKey();
GlobalKey<PageNavigationFrameworkState> pageNavigationFrameworkKey =
    GlobalKey();

class InitializeApp extends StatefulWidget {
  InitializeApp({Key? key}) : super(key: key);

  @override
  State<InitializeApp> createState() => _InitializeAppState();
}

class _InitializeAppState extends State<InitializeApp> {
  @override
  void initState() {
    super.initState();
    // Handle a UPI screenshot that was shared into the app while it was closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handlePendingSharedUpiImage(context);
      initUpiShareListener(() => handlePendingSharedUpiImage(context));
    });
  }

  void refreshAppState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return App(key: ValueKey("Main App"));
  }
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("Rebuilt Material App");
    return MaterialApp(
      showPerformanceOverlay: kProfileMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      shortcuts: shortcuts,
      actions: keyboardIntents,
      themeAnimationDuration: Duration(milliseconds: 400),
      themeAnimationCurve: CustomDelayedCurve(),
      key: ValueKey('KaashuAppMain'),
      title: 'Kaashu',
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      scrollBehavior: ScrollBehaviorOverride(),
      themeMode: getSettingConstants(appStateSettings)["theme"],
      home: HandleWillPopScope(
        child: Stack(
          children: [
            Row(
              children: [
                NavigationSidebar(key: sidebarStateKey),
                Expanded(
                    child: Stack(
                  children: [
                    InitialPageRouteNavigator(),
                    GlobalSnackbar(key: snackbarKey),
                  ],
                )),
              ],
            ),
            GlobalLoadingIndeterminate(key: loadingIndeterminateKey),
            GlobalLoadingProgress(key: loadingProgressKey),
          ],
        ),
      ),
      builder: (context, child) {
        if (kReleaseMode) {
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            return Container(color: Colors.transparent);
          };
        }

        Widget mainWidget = OnAppResume(
          updateGlobalAppLifecycleState: true,
          onAppResume: () async {
            await setHighRefreshRate();
            handlePendingSharedUpiImage(context);
          },
          child: InitializeBiometrics(
            child: InitializeAppLinks(
              child: WatchForDayChange(
                child: WatchSelectedWalletPk(
                  child: WatchAllWallets(
                    child: child ?? SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );

        if (kIsWeb) {
          return FadeIn(
              duration: Duration(milliseconds: 1000), child: mainWidget);
        } else {
          return mainWidget;
        }
      },
      // ),
    );
  }
}
