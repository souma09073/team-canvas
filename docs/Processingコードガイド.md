# Processing版 コードガイド

## この資料について

Processing版のファイル構成と重要なコードを、チームメンバーが辞書のように参照できるようにまとめた資料です。

現在のProcessing版は、主人公・道路・沖縄の背景を使った**ビジュアル試作段階**です。
血糖値、食べ物、マンジャロ、ゾーン、ゲームオーバーなどの本編ロジックは、今後HTMLプロトタイプから移植します。

---

## 起動方法

Processingで次のファイルを開き、画面上部の実行ボタンを押します。

- [`processing/manjaro_game/manjaro_game.pde`](../processing/manjaro_game/manjaro_game.pde)

### 現在の操作

| 操作 | キー |
|---|---|
| 左レーンへ移動 | `←` または `A` |
| 右レーンへ移動 | `→` または `D` |
| 中央へ戻してアニメーションをリセット | `R` |

---

## Processingのファイル構成

同じスケッチフォルダにある`.pde`ファイルは、Processingによって1つのプログラムとしてまとめて実行されます。

| ファイル | 役割 | 主に変更する場面 |
|---|---|---|
| [`manjaro_game.pde`](../processing/manjaro_game/manjaro_game.pde) | ゲーム全体の司令塔 | 起動処理、毎フレームの処理順、キー操作 |
| [`Config.pde`](../processing/manjaro_game/Config.pde) | 調整値の置き場 | 画面、道路、レーン、主人公の大きさ |
| [`Assets.pde`](../processing/manjaro_game/Assets.pde) | 画像の読み込み | 画像素材の追加・差し替え |
| [`Player.pde`](../processing/manjaro_game/Player.pde) | 主人公 | レーン移動、30コマ走行、汗、上下動 |
| [`Renderer3D.pde`](../processing/manjaro_game/Renderer3D.pde) | 遠景と道路 | 道路の色・形・白線・流れる速度 |
| [`Scenery.pde`](../processing/manjaro_game/Scenery.pde) | 沿道の街区 | 家やヤシの大きさ、数、速度、再配置 |
| [`HUD.pde`](../processing/manjaro_game/HUD.pde) | 画面上の情報 | タイトル、操作説明、今後の血糖値UI |

---

## ゲームが動く流れ

### 1. `settings()`

画面サイズと描画方式を決めます。

```java
size(1280, 720, P3D);
smooth(8);
```

- `1280, 720`：画面サイズ
- `P3D`：Processingの3D描画モード
- `smooth(8)`：図形の輪郭を滑らかにする

### 2. `setup()`

ゲーム開始時に一度だけ実行されます。

主な処理：

1. フレームレートを60fpsに設定
2. 画像素材を読み込む
3. 主人公・道路・街区・HUDを生成

### 3. `draw()`

ゲーム中、1秒間に約60回繰り返されます。

```text
状態更新
  主人公 → 道路 → 街区

画面描画
  遠景 → 道路 → 街区 → 主人公 → HUD
```

後から描いたものほど手前に表示されます。そのためHUDは最後に描画します。

### 4. `keyPressed()`

キー入力を主人公の処理へ渡します。

```java
player.moveLeft();
player.moveRight();
player.reset();
```

---

## `Config.pde`：調整値

ゲームの見た目に関する基本値をまとめています。

| 定数 | 現在値 | 意味 |
|---|---:|---|
| `SCREEN_W` | 1280 | 基準画面幅 |
| `SCREEN_H` | 720 | 基準画面高さ |
| `HORIZON_Y` | 286 | 道路の消失点の高さ |
| `ROAD_TOP_HALF` | 46 | 道路の奥側の半幅 |
| `ROAD_BOTTOM_HALF` | 575 | 道路の手前側の半幅 |
| `LANE_SCREEN_X` | 3地点 | 左・中央・右レーンの画面上の位置 |
| `PLAYER_BASE_Y` | 668 | 主人公の足元位置 |
| `PLAYER_HEIGHT` | 350 | 主人公の表示サイズ |
| `PLAYER_LANE_SMOOTH` | 10.0 | レーン移動の追従速度 |

