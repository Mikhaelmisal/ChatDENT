import 'package:chatdent/common_widgets/dialogs/close_dialog_button.dart';
import 'package:chatdent/common_widgets/dialogs/dialog_styling.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class FirstLaunchDialog extends StatelessWidget {
  const FirstLaunchDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Txt(txt("firstLaunchDialogTitle")),
          IconButton(
              icon: const Icon(WindowsIcons.cancel),
              onPressed: () => Navigator.pop(context))
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Txt(txt("firstLaunchDialogContent")),
        ],
      ),
      style: dialogStyling(context, false),
      actions: const [CloseButtonInDialog(buttonText: "close")],
    );
  }
}
