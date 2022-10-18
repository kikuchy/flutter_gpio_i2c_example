import 'package:dart_periphery/dart_periphery.dart';

/// 元ネタは https://github.com/adafruit/Adafruit_CircuitPython_SSD1306
/// これを作例に必要な部分だけDartに移植したもの
class Ssd1306 {
  static const setContrast = 0x81;
  static const setEntireOn = 0xA4;
  static const setNormInv = 0xA6;
  static const setDisp = 0xAE;
  static const setMemAddr = 0x20;
  static const setColAddr = 0x21;
  static const setPageAddr = 0x22;
  static const setDispStartLine = 0x40;
  static const setSegRemap = 0xA0;
  static const setMuxRatio = 0xA8;
  static const setIrefSelect = 0xAD;
  static const setComOutDir = 0xC0;
  static const setDispOffset = 0xD3;
  static const setComPinCfg = 0xDA;
  static const setDispClkDiv = 0xD5;
  static const setPrecharge = 0xD9;
  static const setVcomDesel = 0xDB;
  static const setChargePump = 0x8D;

  Ssd1306({
    required I2C i2c,
    required int width,
    required int height,
    int address = 0x3C,
    bool externalVcc = false,
    bool pageAddressing = false,
  })  : _i2c = i2c,
        _width = width,
        _height = height,
        _address = address,
        _pageAddressing = pageAddressing,
        _externalVcc = externalVcc,
        _pages = height ~/ 8,
        _buffer = List.filled(((height ~/ 8) * width) + 1, 0),
        _pageBuffer = List.filled(width + 1, 0),
        _pageColumnStart = [width % 32, 0x10 + width ~/ 32] {
    // Set first byte of data buffer to Co=0, D/C=1
    _buffer[0] = 0x40;
    powerOn();
    initDisplay();
  }

  final I2C _i2c;
  final int _address;
  final int _width;
  final int _height;
  final bool _pageAddressing;
  final int _pages;
  final bool _externalVcc;
  final List<int> _buffer;
  List<int> _pageBuffer;
  final List<int> _pageColumnStart;
  bool _power = false;

  void _writeCmd(int cmd) {
    final buf = [0x80, cmd];
    _i2c.writeBytes(_address, buf);
  }

  void _writeFrameBuf() {
    if (_pageAddressing) {
      for (int page = 0; page < _pages; page++) {
        _writeCmd(0xB0 + page);
        _writeCmd(_pageColumnStart[0]);
        _writeCmd(_pageColumnStart[1]);
        _pageBuffer = [
          _pageBuffer[0],
          ..._buffer.sublist(1 + _width * page, 1 + _width * (page + 1)),
        ];
        _i2c.writeBytes(_address, _pageBuffer);
      }
    } else {
      _i2c.writeBytes(_address, _buffer);
    }
  }

  void initDisplay() {
    <int>[
      // off
      setDisp,
      // address setting
      setMemAddr,
      if (_pageAddressing)
      // Page Addressing Mode
        0x10
      else
      // Horizontal Addressing Mode
        0x00,
      setDispStartLine,
      // column addr 127 mapped to SEG0
      setSegRemap | 0x01,
      setMuxRatio,
      _height - 1,
      // scan from COM[N] to COM0
      setComOutDir | 0x08,
      setDispOffset,
      0x00,
      setComPinCfg,
      if (_width > 2 * _height) 0x02 else 0x12,
      // timing and driving scheme
      setDispClkDiv,
      0x80,
      setPrecharge,
      if (_externalVcc) 0x22 else 0xF1,
      setVcomDesel,
      // 0.83*Vcc  # n.b. specs for ssd1306 64x32 oled screens imply this should be 0x40
      0x30,
      // display
      setContrast,
      // maximum
      0xFF,
      // output follows RAM contents
      setEntireOn,
      // not inverted
      setNormInv,
      setIrefSelect,
      // enable internal IREF during display on
      0x30,
      setChargePump,
      if (_externalVcc) 0x10 else 0x14,
      // display on
      setDisp | 0x01,
    ].forEach(_writeCmd);
    fill(0);
    show();
  }

  void powerOn() {
    _writeCmd(setDisp | 0x01);
    _power = true;
  }

  void fill(int color) {
    _buffer.fillRange(1, _buffer.length, color);
  }

  void setPixel(int x, int y, int color) {
    final index = (y >> 3) * _width + x;
    final offset = y & 0x07;
    _buffer[index + 1] = (_buffer[index + 1] & ~(0x01 << offset)) |
    ((color != 0 ? 1 : 0) << offset);
  }

  void show() {
    if (!_pageAddressing) {
      int xpos0 = 0;
      int xpos1 = _width - 1;
      if (_width != 128) {
        // narrow displays use centered columns
        final colOffset = (128 - _width) ~/ 2;
        xpos0 += colOffset;
        xpos1 += colOffset;
      }
      _writeCmd(setColAddr);
      _writeCmd(xpos0);
      _writeCmd(xpos1);
      _writeCmd(setPageAddr);
      _writeCmd(0);
      _writeCmd(_pages - 1);
    }
    _writeFrameBuf();
  }
}