`RUN_CYCLE_SPEED`は現在の30コマ処理では使われていません。
走行アニメーションの速度は、`Player.pde`内の次の計算で決まっています。

```java
strideDistance += dt * runSpeed * 1.48;
```

---

## `Assets.pde`：画像読み込み

### 現在使用している画像

#### 主人公

| ファイル | 内容 |
|---|---|
| `runner.png` | 30コマ画像が読み込めなかった場合の予備 |
| `run30_01.png` | 走行コマ1〜6 |
| `run30_02.png` | 走行コマ7〜12 |
| `run30_03.png` | 走行コマ13〜18 |
| `run30_04.png` | 走行コマ19〜24 |
| `run30_05.png` | 走行コマ25〜30 |

保存場所：

- [`data/images/player/`](../processing/manjaro_game/data/images/player/)

#### 背景

| ファイル | 内容 |
|---|---|
| `okinawa_far.png` | 固定された空・海・遠景 |
| `okinawa_blocks.png` | 手前へ流れる家・ヤシ・石垣などの街区 |

保存場所：

- [`data/images/backgrounds/`](../processing/manjaro_game/data/images/backgrounds/)

ファイル名に`chroma`が付いた画像は、透過処理前の原本です。ゲームでは直接使用していません。

---

## `Player.pde`：主人公

### 主人公の状態

| 変数 | 意味 |
|---|---|
| `lane` | 現在のレーン。`0=左`、`1=中央`、`2=右` |
| `screenX` | 主人公の画面上の横位置 |
| `strideDistance` | 走行アニメーションの進み |
| `runSpeed` | 現在の速度倍率 |
| `sweat` | 表示中の汗を保存するリスト |

### レーン移動

```java
lane = max(0, lane - 1);
lane = min(2, lane + 1);
```

`lane`が0未満、2より大きくならないよう制限しています。

横方向の移動は、現在位置から目的のレーンへ少しずつ近づけています。

```java
screenX = lerp(screenX, targetX, follow);
```

### 30コマ走行

走った距離から、表示するコマ番号を0〜29の範囲で決めます。

```java
return floor(strideDistance * 30.0) % 30;
```

各画像シートには6コマ入っています。

```java
int sheetIndex = frame30 / 6;
int localFrame = frame30 % 6;
```

たとえば14コマ目の場合：

- `14 / 6 = 2` → 3枚目の画像シート
- `14 % 6 = 2` → シート内の3コマ目

### 上下動と着地

```java
float bob = -abs(sin(phase)) * 9;
float landing = pow(abs(cos(phase)), 8);
```

- `bob`：走行中の上下動
- `landing`：着地時の潰れと影の変化

### 汗

`SweatDrop`クラスが汗1粒を管理します。

| 変数 | 意味 |
|---|---|
| `x`, `y` | 汗の位置 |
| `vx`, `vy` | 汗の移動速度 |
| `life` | 消えるまでの残り時間 |
| `size` | 汗の大きさ |

汗の発生間隔：

```java
sweatTimer = random(0.10, 0.16);
```

約0.10〜0.16秒ごとに、主人公の左右から交互に汗が出ます。

---

## `Renderer3D.pde`：遠景と道路

### 遠景

`okinawa_far.png`を画面全体に表示します。
ヤシや家などの近景は含めず、空・海・遠くの街だけを固定しています。

### 道路

道路は奥が細く、手前が広い台形として描いています。

道路の幅は`Config.pde`の次の値で決まります。

```java
ROAD_TOP_HALF
ROAD_BOTTOM_HALF
```

### 白線の移動

```java
scroll = (scroll + dt * 0.42 * speed) % 1.0;
```

- `0.42`を上げる → 白線が速く流れる
- `speed` → 主人公の`runSpeed`と連動

### 遠近感

```java
return t * t;
```

距離を二乗することで、遠くではゆっくり、手前では急速に動く見え方を作っています。

---

## `Scenery.pde`：動く街区

### `RoadsideBlock`

家、ヤシ、シーサー、石垣などをまとめた街区1個分を管理します。

