import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dart_periphery/dart_periphery.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image/image.dart' as image;

import '../i2c_device/ccs811.dart';
import '../i2c_device/ssd1306.dart';
import 'commons.dart';

class I2cPage extends StatelessWidget {
  const I2cPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("I2C examples"),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("CCS811 CO2 censor"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Co2Page(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text("SSD1306"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Ssd1306Page(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class Co2Page extends StatefulWidget {
  const Co2Page({Key? key}) : super(key: key);

  @override
  State<Co2Page> createState() => _Co2PageState();
}

class _Co2PageState extends State<Co2Page> {
  late I2C _i2c;
  late Ccs811 _censor;
  late Timer _timer;
  final List<HistoryData<int>> _co2History = [];

  @override
  void initState() {
    super.initState();
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(const InitializationSettings(
        linux: LinuxInitializationSettings(defaultActionName: "OK")));

    _i2c = I2C(1);
    _censor = Ccs811(_i2c);
    void setupTimer() {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
            (timer) {
          try {
            print("Error no: ${_i2c.getErrno()}");
            print("CCS881 isReady: ${_censor.isDataReady}");
            if (_censor.isDataReady) {
              final eco2 = _censor.eco2;
              if (eco2 < 10000) {
                setState(() {
                  _co2History.add(HistoryData(eco2));
                });
                if (eco2 >= 1000) {
                  flutterLocalNotificationsPlugin.show(
                    0,
                    "CO2 Level: High",
                    "Ventilate the room now!\nCO2: ${eco2}PPM",
                    const NotificationDetails(
                      linux: LinuxNotificationDetails(),
                    ),
                  );
                }
              }
            }
          } catch (e) {
            print(e);
            _timer.cancel();
            setupTimer();
          }
        },
      );
    }

    setupTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    _i2c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CO2 censor"),
      ),
      body: LineChart(LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: _co2History
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

class Ssd1306Page extends StatefulWidget {
  const Ssd1306Page({Key? key}) : super(key: key);

  @override
  State<Ssd1306Page> createState() => _Ssd1306PageState();
}

class _Ssd1306PageState extends State<Ssd1306Page> {
  late I2C _i2c;
  late Ssd1306 _ssd1306;

  File? lastFile;

  @override
  void initState() {
    super.initState();
    // setCustomLibrary("/usr/local/lib/aarch64-linux-gnu/libperiphery.so");
    _i2c = I2C(1);
    _ssd1306 = Ssd1306(i2c: _i2c, width: 128, height: 32);
    _ssd1306.fill(0);
    _ssd1306.show();
  }

  @override
  void dispose() {
    _i2c.dispose();
    super.dispose();
  }

  void applyFill() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      final file = File(result.files.first.path!);
      final img = image.decodeImage(await file.readAsBytes())!;
      for (int x = 0; x < min(img.width, 128); x++) {
        for (int y = 0; y < min(img.height, 32); y++) {
          // temporary only alpha
          _ssd1306.setPixel(x, y, img.getPixel(x, y) & 0xFF000000);
        }
      }
      _ssd1306.show();
      setState(() {
        lastFile = file;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SSD1306 example"),
      ),
      body: Center(
        child: Column(
          children: [
            if (lastFile != null)
              Image.file(lastFile!),
            ElevatedButton(
              child: const Text("Flip"),
              onPressed: () async {

                applyFill();
              },
            )
          ],
        ),
      ),
    );
  }
}