import 'dart:io';

import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/app/navbar_widget.dart';
import 'package:chatdent/app/panel_widget.dart';
import 'package:chatdent/app/routes.dart';
import 'package:chatdent/common_widgets/dialogs/changelog_dialog.dart';
import 'package:chatdent/common_widgets/dialogs/first_launch_dialog.dart';
import 'package:chatdent/common_widgets/dialogs/new_version_dialog.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/features/network_actions/network_actions_widget.dart';
import 'package:chatdent/features/patient_side/patient_side_screen.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/launch.dart';
import 'package:chatdent/services/localization/en.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/features/login/login_screen.dart';
import 'package:chatdent/common_widgets/current_account.dart';
import 'package:chatdent/common_widgets/logo.dart';
import 'package:chatdent/services/patient_side.dart';
import 'package:chatdent/services/version.dart';
import 'package:chatdent/services/changelog.dart';
import 'package:chatdent/utils/flyout_focus_fix.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

late BuildContext bContext;

/// Cached [GlobalObjectKey]s for route screen bodies so [identical] comparison
/// succeeds across rebuilds. Without caching, string interpolation creates a
/// new String each build, breaking [GlobalObjectKey]'s identity-based equality.
final _bodyKeys = <String, GlobalKey>{};
GlobalKey _bodyKeyFor(String routeId) =>
    _bodyKeys.putIfAbsent(routeId, () => GlobalObjectKey(routeId));

class ChatDENTApp extends StatelessWidget {
  const ChatDENTApp({super.key});

