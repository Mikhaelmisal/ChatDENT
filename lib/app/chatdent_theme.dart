import 'package:fluent_ui/fluent_ui.dart';

/// SuperDesign UI typeface (Outfit, Inter fallback in the draft).
abstract final class ChatDentFonts {
  static const String ui = 'Outfit';
}

/// Light tokens from SuperDesign draft
/// https://p.superdesign.dev/draft/d2eacc10-0fc4-4234-be6e-04ed61704a8a
abstract final class ChatDentColors {
  static const Color canvas = Color(0xFFFDFCF8);
  static const Color chrome = Color(0xFFF5F3EE);
  static const Color card = Color(0xFFFFFFFF);
  static const Color stone = Color(0xFF292524);
  static const Color muted = Color(0xFF78716C);
  static const Color border = Color(0xFFE7E5E4);
  static const Color fluentBlue = Color(0xFF0078D4);
  static const Color error = Color(0xFFB42318);
  static const Color online = Color(0xFF0F766E);

  static const Color purpleAccent = Color(0x33800080);
  static const Color blueAccent = Color(0x330078D4);
  static const Color tealAccent = Color(0x33008080);
  static const Color amberAccent = Color(0x33EA580C);

  static const Color purpleIcon = Color(0xFF6B21A8);
  static const Color purpleText = Color(0xFF581C87);
  static const Color purpleLabel = Color(0xFF6B21A8);

  static const Color blueIcon = Color(0xFF1D4ED8);
  static const Color blueText = Color(0xFF1E3A8A);
  static const Color blueLabel = Color(0xFF1E40AF);

  static const Color tealIcon = Color(0xFF0F766E);
  static const Color tealText = Color(0xFF134E4A);
  static const Color tealLabel = Color(0xFF115E59);

  static const Color amberIcon = Color(0xFFC2410C);
  static const Color amberText = Color(0xFF9A3412);
  static const Color amberLabel = Color(0xFFC2410C);
}

/// Theme-aware palette. Use [ChatDentPalette.of] in widgets so dark mode
/// actually paints chrome, canvas, and text — not only the Fluent pane.
class ChatDentPalette {
  const ChatDentPalette({
    required this.isDark,
    required this.canvas,
    required this.chrome,
    required this.card,
    required this.stone,
    required this.muted,
    required this.border,
    required this.fluentBlue,
    required this.error,
    required this.online,
    required this.emptyFill,
    required this.onLogout,
    required this.logout,
    required this.logoutHover,
    required this.logoutPressed,
    required this.purpleAccent,
    required this.blueAccent,
    required this.tealAccent,
    required this.amberAccent,
    required this.purpleIcon,
    required this.purpleText,
    required this.purpleLabel,
    required this.blueIcon,
    required this.blueText,
    required this.blueLabel,
    required this.tealIcon,
    required this.tealText,
    required this.tealLabel,
    required this.amberIcon,
    required this.amberText,
    required this.amberLabel,
  });

  final bool isDark;
  final Color canvas;
  final Color chrome;
  final Color card;
  final Color stone;
  final Color muted;
  final Color border;
  final Color fluentBlue;
  final Color error;
  final Color online;
  final Color emptyFill;
  final Color onLogout;
  final Color logout;
  final Color logoutHover;
  final Color logoutPressed;
  final Color purpleAccent;
  final Color blueAccent;
  final Color tealAccent;
  final Color amberAccent;
  final Color purpleIcon;
  final Color purpleText;
  final Color purpleLabel;
  final Color blueIcon;
  final Color blueText;
  final Color blueLabel;
  final Color tealIcon;
  final Color tealText;
  final Color tealLabel;
  final Color amberIcon;
  final Color amberText;
  final Color amberLabel;

  static const light = ChatDentPalette(
    isDark: false,
    canvas: ChatDentColors.canvas,
    chrome: ChatDentColors.chrome,
    card: ChatDentColors.card,
    stone: ChatDentColors.stone,
    muted: ChatDentColors.muted,
    border: ChatDentColors.border,
    fluentBlue: ChatDentColors.fluentBlue,
    error: ChatDentColors.error,
    online: ChatDentColors.online,
    emptyFill: Color(0xFFF3F4F6),
    onLogout: ChatDentColors.card,
    logout: ChatDentColors.muted,
    logoutHover: Color(0xFF57534E),
    logoutPressed: ChatDentColors.stone,
    purpleAccent: ChatDentColors.purpleAccent,
    blueAccent: ChatDentColors.blueAccent,
    tealAccent: ChatDentColors.tealAccent,
    amberAccent: ChatDentColors.amberAccent,
    purpleIcon: ChatDentColors.purpleIcon,
    purpleText: ChatDentColors.purpleText,
    purpleLabel: ChatDentColors.purpleLabel,
    blueIcon: ChatDentColors.blueIcon,
    blueText: ChatDentColors.blueText,
    blueLabel: ChatDentColors.blueLabel,
    tealIcon: ChatDentColors.tealIcon,
    tealText: ChatDentColors.tealText,
    tealLabel: ChatDentColors.tealLabel,
    amberIcon: ChatDentColors.amberIcon,
    amberText: ChatDentColors.amberText,
    amberLabel: ChatDentColors.amberLabel,
  );

