import 'dart:async';
import 'dart:math';

import 'package:dart_periphery/dart_periphery.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpiod/flutter_gpiod.dart';
import 'package:hello/i2c_device/ccs811.dart';
import 'package:image/image.dart' as image;

import '../i2c_device/ssd1306.dart';
import 'commons.dart';

enum OledViewState {
  graph,
  numeric,
}

class LimitedList<T> {
  LimitedList(this.capacity);

  final int capacity;
  List<T> _buffer = [];

  List<T> get list => _buffer;

  void add(T value) {
    if (_buffer.length == capacity) {
      _buffer = _buffer.sublist(1);
    }
    _buffer.add(value);
  }

  Iterable<U> map<U>(U Function(T) toElement) => _buffer.map(toElement);

  T get last => _buffer.last;

  T operator [](int index) => _buffer[index];

  void operator []=(int index, T value) {
    if (index >= capacity - 1) {
      throw RangeError.range(index, 0, capacity - 1);
    }
    _buffer[index] = value;
  }
}

class Blinker {
  Blinker(this._led, this._blinkingInterval);

  final GpioLine _led;
  final Duration _blinkingInterval;
  Timer? _timer;

  void startBlinking() {
    _timer = Timer.periodic(
      _blinkingInterval,
      (timer) {
        _led.setValue(!_led.getValue());
      },
    );
  }

  void stopBlinking() {
    _timer?.cancel();
    _led.setValue(false);
  }

  void dispose() {
    stopBlinking();
  }
}

class Co2Censor {
  Co2Censor(I2C i2c, this._checkingInterval) : _ccs811 = Ccs811(i2c) {
    void setupTimer() {
      try {
        _timer = Timer.periodic(_checkingInterval, (_) {
          _controller.add(_ccs811.eco2);
        });
      } catch (e) {
        _timer.cancel();
        setupTimer();
      }
    }

    setupTimer();
  }

  final Ccs811 _ccs811;
  final Duration _checkingInterval;
  late final Timer _timer;
  final StreamController<int> _controller = StreamController();

  Stream<int> get onValue => _controller.stream;

  void dispose() {
    _timer.cancel();
    _controller.close();
  }
}

class Oled {
  Oled(I2C i2c, this._width, this._height)
      : _ssd1306 = Ssd1306(
          i2c: i2c,
          width: _width,
          height: _height,
        );

  final Ssd1306 _ssd1306;
  final int _width;
  final int _height;
  image.BitmapFont? _font;

  Future<image.BitmapFont> _inconsolata() async {
    if (_font == null) {
      final f = await rootBundle.load("assets/Inconsolata.zip");
      _font = image.BitmapFont.fromZip(f.buffer.asUint8List());
    }
    return _font!;
  }

  void showGraph(List<int> data) {
    final minValue = data.reduce(min);
    final maxValue = data.reduce(max);
    final range = maxValue - minValue;
    final threshold = (range / (_height - 1)).ceil();
    _ssd1306.fill(0);
    for (int i = 0; i < min(data.length, _width); i++) {
      final h = threshold > 0 ? (data[i] - minValue) ~/ threshold : 0;
      final y = _height - 1 - h;
      final x = _width - 1 - i;
      _ssd1306.setPixel(x, y, 1);
    }
    _ssd1306.show();
  }

  Future<void> showLastData(int data) async {
    final canvas = image.drawString(
      image.fill(
        image.Image(_width, _height),
        0x00000000,
      ),
      await _inconsolata(),
      0,
      0,
      "CO2: $data PPM",
    );
    for (int x = 0; x < canvas.width; x++) {
      for (int y = 0; y < canvas.height; y++) {
        _ssd1306.setPixel(x, y, canvas.getPixel(x, y) > 0 ? 1 : 0);
      }
    }
    _ssd1306.show();
  }
}

class ComprehensivePage extends StatefulWidget {
  const ComprehensivePage({Key? key}) : super(key: key);

  @override
  State<ComprehensivePage> createState() => _ComprehensivePageState();
}

class _ComprehensivePageState extends State<ComprehensivePage> {
  static const oledHeight = 32;
  static const oledWidth = 128;
  static const historyCapacity = oledWidth;
  static const tactSwitchPinNo = 20;
  static const ledPinNo = 26;

  OledViewState _oledViewState = OledViewState.graph;
  final LimitedList<HistoryData<int>> _co2Histories =
      LimitedList(historyCapacity);
  StreamSubscription? _tactSwitchSubscription;
  late final Blinker _ledBlinker;
  late final I2C _i2c;
  late final Co2Censor _co2censor;
  StreamSubscription? _co2CensorSubscription;
  late final Oled _oled;

  GpioLine get _tactSwitch => chip.lines[tactSwitchPinNo];

  GpioLine get _led => chip.lines[ledPinNo];

  @override
  void initState() {
    super.initState();
    _initTactSwitch();
    _initLed();
    _i2c = I2C(1);
    _initCo2Censor(_i2c);
    _initOled(_i2c);
  }

  void _initLed() {
    _led.requestOutput(
      consumer: "Danger CO2 signal",
      initialValue: false,
    );
    _ledBlinker = Blinker(_led, const Duration(milliseconds: 700));
  }

  void _initTactSwitch() {
    _tactSwitch.requestInput(
      consumer: "OLED mode switch",
      bias: Bias.pullUp,
      triggers: {SignalEdge.rising},
    );
    _tactSwitchSubscription = _tactSwitch.onEvent.listen((event) {
      if (event.edge == SignalEdge.rising) {
        print(event);
        _flipOledViewState();
      }
    });
  }

  void _initCo2Censor(I2C i2c) {
    _co2censor = Co2Censor(i2c, const Duration(seconds: 1));
    _co2CensorSubscription = _co2censor.onValue.listen((co2) {
      setState(() {
        _co2Histories.add(HistoryData(co2));
      });
      switch (_oledViewState) {
        case OledViewState.graph:
          _oled.showGraph(_co2Histories.list.map((e) => e.data).toList());
          break;
        case OledViewState.numeric:
          _oled.showLastData(_co2Histories.last.data);
          break;
      }
      if (co2 >= 1000) {
        _ledBlinker.startBlinking();
      } else {
        _ledBlinker.stopBlinking();
      }
    });
  }

  void _initOled(I2C i2c) {
    _oled = Oled(i2c, oledWidth, oledHeight);
  }

  void _flipOledViewState() {
    final currentState = _oledViewState;
    setState(() {
      switch (currentState) {
        case OledViewState.numeric:
          _oledViewState = OledViewState.graph;
          break;
        case OledViewState.graph:
          _oledViewState = OledViewState.numeric;
          break;
      }
    });
  }

  @override
  void dispose() {
    _co2CensorSubscription?.cancel();
    _co2censor.dispose();
    _i2c.dispose();
    _ledBlinker.dispose();
    _led.release();
    _tactSwitchSubscription?.cancel();
    _tactSwitch.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Comprehensive Example"),
      ),
      body: LineChart(LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: _co2Histories
                .map(
                  (h) => FlSpot(
                    (h.time.millisecondsSinceEpoch / 1000).toDouble(),
                    h.data.toDouble(),
                  ),
                )
                .toList(),
          )
        ],
      )),
    );
  }
}
