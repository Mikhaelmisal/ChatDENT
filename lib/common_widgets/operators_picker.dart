import 'package:chatdent/features/accounts/accounts_controller.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/common_widgets/tag_input.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';

class OperatorsPicker extends StatelessWidget {
  final List<String> value;
  final void Function(List<String>) onChanged;
  const OperatorsPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TagInputWidget(
      enabled: login.perm(Perm.appointments).exact(1) || login.perm(Perm.patients).exact(1) ? false : true,
      key: WK.fieldOperators,
      suggestions: accounts.operators.map((account) => TagInputItem(value: account.id, label: accounts.name(account))).toList(),
      onChanged: (s) {
        onChanged(s.where((x) => x.value != null).map((x) => x.value!).toList());
      },
      initialValue: value.map((id) => TagInputItem(value: id, label: accounts.nameOrEmailFromID(id))).toList(),
      strict: true,
      limit: 999,
      placeholder: txt("selectDoctors"),
    );
  }
}