  static const dark = ChatDentPalette(
    isDark: true,
    canvas: Color(0xFF1C1917),
    chrome: Color(0xFF292524),
    card: Color(0xFF211E1C),
    stone: Color(0xFFF5F3EE),
    muted: Color(0xFFA8A29E),
    border: Color(0xFF44403C),
    fluentBlue: Color(0xFF4FC3F7),
    error: Color(0xFFF97066),
    online: Color(0xFF2DD4BF),
    emptyFill: Color(0xFF35302C),
    onLogout: Color(0xFFF5F3EE),
    logout: Color(0xFF57534E),
    logoutHover: Color(0xFF78716C),
    logoutPressed: Color(0xFF44403C),
    purpleAccent: Color(0x554C1D6B),
    blueAccent: Color(0x551E3A8A),
    tealAccent: Color(0x5511554E),
    amberAccent: Color(0x557C2D12),
    purpleIcon: Color(0xFFE9D5FF),
    purpleText: Color(0xFFF3E8FF),
    purpleLabel: Color(0xFFD8B4FE),
    blueIcon: Color(0xFF7DD3FC),
    blueText: Color(0xFFE0F2FE),
    blueLabel: Color(0xFF7DD3FC),
    tealIcon: Color(0xFF5EEAD4),
    tealText: Color(0xFFCCFBF1),
    tealLabel: Color(0xFF5EEAD4),
    amberIcon: Color(0xFFFDBA74),
    amberText: Color(0xFFFFEDD5),
    amberLabel: Color(0xFFFDBA74),
  );

  static ChatDentPalette of(BuildContext context) {
    return FluentTheme.of(context).brightness == Brightness.dark
        ? dark
        : light;
  }

  WidgetStateProperty<Color?> get selectedTileColor => WidgetStatePropertyAll(
        fluentBlue.withValues(alpha: isDark ? 0.22 : 0.1),
      );
}

FluentThemeData chatDentLightTheme() {
  const p = ChatDentPalette.light;
  final base = FluentThemeData.light();
  return base.copyWith(
    accentColor: Colors.blue,
    scaffoldBackgroundColor: p.canvas,
    micaBackgroundColor: p.chrome,
    acrylicBackgroundColor: p.chrome,
    menuColor: p.chrome,
    cardColor: p.card,
    shadowColor: p.stone.withValues(alpha: 0.2),
    inactiveColor: p.muted,
    inactiveBackgroundColor: p.chrome,
    typography: base.typography.apply(
      fontFamily: ChatDentFonts.ui,
      displayColor: p.stone,
    ),
    iconTheme: IconThemeData(color: p.stone, size: 18),
    dialogTheme: chatDentDialogTheme(p),
    navigationPaneTheme: NavigationPaneThemeData(
      backgroundColor: p.chrome,
      overlayBackgroundColor: p.chrome,
      highlightColor: const Color(0x00000000),
      selectedIconColor: WidgetStatePropertyAll(p.fluentBlue),
      unselectedIconColor: WidgetStatePropertyAll(p.stone),
      selectedTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: ChatDentFonts.ui,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.fluentBlue,
        ),
      ),
      unselectedTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: ChatDentFonts.ui,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: p.stone,
        ),
      ),
      tileColor: WidgetStateProperty.resolveWith((states) {
        if (states.isPressed) {
          return p.stone.withValues(alpha: 0.08);
        }
        if (states.isHovered) {
          return p.stone.withValues(alpha: 0.05);
        }
        return Colors.transparent;
      }),
      iconPadding: const EdgeInsets.symmetric(horizontal: 10),
      labelPadding: const EdgeInsetsDirectional.only(end: 10),
    ),
  );
}

