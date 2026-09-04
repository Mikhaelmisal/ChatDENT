import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

class ScreenCommandBar extends StatelessWidget {
  const ScreenCommandBar({
    super.key,
    required this.mainButton,
    this.otherButtons = const [],
    this.farItems = const [],
  });

  final Widget mainButton;
  final List<Widget> otherButtons;
  final List<Widget> farItems;

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(
          color: p.card,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 8,
                      children: [
                        mainButton,
                        Container(
                          width: 1,
                          height: 20,
                          color: p.stone.withValues(alpha: 0.12),
                        ),
                        ...otherButtons
                      ],
                    ),
                  ),
                ),
                if (farItems.isNotEmpty)
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        spacing: 5,
                        children: [...farItems],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IgnorePointer(
          child: SizedBox(
            height: 18,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color.fromRGBO(80, 80, 80, 0.175),
                    const Color.fromRGBO(80, 80, 80, 0.05),
                    const Color.fromRGBO(80, 80, 80, 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

BoxDecoration topBarDecoration(BuildContext context, Color color) {
  final p = ChatDentPalette.of(context);
  return BoxDecoration(
    border: BorderDirectional(
      bottom: BorderSide(
        color: p.stone.withValues(alpha: 0.12),
      ),
    ),
    gradient: LinearGradient(
      colors: [
        Colors.transparent,
        p.stone.withValues(alpha: 0.05),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

Border listDividerBorder(BuildContext context) {
  final p = ChatDentPalette.of(context);
  return Border(
    bottom: BorderSide(
      color: p.stone.withValues(alpha: 0.12),
      width: 1,
    ),
  );
}

class TopSearch extends StatelessWidget {
  final TextEditingController controller;
  final void Function(void Function()) setState;
  const TopSearch({
    super.key,
    required this.controller,
    required this.setState,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.transparent)),
      placeholder: txt("searchPlaceholder"),
      placeholderStyle: TextStyle(
          fontSize: 18,
          color: FluentTheme.of(context).inactiveColor.withAlpha(140)),
      prefix: const Text(
        "🔍",
        style: TextStyle(fontSize: 18),
      ),
      controller: controller,
      onChanged: (text) => setState(() {}),
      suffix: controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(
                WindowsIcons.clear,
                size: 20,
              ),
              onPressed: () {
                controller.clear();
                setState(() {});
              })
          : null,
    );
  }
}
