import 'package:dart_periphery/dart_periphery.dart';

/// 元ネタは https://github.com/adafruit/Adafruit_CircuitPython_Register/blob/main/adafruit_register/i2c_bit.py のROBit
class ReadOnlyBit {
  const ReadOnlyBit(
      this._i2c, this._deviceAddress, this._registerAddress, this._bit);

  final I2C _i2c;
  final int _deviceAddress;
  final int _registerAddress;
  final int _bit;

  int get _bitMask => 1 << (_bit % 8);

  bool get bit {
    final byte = _i2c.readByteReg(_deviceAddress, _registerAddress);
    final b = byte & _bitMask;
    return b != 0;
  }
}

/// 元ネタは https://github.com/adafruit/Adafruit_CircuitPython_Register/blob/main/adafruit_register/i2c_bit.py のRWBit
class RwBit extends ReadOnlyBit {
  const RwBit(I2C i2c, int deviceAddress, int registerAddress, int bit)
      : super(i2c, deviceAddress, registerAddress, bit);

  set bit(bool b) {
    final byte = _i2c.readByte(_registerAddress);
    final base = byte & ~_bitMask;
    final flag = ((b) ? 1 : 0) << (_bit % 8);
    _i2c.writeByte(_registerAddress, base | flag);
  }
}

/// 元ネタは https://github.com/adafruit/Adafruit_CircuitPython_CCS811
/// これを作例に必要な部分だけDartに移植したもの
class Ccs811 {
  static const _algResultData = 0x02;
  static const _rawData = 0x03;
  static const _envData = 0x05;
  static const _ntc = 0x06;
  static const _thresholds = 0x10;
  static const _baseline = 0x11;
  static const _swReset = 0xFF;

  Ccs811(this._i2c, [this._address = 0x5A]);

  final I2C _i2c;
  final int _address;

  late final _isDataReadyBit = ReadOnlyBit(_i2c, _address, 0x00, 3);

  bool get isDataReady => _isDataReadyBit.bit;

  late final _errorBit = ReadOnlyBit(_i2c, _address, 0x00, 0);

  bool get hasError => _errorBit.bit;

  int _eco2 = 0;

  int get eco2 {
    _updateData();
    return _eco2;
  }

  int _tvoc = 0;

  int get tvoc {
    _updateData();
    return _tvoc;
  }

  int getErrorCode() {
    _i2c.writeByte(_address, 0xE0);
    return _i2c.readByte(_address);
  }

  void _updateData() {
    if (isDataReady) {
      _i2c.writeByte(_address, _algResultData);
      final buf = _i2c.readBytes(_address, 8);
      _eco2 = ((buf[0] << 8) & 0xFF00) | (buf[1] & 0xFF);
      _tvoc = ((buf[2] << 8) & 0xFF00) | (buf[3] & 0xFF);

      if (hasError) {
        throw Ccs811Exception(getErrorCode());
      }
    }
  }
}

class Ccs811Exception implements Exception {
  Ccs811Exception(this.errorCode);

  final int errorCode;

  @override
  String toString() {
    return "Error code: $errorCode";
  }
}