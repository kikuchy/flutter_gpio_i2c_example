# FlutterKaigi 2022 『Flutterが拓くハードウェアの世界』サンプルリポジトリ

https://flutterkaigi.jp/2022/ で発表する『Flutterが拓くハードウェアの世界』の中で使用した作例のコードです。

Raspberry Pi 3より新しいRaspberry Piで動作するはずです。
Raspberry Pi 3 Model B+での動作を確認しています。

## ざっくりした解説

### [GPIOのサンプル](./lib/page/gpio_examples.dart#L8)

* 使用したいピンを選んで、任意のサンプルを実行できます

#### [入力サンプル](./lib/page/gpio_examples.dart#L81)

* 選択したGPIOピンに通電したのを感知して、画面の表示を切り替えます
* スイッチを繋いでGNDとショートさせると、スイッチの押下を感知できます

#### [出力サンプル](./lib/page/gpio_examples.dart#L151)

* 選択したGPIOピンの電位を、一定周期でVccとGNDを切り替えます
* LEDを繋ぐとLチカします

### [I2Cのサンプル](./lib/page/i2c_examples.dart#L16)

* RaspberryPiのI2Cバス1を使用したサンプルを実行できます

#### [入力サンプル](./lib/page/i2c_examples.dart#L55)

* CCS881空気品質センサを使用して、CO2濃度を時系列グラフ表示します

#### [出力サンプル](./lib/page/i2c_examples.dart#L145)

* SSD1306 OLEDモジュールを使用して、選択した画像の不透明部分をOLEDモジュールに表示します

### [統合サンプル](./lib/page/comprehensive_example.dart)

* CO2を測定し、閾値を超えたら警告するサンプルです
* I2Cバス1にCCS881空気品質センサと、SSD1306 OLEDモジュールを接続する必要があります
* GPIO 20ピンにタクトスイッチを繋ぐ必要があります
* GPIO 26ピンにLEDを繋ぐ必要があります
* 仕様
  * Flutterの画面には測定したCO2濃度が時系列グラフで表示されます
  * OLEDモジュールにはCO2濃度の時系列グラフか、現在のCO2濃度の数値が表示されます
  * タクトスイッチを押下すると、OLEDモジュールの表示内容が切り替わります
  * CO2濃度が1000PPMを超えると、LEDが700ms周期で点滅します
* 実装Tips
  * 文字表示画像を作るため、imageパッケージを使用して画像を作っています
    * 文字描画をするため、フォントは [Inconsolata](https://www.levien.com/type/myfonts/inconsolata.html) を使用しています
      * InconsolataはRaph LevienによるSIL Open Font Licenseのフォントです
  * 各ICの機能を（今回の作例において最低限の機能だけを）抽象化したクラスを用意しています
    * lib/i2c_device をご覧ください
    * データシートから実装を起こすのは大変だったので、adafluit社のCircuitPythonのdriver実装をDart向けに（作例の動作に必要な分だけ）移植しました
