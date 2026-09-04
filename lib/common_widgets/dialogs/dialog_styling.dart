import 'package:chatdent/app/chatdent_theme.dart';
import 'package:fluent_ui/fluent_ui.dart';

ContentDialogThemeData dialogStyling(BuildContext context, bool danger,
    [bool withLowerPadding = false]) {
  final p = ChatDentPalette.of(context);
  final base = chatDentDialogTheme(p);
  return ContentDialogThemeData(
    decoration: base.decoration,
    actionsDecoration: BoxDecoration(
      color: p.chrome,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      boxShadow: [
        BoxShadow(
          color: (danger ? p.error : p.stone).withValues(alpha: 0.18),
          blurRadius: 10,
          spreadRadius: 1,
          offset: const Offset(0, 1),
        )
      ],
    ),
    titleStyle: base.titleStyle,
    bodyStyle: base.bodyStyle,
    barrierColor: base.barrierColor,
    padding: EdgeInsets.fromLTRB(20, 20, 20, withLowerPadding ? 20 : 0),
  );
}