FluentThemeData chatDentDarkTheme() {
  const p = ChatDentPalette.dark;
  final base = FluentThemeData.dark();
  return base.copyWith(
    accentColor: Colors.blue,
    scaffoldBackgroundColor: p.canvas,
    micaBackgroundColor: p.chrome,
    acrylicBackgroundColor: p.chrome,
    menuColor: p.chrome,
    cardColor: p.card,
    shadowColor: Colors.black.withValues(alpha: 0.45),
    inactiveColor: p.muted,
    inactiveBackgroundColor: p.chrome,
    typography: base.typography.apply(
      fontFamily: ChatDentFonts.ui,
      displayColor: p.stone,
    ),
    iconTheme: IconThemeData(color: p.stone, size: 18),
    dialogTheme: chatDentDialogTheme(p),
    navigationPaneTheme: NavigationPaneThemeData(
      backgroundColor: p.chrome,
      overlayBackgroundColor: p.chrome,
      highlightColor: const Color(0x00000000),
      selectedIconColor: WidgetStatePropertyAll(p.fluentBlue),
      unselectedIconColor: WidgetStatePropertyAll(p.stone),
      selectedTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: ChatDentFonts.ui,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.fluentBlue,
        ),
      ),
      unselectedTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: ChatDentFonts.ui,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: p.stone,
        ),
      ),
      tileColor: WidgetStateProperty.resolveWith((states) {
        if (states.isPressed) {
          return Colors.white.withValues(alpha: 0.10);
        }
        if (states.isHovered) {
          return Colors.white.withValues(alpha: 0.06);
        }
        return Colors.transparent;
      }),
      iconPadding: const EdgeInsets.symmetric(horizontal: 10),
      labelPadding: const EdgeInsetsDirectional.only(end: 10),
    ),
  );
}

ContentDialogThemeData chatDentDialogTheme(ChatDentPalette p) {
  return ContentDialogThemeData(
    decoration: BoxDecoration(
      color: p.card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: p.border),
    ),
    actionsDecoration: BoxDecoration(
      color: p.chrome,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
    ),
    titleStyle: TextStyle(
      fontFamily: ChatDentFonts.ui,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: p.stone,
    ),
    bodyStyle: TextStyle(
      fontFamily: ChatDentFonts.ui,
      fontSize: 13,
      color: p.stone,
    ),
    barrierColor: p.isDark
        ? const Color.fromRGBO(0, 0, 0, 0.55)
        : p.stone.withValues(alpha: 0.28),
  );
}

List<BoxShadow> chatDentPopupShadow(ChatDentPalette p) => [
      BoxShadow(
        offset: const Offset(0, 10),
        blurRadius: 28,
        spreadRadius: 0,
        color: p.isDark
            ? const Color.fromRGBO(0, 0, 0, 0.55)
            : const Color.fromRGBO(41, 37, 36, 0.14),
      ),
    ];

BoxDecoration chatDentPopupCard(ChatDentPalette p, {double radius = 8}) {
  return BoxDecoration(
    color: p.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: p.border),
    boxShadow: chatDentPopupShadow(p),
  );
}

BoxDecoration chatDentInnerCard(ChatDentPalette p, {double radius = 8}) {
  return BoxDecoration(
    color: p.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: p.border),
  );
}

BoxDecoration chatDentFieldFill(ChatDentPalette p) {
  return BoxDecoration(
    color: p.isDark ? p.canvas : p.card,
    borderRadius: BorderRadius.circular(5),
    border: Border.all(color: p.border),
  );
}

List<BoxShadow> get chatDentAppBarShadow => [
      const BoxShadow(
        offset: Offset(0, 4),
        blurRadius: 14,
        spreadRadius: 0,
        color: Color.fromRGBO(41, 37, 36, 0.16),
      ),
    ];

List<BoxShadow> get chatDentCommandBarShadow => [
      const BoxShadow(
        offset: Offset(0, 6),
        blurRadius: 30,
        spreadRadius: 5,
        color: Color.fromRGBO(128, 128, 128, 0.5),
      ),
      const BoxShadow(
        offset: Offset(0, 2),
        blurRadius: 8,
        spreadRadius: 0,
        color: Color.fromRGBO(41, 37, 36, 0.12),
      ),
    ];

/// CSS `0 6px 15px 5px` colored glow from SuperDesign, plus a wider
/// second layer so Windows actually paints the diffuse halo.
List<BoxShadow> chatDentStatShadow(Color color) => [
      BoxShadow(
        offset: const Offset(0, 6),
        blurRadius: 18,
        spreadRadius: 4,
        color: color.withValues(alpha: 0.28),
      ),
      BoxShadow(
        offset: const Offset(0, 12),
        blurRadius: 32,
        spreadRadius: 2,
        color: color.withValues(alpha: 0.16),
      ),
    ];
