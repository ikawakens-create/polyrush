/// 手触りに関わる数値定数を 1 か所に集約するクラス（ADR-0014）。
///
/// フィールドをすべてここに置くことで、ゲームプレイの感触調整を
/// 1 ファイルの変更で完結させる。
class FeelConfig {
  const FeelConfig({
    this.fingerOffset = 60.0,
    this.hitboxPad = 16.0,
    this.pickupScale = 1.0,
    this.pickupMs = 100,
    this.returnMs = 100,
    this.snapRadius = 0.5,
    this.dragStartSlop = 8.0,
  });

  /// 指の接触点からピースを上方向にずらすピクセル数。
  final double fingerOffset;

  /// トレイアイテムの掴み判定を拡張するピクセル数（四辺に適用）。
  final double hitboxPad;

  /// 拾い上げ時の拡大率（1.0 = 等倍）。
  final double pickupScale;

  /// 拾い上げアニメーションの時間（ミリ秒）。
  final int pickupMs;

  /// トレイへ戻るアニメーションの時間（ミリ秒）。
  final int returnMs;

  /// 吸着を許す最大ズレ（セル単位）。
  /// 離した時、ピース左上の格子からのズレがこの値以内なら吸着する。
  final double snapRadius;

  /// この距離以上ポインタが動いて初めて掴み開始とみなす（タップ誤操作で外れるのを防ぐ）。
  final double dragStartSlop;

  FeelConfig copyWith({
    double? fingerOffset,
    double? hitboxPad,
    double? pickupScale,
    int? pickupMs,
    int? returnMs,
    double? snapRadius,
    double? dragStartSlop,
  }) =>
      FeelConfig(
        fingerOffset: fingerOffset ?? this.fingerOffset,
        hitboxPad: hitboxPad ?? this.hitboxPad,
        pickupScale: pickupScale ?? this.pickupScale,
        pickupMs: pickupMs ?? this.pickupMs,
        returnMs: returnMs ?? this.returnMs,
        snapRadius: snapRadius ?? this.snapRadius,
        dragStartSlop: dragStartSlop ?? this.dragStartSlop,
      );
}