  @override
  StatelessElement createElement() {
    PatientSide.fromHref();
    Future.delayed(const Duration(milliseconds: 1000), () {
      showDialogsIfNeeded();
    });
    return super.createElement();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: localSettings.stream,
        builder: (context, snapshot) {
          return FluentApp(
            title: "ChatDENT",
            key: WK.fluentApp,
            locale: Locale(locale.s.$code),
            theme: chatDentLightTheme(),
            darkTheme: chatDentDarkTheme(),
            themeMode: localSettings.selectedTheme,
            home: CupertinoTheme(
              data: localSettings.selectedTheme == ThemeMode.dark
                  ? const CupertinoThemeData(brightness: Brightness.dark)
                  : const CupertinoThemeData(brightness: Brightness.light),
              child: FluentTheme(
                data: localSettings.selectedTheme == ThemeMode.dark
                    ? chatDentDarkTheme()
                    : chatDentLightTheme(),
                child: MStreamBuilder(
                  streams: [
                    version.isOutdated.stream,
                    version.current.stream,
                    launch.isFirstLaunch.stream,
                    launch.open.stream,
                    routes.showBottomNav.stream,
                    routes.panels.stream,
                    routes.minimizePanels.stream
                  ],
                  builder: (BuildContext context, _) {
                    bContext = context;
                    return SafeArea(
                      top: false,
                      left: false,
                      right: false,
                      bottom: !kIsWeb && Platform.isAndroid,
                      child: ScaffoldPage(
                        padding: EdgeInsets.zero,
                        resizeToAvoidBottomInset: true,
                        content: Stack(
                          fit: StackFit.expand,
                          children: [
                            buildAppLayout(),
                            if (routes.showBottomNav() &&
                                routes.panels().isEmpty &&
                                launch.open() == Open.staff)
                              const BottomNavBar()
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        });
  }

  void showDialogsIfNeeded() async {
    await version.init();

    // Show changelog dialog when the app version changes (post-update).
    if (localSettings.lastSeenVersion != version.current() &&
        version.current() != "0.0.0" &&
        bContext.mounted) {
      final entry = await changelog.forVersion(version.current());
      localSettings.lastSeenVersion = version.current();
      localSettings.notifyAndPersist();

      if (entry != null && entry.changes.isNotEmpty && bContext.mounted) {
        showChangelogDialog(bContext, entry: entry);
      }
    }

    // Show new version dialog only on macOS — all other platforms
    // (MS Store, Play Store, App Store) handle updates automatically.
    if (version.needsUpdateNotification &&
        version.isOutdated() &&
        !launch.dialogShown() &&
        bContext.mounted) {
      launch.dialogShown(true);

      showDialog(
        barrierDismissible: true,
        dismissWithEsc: true,
        context: bContext,
        builder: (context) => NewVersionDialog(
          downloadLink: version.downloadLink,
        ),
      );
    }

    // Show first launch dialog if this is the first time the app is launched
    if (launch.isFirstLaunch() && bContext.mounted && !launch.dialogShown()) {
      launch.dialogShown(true);
      showDialog(
        barrierDismissible: true,
        dismissWithEsc: true,
        context: bContext,
        builder: (BuildContext context) => const FirstLaunchDialog(),
      );
    }
  }

  Widget buildAppLayout() {
    return MStreamBuilder(
      streams: [
        launch.open.stream,
        routes.currentRouteIndex.stream,
        routes.panels.stream
      ],
      key: WK.builder,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, __) {
          if (launch.layoutWidth < 710 &&
              routes.panels().isNotEmpty &&
              routes.minimizePanels() == false) {
            routes.minimizePanels(true);
            return;
          }
          routes.goBack();
        },
        child: LayoutBuilder(builder: (context, constraints) {
          launch.layoutWidth = constraints.maxWidth;
          final hideSidePanel =
              routes.panels().isEmpty || launch.open() != Open.staff;
          return Container(
            color: ChatDentPalette.of(context).chrome,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPositionedMainScreen(constraints, hideSidePanel, context),
                if (routes.panels().isNotEmpty &&
                    routes.minimizePanels() == false &&
                    constraints.maxWidth < 710)
                  ModalBarrier(
                    color: FluentTheme.of(context)
                        .menuColor
                        .withValues(alpha: 0.4),
                    onDismiss: () => routes.minimizePanels(true),
                  ),
                _buildPositionedPanel(context, constraints, hideSidePanel),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPositionedMainScreen(
      BoxConstraints constraints, bool hideSidePanel, BuildContext context) {
    final hasKeyboard = MediaQuery.of(context).viewInsets.bottom > 0;
    final wantBottomNav =
        launch.open() == Open.staff && constraints.maxWidth < 710;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (routes.showBottomNav() != wantBottomNav) {
        routes.showBottomNav(wantBottomNav);
      }
    });
    return AnimatedPositioned(
      duration: hasKeyboard ? Duration.zero : const Duration(milliseconds: 300),
      top: 0,
      left: locale.s.$direction == Direction.rtl ? null : 0,
      right: locale.s.$direction == Direction.rtl ? 0 : null,
      height: constraints.maxHeight,
      width: (!hideSidePanel) && constraints.maxWidth >= 710
          ? constraints.maxWidth - 355
          : constraints.maxWidth,
      child: Container(
        decoration: BoxDecoration(boxShadow: kElevationToShadow[6]),
        child: Stack(
          children: [
            NavigationView(
          clipBehavior: constraints.maxWidth <= 640 ? Clip.antiAlias : Clip.none,
          contentShape: constraints.maxWidth <= 640
              ? null
              : const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.transparent),
                  borderRadius: BorderRadius.zero,
                ),
          appBar: NavigationAppBar(
            leading: _staffAppBarLeading(constraints),
            automaticallyImplyLeading: false,
            height: 40,
            decoration: BoxDecoration(
              color: ChatDentPalette.of(context).chrome,
              boxShadow: chatDentAppBarShadow,
            ),
            actions: const NetworkActions(key: WK.globalActions),
            // ignore: prefer_const_constructors
            title: NavScreenTitle(),
          ),
          onDisplayModeChanged: (mode) {
            if (mode == PaneDisplayMode.minimal && constraints.maxWidth < 710) {
              routes.showBottomNav(true);
            } else if (constraints.maxWidth >= 710) {
              routes.showBottomNav(false);
            }
          },
          content: launch.open() == Open.login
              // ignore: prefer_const_constructors
              ? LoginScreen()
              : launch.open() == Open.patient
                  ? const PatientSideScreen()
                  : constraints.maxWidth <= 640
                      ? _staffRouteBody(constraints)
                      : null,
          pane: launch.open() == Open.staff && constraints.maxWidth > 640
              ? NavigationPane(
                  size: const NavigationPaneSize(openWidth: kSidebarOpenWidth),
                  header: null,
                  indicator: const NavigationIndicator(),
                  selected: routes.currentRouteIndex(),
                  displayMode: localSettings.sidebarCollapsed
                      ? PaneDisplayMode.compact
                      : PaneDisplayMode.open,
                  toggleable: false,
                  items: [
                    PaneItemWidgetAdapter(
                        applyPadding: false,
                        child: SizedBox(
                          // Overlay chrome covers the 40px app bar, so the pane
                          // only needs the remainder of logo + account height.
                          height: kSidebarChromeHeight - kSidebarAppBarHeight,
                          width: double.infinity,
                        ),
                      ),
                    ...routes.allRoutes.where((p) => p.onFooter != true).map(
                          (route) => PaneItem(
                            key: Key("${route.identifier}_screen_button"),
                            icon: route.accessible
                                ? Icon(route.icon, size: 18)
                                : const Icon(WindowsIcons.lock, size: 18),
                            selectedTileColor:
                                ChatDentPalette.of(context).selectedTileColor,
                            body: route.accessible
                                ? KeyedSubtree(
                                    key: _bodyKeyFor(route.identifier),
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                          bottom: (routes.showBottomNav() &&
                                                  constraints.maxWidth < 710)
                                              ? 66
                                              : 0),
                                      child: (route.screen)(),
                                    ),
                                  )
                                : const SizedBox(),
                            title: Txt(route.title),
                            trailing: null,
                            onTap: () => route.accessible
                                ? routes.navigate(route.identifier)
                                : null,
                            enabled: route.accessible,
                          ),
                        ),
                  ],
                  footerItems: [
                    ...routes.allRoutes.where((p) => p.onFooter == true).map(
                          (route) => PaneItem(
                            key: Key("${route.identifier}_screen_button"),
                            icon: Icon(route.icon, size: 18),
                            selectedTileColor:
                                ChatDentPalette.of(context).selectedTileColor,
                            body: KeyedSubtree(
                              key: _bodyKeyFor(route.identifier),
                              child: Padding(
                                padding: EdgeInsets.only(
                                    bottom: (routes.showBottomNav() &&
                                            constraints.maxWidth < 710)
                                        ? 66
                                        : 0),
                                child: (route.screen)(),
                              ),
                            ),
                            title: Txt(route.title),
                            trailing: route.identifier == 'settings'
                                ? const AppVersionLabel()
                                : null,
                            onTap: () => route.accessible
                                ? routes.navigate(route.identifier)
                                : null,
                          ),
                        ),
                  ],
                )
              : null,
            ),
            if (launch.open() == Open.staff && constraints.maxWidth > 640)
              PositionedDirectional(
                top: 0,
                start: 0,
                width: localSettings.sidebarCollapsed
                    ? kCompactNavigationPaneWidth
                    : kSidebarOpenWidth,
                child: const SidebarChrome(),
              ),
            if (launch.open() == Open.staff)
              PositionedDirectional(
                top: kSidebarAppBarHeight - 18,
                start: constraints.maxWidth > 640
                    ? (localSettings.sidebarCollapsed
                        ? kCompactNavigationPaneWidth
                        : kSidebarOpenWidth)
                    : 0,
                end: 0,
                height: 18,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color.fromRGBO(80, 80, 80, 0.175),
                          Color.fromRGBO(80, 80, 80, 0.05),
                          Color.fromRGBO(80, 80, 80, 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (launch.open() == Open.staff && constraints.maxWidth > 640)
              PositionedDirectional(
                top: 0,
                bottom: 0,
                start: (localSettings.sidebarCollapsed
                        ? kCompactNavigationPaneWidth
                        : kSidebarOpenWidth) -
                    24,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            ChatDentPalette.of(context)
                                .stone
                                .withValues(alpha: 0.0),
                            ChatDentPalette.of(context)
                                .stone
                                .withValues(alpha: 0.03),
                            ChatDentPalette.of(context)
                                .stone
                                .withValues(alpha: 0.03),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Phone/tablet compact shell: paint the selected screen in [NavigationView.content]
  /// because Fluent pane bodies stay blank in minimal mode on Android.
  Widget _staffRouteBody(BoxConstraints constraints) {
    final route = routes.currentRoute;
    return Padding(
      padding: EdgeInsets.only(
        bottom: constraints.maxWidth < 710 ? 66 : 0,
      ),
      child: route.accessible ? (route.screen)() : const SizedBox.shrink(),
    );
  }

  /// Pushes the Dashboard/Patients pill into the content app bar so it is
  /// never painted under [SidebarChrome] / the logo.
  Widget? _staffAppBarLeading(BoxConstraints constraints) {
    if (launch.open() != Open.staff) return null;
    if (constraints.maxWidth <= 640) return null;
    final sidebarWidth = localSettings.sidebarCollapsed
        ? kCompactNavigationPaneWidth
        : kSidebarOpenWidth;
    return SizedBox(width: sidebarWidth);
  }

  Widget _buildPositionedPanel(
      BuildContext context, BoxConstraints constraints, bool hideSidePanel) {
    final minimized = routes.minimizePanels() && constraints.maxWidth < 710;
    final hasKeyboard = MediaQuery.of(context).viewInsets.bottom > 0;
    return AnimatedPositioned(
      duration: hasKeyboard ? Duration.zero : const Duration(milliseconds: 300),
      width: (constraints.maxWidth < 490 && minimized)
          ? constraints.maxWidth
          : 350,
      height: minimized ? 100 : constraints.maxHeight,
      top: minimized ? null : 0,
      bottom: minimized ? -20 : null,
      left: locale.s.$direction == Direction.ltr
          ? null
          : (hideSidePanel ? -400 : 0),
      right: locale.s.$direction == Direction.ltr
          ? (hideSidePanel ? -400 : 0)
          : null,
      child: hideSidePanel
          ? const SizedBox()
          : SafeArea(
              top: minimized ? false : true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeInCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0.25, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(
                    position: slideAnimation,
                    child: child,
                  );
                },
                child: PanelScreen(
                  key: Key(routes.panels().last.identifier),
                  layoutHeight: constraints.maxHeight,
                  layoutWidth: constraints.maxWidth,
                  panel: routes.panels().last,
                ),
              ),
            ),
    );
  }
}

class NavScreenTitle extends StatefulWidget {
  const NavScreenTitle({super.key});

  @override
  State<NavScreenTitle> createState() => _NavScreenTitleState();
}

class _NavScreenTitleState extends State<NavScreenTitle> {
  final controller = FlyoutController();

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
    return FlyoutTarget(
      controller: controller,
      child: GestureDetector(
        onTap: () async {
          if (launch.open() != Open.staff) return;
          await flyoutFocusFix(context);
          controller.showFlyout(builder: (ctx) {
            return MenuFlyout(
              items: routes.allRoutes.map((route) {
                return MenuFlyoutItem(
                  leading: Icon(route.icon),
                  selected: route.identifier == routes.currentRoute.identifier,
                  text: Text(route.title),
                  onPressed: () {
                    controller.close();
                    routes.navigate(route.identifier);
                  },
                );
              }).toList(),
            );
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: launch.open() == Open.staff
                ? p.card
                : p.muted.withValues(alpha: 0.6),
            border: Border.all(
              color: p.stone.withValues(alpha: 0.1),
            ),
            boxShadow: launch.open() == Open.staff
                ? [
                    BoxShadow(
                      color: p.stone.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(
                launch.open() == Open.staff
                    ? routes.currentRoute.icon
                    : WindowsIcons.lock,
                size: 14,
                color: p.muted,
              ),
              launch.open() == Open.staff
                  ? Txt(
                      routes.currentRoute.title,
                      style: TextStyle(
                        color: p.muted,
                        fontSize: 12,
                      ),
                    )
                  : launch.open() == Open.patient
                      ? Txt(
                          txt("patientSide"),
                          style: TextStyle(
                            color: p.muted,
                            fontSize: 12,
                          ),
                        )
                      : Txt(
                          txt("login"),
                          style: TextStyle(
                            color: p.muted,
                            fontSize: 12,
                          ),
                        )
            ],
          ),
        ),
      ),
    );
  }
}
