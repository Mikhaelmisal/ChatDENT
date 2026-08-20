import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class NoItemsFound extends StatelessWidget {
  const NoItemsFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: InfoBar(
          style: InfoBarThemeData(
            decoration: (severity) {
              return BoxDecoration(
                color: FluentTheme.of(context).cardColor,
                border: Border.all(color: Colors.grey.withAlpha(50)),
                borderRadius: BorderRadius.circular(10),
              );
            },
          ),
          isIconVisible: true,
          severity: InfoBarSeverity.warning,
          title: Txt(txt("noItemsFound")),
        ),
      ),
    );
  }
}
