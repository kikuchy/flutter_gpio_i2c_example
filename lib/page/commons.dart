import 'package:flutter_gpiod/flutter_gpiod.dart';

final chip = FlutterGpiod.instance.chips.singleWhere(
      (chip) => chip.label == 'pinctrl-bcm2711',
  orElse: () => FlutterGpiod.instance.chips
      .singleWhere((chip) => chip.label == 'pinctrl-bcm2835'),
);

class HistoryData<T> {
  HistoryData(this.data) : time = DateTime.now();
  final T data;
  final DateTime time;
}