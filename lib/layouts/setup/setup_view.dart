import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/pages/setup_checks/battery_optimization.dart';
import 'package:bluebubbles/layouts/setup/dialogs/failed_to_connect_dialog.dart';
import 'package:bluebubbles/layouts/setup/pages/sync/sync_settings.dart';
import 'package:bluebubbles/layouts/setup/pages/sync/server_credentials.dart';
import 'package:bluebubbles/layouts/setup/pages/contacts/request_contacts.dart';
import 'package:bluebubbles/layouts/setup/pages/setup_checks/mac_setup_check.dart';
import 'package:bluebubbles/layouts/setup/pages/sync/sync_progress.dart';
import 'package:bluebubbles/layouts/setup/pages/welcome/welcome_page.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class SetupViewController extends StatefulController {
  final pageController = PageController(initialPage: 0);
  int currentPage = 1;
  int numberToDownload = 25;
  bool skipEmptyChats = true;
  bool saveToDownloads = false;
  String error = "";
  bool obscurePass = true;

  int get pageOfNoReturn => kIsWeb || kIsDesktop ? 3 : 5;

  void updatePage(int newPage) {
    currentPage = newPage;
    updateWidgetFunctions[PageNumber]?.call(newPage);
  }

  void updateNumberToDownload(int num) {
    numberToDownload = num;
    updateWidgetFunctions[NumberOfMessagesText]?.call(num);
  }

  void updateConnectError(String newError) {
    error = newError;
    updateWidgetFunctions[ErrorText]?.call(newError);
  }
}

class SetupView extends StatefulWidget {
  SetupView({Key? key}) : super(key: key);

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends OptimizedState<SetupView> {
  final controller = Get.put(SetupViewController());

  @override
  void initState() {
    super.initState();

    ever(SocketManager().state, (event) {
      if (event == SocketState.FAILED
          && !SettingsManager().settings.finishedSetup.value
          && controller.pageController.hasClients
          && controller.currentPage > controller.pageOfNoReturn) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => FailedToConnectDialog(
            onDismiss: () {
              controller.pageController.animateToPage(
                controller.pageOfNoReturn - 1,
                duration: Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
              Navigator.of(context).pop();
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: context.theme.colorScheme.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              SetupHeader(),
              const SizedBox(height: 20),
              SetupPages(),
            ],
          ),
        ),
      ),
    );
  }
}

class SetupHeader extends StatelessWidget {
  final SetupViewController controller = Get.find<SetupViewController>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: kIsDesktop ? 40 : 20, left: 20, right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Hero(
                tag: "setup-icon",
                child: Image.asset("assets/icon/icon.png", width: 30, fit: BoxFit.contain)
              ),
              const SizedBox(width: 10),
              Text(
                "BlueBubbles",
                style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2, fontSizeFactor: 1.35),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 13),
              child: PageNumber(parentController: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class PageNumber extends CustomStateful<SetupViewController> {
  PageNumber({required super.parentController});

  @override
  State<StatefulWidget> createState() => _PageNumberState();
}

class _PageNumberState extends CustomState<PageNumber, int, SetupViewController> {

  @override
  void updateWidget(int newVal) {
    controller.currentPage = newVal;
    super.updateWidget(newVal);
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "${controller.currentPage}",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          TextSpan(
            text: " of ${kIsWeb ? "4" : kIsDesktop ? "5" : "7"}",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: Colors.white38, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}

class SetupPages extends StatelessWidget {
  final SetupViewController controller = Get.find<SetupViewController>();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PageView(
        onPageChanged: (page) {
          // skip pages if the things required are already complete
          if (!kIsWeb && !kIsDesktop && page == 1 && controller.currentPage == 1) {
            Permission.contacts.status.then((status) {
              if (status.isGranted) {
                controller.pageController.nextPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
          if (!kIsWeb && !kIsDesktop && page == 2 && controller.currentPage == 2) {
            DisableBatteryOptimization.isAllBatteryOptimizationDisabled.then((isDisabled) {
              if (isDisabled ?? false) {
                controller.pageController.nextPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
          controller.updatePage(page + 1);
        },
        physics: const NeverScrollableScrollPhysics(),
        controller: controller.pageController,
        children: <Widget>[
          WelcomePage(),
          if (!kIsWeb && !kIsDesktop) RequestContacts(),
          if (!kIsWeb && !kIsDesktop) BatteryOptimizationCheck(),
          MacSetupCheck(),
          ServerCredentials(),
          if (!kIsWeb)
            SyncSettings(),
          SyncProgress(),
          //ThemeSelector(),
        ],
      ),
    );
  }
}
