import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/common_widgets/dialogs/changelog_dialog.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

String savedVersion = "";

/// Logo + app name at the top of the expanded sidebar (no version).
class AppLogo extends StatefulWidget {
  /// Kept so hot reload does not reject a constructor-field change.
  final bool collapseToPlaceholder;

  const AppLogo({super.key, this.collapseToPlaceholder = false});

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> {
  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
    final textStyle = TextStyle(
      fontFamily: ChatDentFonts.ui,
      color: p.muted.withValues(alpha: 0.8),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    return Align(
      key: WK.appLogo,
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                "assets/images/logo.png",
                height: 50,
              ),
              const SizedBox(width: 8),
              Text("ChatDENT", style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Version under Settings. Hidden when the sidebar is collapsed.
class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({super.key});

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  String version = savedVersion;

  @override
  void initState() {
    super.initState();
    if (version.isEmpty) {
      PackageInfo.fromPlatform().then((p) {
        if (mounted) {
          setState(() {
            version = p.version;
            savedVersion = p.version;
          });
        }
      }).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (version.isEmpty) return const SizedBox.shrink();
    final style = TextStyle(
      fontFamily: ChatDentFonts.ui,
      color: ChatDentPalette.of(context).muted,
      fontSize: 10,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => showChangelogDialog(context),
        child: Text('v$version', style: style),
      ),
    );
  }
}
