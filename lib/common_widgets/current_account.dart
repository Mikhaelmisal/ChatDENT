import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/common_widgets/logo.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../services/login.dart';

const double kSidebarAppBarHeight = 40;
const double kSidebarOpenWidth = 210;
const double kSidebarLogoHeight = 62;
const double kSidebarAccountHeight = 48;
const double kSidebarChromeHeight = kSidebarLogoHeight + kSidebarAccountHeight;

/// Logo + ☰ row painted over a fixed pane spacer so nav icons never jump.
class SidebarChrome extends StatelessWidget {
  const SidebarChrome({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: localSettings.stream,
      builder: (context, _) {
        final collapsed = localSettings.sidebarCollapsed;
        return ColoredBox(
          color: ChatDentPalette.of(context).chrome,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: kSidebarLogoHeight,
                child: collapsed
                    ? const Center(child: SidebarCollapsedLogo())
                    : const AppLogo(),
              ),
              const CurrentAccount(),
            ],
          ),
        );
      },
    );
  }
}

/// Same slot as pane icons: 6px tile margin, 36px cell, 16px glyph.
class SidebarIconSlot extends StatelessWidget {
  final Widget child;

  const SidebarIconSlot({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: SizedBox(
        width: 36,
        height: kPaneItemMinHeight,
        child: Center(child: child),
      ),
    );
  }
}

/// Tooth mark — closed sidebar, sized to the pane icon card (40px).
class SidebarCollapsedLogo extends StatelessWidget {
  const SidebarCollapsedLogo({super.key});

  static const double size = 32;

  @override
  Widget build(BuildContext context) {
    return const Image(
      image: AssetImage('assets/images/logo.png'),
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

class SidebarToggleButton extends StatelessWidget {
  const SidebarToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final collapsed = localSettings.sidebarCollapsed;
    return Tooltip(
      message: collapsed ? txt('expandSidebar') : txt('collapseSidebar'),
      child: SidebarIconSlot(
        child: HoverButton(
          onPressed: () {
            localSettings.sidebarCollapsed = !localSettings.sidebarCollapsed;
            localSettings.notifyAndPersist();
          },
          builder: (context, states) {
            final hovered = states.isHovered || states.isPressed;
            final p = ChatDentPalette.of(context);
            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hovered
                    ? p.stone.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                FluentIcons.global_nav_button,
                size: 16,
                color: p.stone,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Open sidebar: ☰, then name — matches draft account row.
class CurrentAccount extends StatelessWidget {
  const CurrentAccount({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: localSettings.stream,
      builder: (context, _) {
        final collapsed = localSettings.sidebarCollapsed;
        return SizedBox(
          height: kSidebarAccountHeight,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SidebarToggleButton(),
                if (!collapsed) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Txt(
                      login.currentName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: ChatDentFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ChatDentPalette.of(context).stone,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
    return Button(
      key: WK.btnLogout,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.isPressed) return p.logoutPressed;
          if (states.isHovered) return p.logoutHover;
          return p.logout;
        }),
        foregroundColor: WidgetStatePropertyAll(p.onLogout),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
      onPressed: () {
        login.logout(false);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.sign_out, size: 14, color: p.onLogout),
          const SizedBox(width: 6),
          Txt(
            txt("logout"),
            style: TextStyle(fontSize: 13, color: p.onLogout),
          ),
        ],
      ),
    );
  }
}
