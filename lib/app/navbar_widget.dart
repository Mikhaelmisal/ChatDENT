import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/app/routes.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/utils/flyout_focus_fix.dart';
import 'package:fluent_ui/fluent_ui.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
    return Positioned(
      bottom: 0,
      height: 66,
      width: MediaQuery.of(context).size.width,
      child: Container(
        decoration: BoxDecoration(
          color: p.chrome,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0.0, -2.0),
              blurRadius: 15.0,
              spreadRadius: 1.0,
              color: p.stone.withValues(alpha: 0.05),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: p.border,
              width: 0.5,
            ),
          ),
        ),
        child: StreamBuilder(
          stream: routes.currentRouteIndex.stream,
          builder: (context, snapshot) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final allRoutes = routes.allRoutes;
                final int totalRoutes = allRoutes.length;

                const double minItemWidth = 52.0;
                int maxVisibleItems = (availableWidth / minItemWidth).floor();

                var visibleRoutes = allRoutes;
                var overflowRoutes = [];
                bool showMore = false;

                if (maxVisibleItems < totalRoutes) {
                  showMore = true;
                  int visibleCount = maxVisibleItems - 1;
                  if (visibleCount < 1) visibleCount = 1;

                  visibleRoutes = allRoutes.sublist(0, visibleCount);
                  overflowRoutes = allRoutes.sublist(visibleCount);
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...visibleRoutes.map((r) => Expanded(
                          child: BottomNavBarButton(
                            icon: r.icon,
                            identifier: r.identifier,
                            title: r.navbarTitle,
                            active:
                                r.identifier == routes.currentRoute.identifier,
                          ),
                        )),
                    if (showMore)
                      Container(
                        width: 1,
                        height: 24,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 16),
                        color: ChatDentPalette.of(context)
                            .border
                            .withValues(alpha: 0.5),
                      ),
                    if (showMore)
                      Expanded(
                        child: BottomNavBarMoreButton(
                          overflowRoutes: overflowRoutes,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class BottomNavBarButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final String identifier;
  final bool active;
  const BottomNavBarButton({
    super.key,
    required this.title,
    required this.icon,
    required this.identifier,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
    final color = active ? p.fluentBlue : p.muted;

    return HoverButton(
      onPressed: () => routes.navigate(identifier),
      builder: (context, states) {
        final isHovered = states.isHovered;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutQuint,
          decoration: BoxDecoration(
            color: active
                ? p.fluentBlue.withValues(alpha: 0.1)
                : (isHovered
                    ? p.stone.withValues(alpha: 0.08)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: states.isPressed ? 0.9 : (active ? 1.1 : 1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                    child: Text(title),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BottomNavBarMoreButton extends StatefulWidget {
  final List overflowRoutes;
  const BottomNavBarMoreButton({super.key, required this.overflowRoutes});

  @override
  State<BottomNavBarMoreButton> createState() => _BottomNavBarMoreButtonState();
}

class _BottomNavBarMoreButtonState extends State<BottomNavBarMoreButton> {
  final bottomNavFlyoutController = FlyoutController();

  @override
  void dispose() {
    bottomNavFlyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
    final isActive = widget.overflowRoutes
        .any((r) => r.identifier == routes.currentRoute.identifier);
    final color = isActive ? p.fluentBlue : p.muted;

    return FlyoutTarget(
      controller: bottomNavFlyoutController,
      child: HoverButton(
        onPressed: () async {
          await flyoutFocusFix(null);
          bottomNavFlyoutController.showFlyout(
            autoModeConfiguration: FlyoutAutoConfiguration(
              preferredMode: FlyoutPlacementMode.topCenter,
            ),
            barrierColor: Colors.transparent,
            builder: (context) {
              return MenuFlyout(
                items: widget.overflowRoutes.map((r) {
                  final isItemActive =
                      r.identifier == routes.currentRoute.identifier;
                  return MenuFlyoutItem(
                    text: Text(
                      r.navbarTitle,
                      style: TextStyle(
                        fontWeight:
                            isItemActive ? FontWeight.bold : FontWeight.normal,
                        color: isItemActive ? p.fluentBlue : null,
                      ),
                    ),
                    leading: Icon(
                      r.icon,
                      color: isItemActive ? p.fluentBlue : null,
                    ),
                    onPressed: () {
                      routes.navigate(r.identifier);
                      Flyout.of(context).close();
                    },
                  );
                }).toList(),
              );
            },
          );
        },
        builder: (context, states) {
          final isHovered = states.isHovered;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuint,
            decoration: BoxDecoration(
              color: isActive
                  ? p.fluentBlue.withValues(alpha: 0.1)
                  : (isHovered
                      ? p.stone.withValues(alpha: 0.08)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: states.isPressed ? 0.9 : (isActive ? 1.1 : 1.0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    WindowsIcons.more,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                        color: color,
                      ),
                      child: Text(txt("more")),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
