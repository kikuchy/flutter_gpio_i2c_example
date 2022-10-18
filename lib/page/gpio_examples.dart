import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gpiod/flutter_gpiod.dart';

import 'commons.dart';

class GpioPage extends StatefulWidget {
  const GpioPage({super.key});

  @override
  State<GpioPage> createState() => _GpioPageState();
}

class _GpioPageState extends State<GpioPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GPIO status list"),
      ),
      body: ListView.builder(
        itemCount: chip.lines.length,
        itemBuilder: (context, i) {
          final line = chip.lines[i];
          return ListTile(
            title: Text("Line $i: ${line.info.name}"),
            subtitle: Text(
                "${line.info.direction}, ${line.info.activeState}, isUsed: ${line.info.isUsed}"),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case "S":
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SwitchPage(
                          pinNo: i,
                        ),
                      ),
                    );
                    break;
                  case "L":
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LchikaPage(pinNo: i),
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem(
                  value: "S",
                  child: Text("Switch"),
                ),
                const PopupMenuItem(
                  value: "L",
                  child: Text("L chika"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SwitchPage extends StatefulWidget {
  const SwitchPage({required this.pinNo, Key? key}) : super(key: key);

  final int pinNo;

  @override
  State<SwitchPage> createState() => _SwitchPageState();
}

class _SwitchPageState extends State<SwitchPage> {
  StreamSubscription? _subscription;
  SignalEdge _lastEdge = SignalEdge.falling;

  String get _stateLabel => _lastValue ? "waiting..." : "CONNECTED!!";
  bool _lastValue = false;
  late final GpioLine _line;

  @override
  void initState() {
    super.initState();

    _line = chip.lines[widget.pinNo];
    try {
      _line.release();
    } catch (e) {
      print(e);
    }
    _line.requestInput(
      consumer: "flutter_gpiod input test",
      bias: Bias.pullUp,
      triggers: const {SignalEdge.rising, SignalEdge.falling},
    );
    print("lines[7]: ${_line.getValue()}");
    _subscription = _line.onEvent.listen((data) {
      final signal = data.edge;
      setState(() {
        _lastEdge = signal;
        _lastValue = _line.getValue();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _line.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Switch Page"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _stateLabel,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class LchikaPage extends StatefulWidget {
  const LchikaPage({required this.pinNo, super.key});

  final int pinNo;

  @override
  _LchikaPageState createState() => _LchikaPageState();
}

class _LchikaPageState extends State<LchikaPage> {
  bool pinValue = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();

    final pin = chip.lines[widget.pinNo];
    pin.requestOutput(consumer: "L chika", initialValue: pinValue);
    pin.setValue(pinValue);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        pinValue = !pin.getValue();
      });
      pin.setValue(pinValue);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    final pin = chip.lines[widget.pinNo];
    pin.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("L chika"),
      ),
      body: Center(
        child: Column(
          children: [
            Text("Pin value: $pinValue"),
          ],
        ),
      ),
    );
  }
}