| 変数 | 意味 |
|---|---|
| `progress` | 奥から手前までの進み。`0=奥`、`1=手前` |
| `side` | `-1=左`、`1=右` |
| `spriteIndex` | 6種類のうち、どの街区を使うか |
| `sizeVariation` | 大きさの個体差 |
| `edgeDistance` | 道路からの距離 |

### 街区の数

```java
blocks = new RoadsideBlock[12];
```

現在は左右合計12街区です。

### 移動

```java
float approach = 0.090 + block.progress * 0.135;
```

街区が手前へ来るほど、画面上の移動速度が上がります。

### 大きさ

```java
float drawH = lerp(70, 650, perspective);
```

- `70`：奥に出現したときの高さ
- `650`：最も手前まで来たときの高さ

### 再利用

街区が画面外まで進んだら、奥へ戻して再利用します。

```java
if (block.progress >= 1.0) {
  block.recycle();
}
```

再配置時に6種類の街区から1つを選び直すため、同じ素材を繰り返し使えます。

---

## `HUD.pde`：画面上の情報

現在は次の情報を表示しています。

- `VISUAL PROTOTYPE 01`
- `沖縄 日本縦断スタート`
- レーン移動の操作説明

日本語フォントは次のコードで指定しています。

```java
font = createFont("Meiryo UI", 20);
```

今後追加する予定の表示：

- 血糖値
- マンジャロの使用状態
- ゾーンゲージ
- コース進行度
- 高血糖・低血糖警告
- ゲームオーバー／ゴール表示

---

## 目的別の逆引き

| やりたいこと | 主に見る場所 |
|---|---|
| 主人公を大きくする | `Config.pde`の`PLAYER_HEIGHT` |
| 主人公を上下に動かす | `Config.pde`の`PLAYER_BASE_Y` |
| レーン間隔を変える | `Config.pde`の`LANE_SCREEN_X` |
| 横移動を速くする | `PLAYER_LANE_SMOOTH` |
| 走行モーションを速くする | `Player.pde`の`strideDistance`更新式 |
| 汗を増やす | `Player.pde`の`sweatTimer` |
| 汗を大きくする | `SweatDrop`の`size` |
| 街区を増やす | `Scenery.pde`の`RoadsideBlock[12]` |
| 街区を大きくする | `Scenery.pde`の`lerp(70, 650, ...)` |
| 街区の流れを速くする | `Scenery.pde`の`approach` |
| 道路の白線を速くする | `Renderer3D.pde`の`0.42` |
| 道路を広くする | `Config.pde`の`ROAD_BOTTOM_HALF` |
| 消失点を上下させる | `Config.pde`の`HORIZON_Y` |
| タイトルや操作説明を変更する | `HUD.pde` |
| 画像を追加・差し替えする | `Assets.pde`と`data/images/` |
| キー操作を変更する | `manjaro_game.pde`の`keyPressed()` |

---

## よく使うProcessingの用語

| 用語 | 意味 |
|---|---|
| `PImage` | Processingで扱う画像 |
| `PFont` | Processingで扱うフォント |
| `ArrayList` | 数が増減するデータの一覧 |
| `int` | 整数 |
| `float` | 小数を含む数値 |
| `final` | 実行中に変更しない定数 |
| `dt` | 前のフレームから経過した秒数 |
| `lerp(a, b, t)` | `a`から`b`の間を滑らかに補間する |
| `random(a, b)` | `a`から`b`までのランダムな値 |
| `constrain()` | 数値を指定範囲内に制限する |
| `pushMatrix()` | 現在の移動・回転状態を保存する |
| `popMatrix()` | 保存した移動・回転状態へ戻す |
| `tint()` | 画像の透明度や色味を調整する |

---

## 今後の実装方針

HTMLプロトタイプで固めたゲーム性を、段階的にProcessingへ移植します。

1. ゲーム状態とコース進行
2. 食べ物の配置・取得判定
3. 血糖値と高血糖・低血糖
4. マンジャロ
5. ゾーンと速度変化
6. HUD
7. ストーリー、スタート画面、ゴール画面
8. 音、演出、最終調整

数値や仕様を変更する際は、変更理由とプレイした感想をチーム内で共有してから調整します。
