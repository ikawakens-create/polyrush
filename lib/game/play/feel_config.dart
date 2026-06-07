/// 手触りに関わる数値定数を 1 か所に集約するクラス（ADR-0014）。
///
/// フィールドをすべてここに置くことで、ゲームプレイの感触調整を
/// 1 ファイルの変更で完結させる。
class FeelConfig {
  const FeelConfig({
    this.fingerOffset = 48.0,
    this.hitboxPad = 16.0,
    this.pickupScale = 1.08,
    this.pickupMs = 100,
    this.returnMs = 150,
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

  FeelConfig copyWith({
    double? fingerOffset,
    double? hitboxPad,
    double? pickupScale,
    int? pickupMs,
    int? returnMs,
  }) =>
      FeelConfig(
        fingerOffset: fingerOffset ?? this.fingerOffset,
        hitboxPad: hitboxPad ?? this.hitboxPad,
        pickupScale: pickupScale ?? this.pickupScale,
        pickupMs: pickupMs ?? this.pickupMs,
        returnMs: returnMs ?? this.returnMs,
      );
}
