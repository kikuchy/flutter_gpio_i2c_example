import 'package:dart_periphery/dart_periphery.dart';
import 'package:flutter/material.dart';
import 'package:hello/page/comprehensive_example.dart';

import 'page/gpio_examples.dart';
import 'page/i2c_examples.dart';

void main() {
  setCustomLibrary("/usr/local/lib/aarch64-linux-gnu/libperiphery.so");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter GPIO Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FeaturePage(),
    );
  }
}

class FeaturePage extends StatelessWidget {
  const FeaturePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flutter hardware control example"),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("GPIO"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const GpioPage()));
            },
          ),
          ListTile(
            title: const Text("I2C"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const I2cPage()));
            },
          ),
          ListTile(
            title: const Text("Comprehensive"),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ComprehensivePage()));
            },
          ),
        ],
      ),
    );
  }
}
