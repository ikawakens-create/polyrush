/// トレイの左詰めレイアウト計算（純粋関数・UI 非依存）。
///
/// 配置済み・ドラッグ中（hidden）のピースは幅 0 として詰め、残りを左に寄せた
/// ときの各アイテムの「内容左端」コンテンツ X 座標を返す。副作用が無いので
/// CI で検証できる（ロジック／手触り分離の方針）。

/// [index] 番目のアイテムの内容左端コンテンツ X 座標を返す。
///
/// - [itemWidths]: 各アイテムの幅（hitboxPad 込み、外側 padding は含まない）。
/// - [hidden]: 非表示（幅 0 として詰める）インデックス集合。
/// - [scrollPaddingLeft]: スクロールビュー左 padding（既定 16）。
/// - [itemHGap]: 各アイテムの左右 padding（片側、既定 12）。
double packedItemStartX({
  required List<double> itemWidths,
  required Set<int> hidden,
  required int index,
  double scrollPaddingLeft = 16,
  double itemHGap = 12,
}) {
  var x = scrollPaddingLeft;
  for (var j = 0; j < index; j++) {
    if (hidden.contains(j)) continue;
    x += itemHGap + itemWidths[j] + itemHGap;
  }
  x += itemHGap;
  return x;
}
