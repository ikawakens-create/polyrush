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
    this.pickupRadius = 0.8,
    this.grabDirectionRatio = 1.0,
    this.trayPickupRadius = 1.0,
    this.trayPickupDownBonus = 1.5,
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

  /// 配置済みピースを掴める範囲（セル単位）。触れた点がピースのいずれかのセル中心から
  /// 縦横ともこの距離以内なら掴める（正方形判定）。
  final double pickupRadius;

  /// トレイで掴みと判定する縦横比のしきい値。上方向移動量 / 横移動量 がこの値以上のとき
  /// 掴みとみなす。大きいほど「まっすぐ上」でないと掴まない（＝横スクロールしやすい）、
  /// 小さいほど掴みやすい。
  final double grabDirectionRatio;

  /// トレイのピースを掴める範囲（トレイセル単位）。触れた点がピースのいずれかのセル中心から
  /// 縦横ともこの距離以内なら、最も近いピースを掴む（正方形・最近傍）。
  final double trayPickupRadius;

  /// トレイのピース掴みで、下方向の許容をこのセル数ぶん追加で広げる
  /// （ピース下の余白でも掴める／細い棒ピースを掴みやすくする）。
  /// 横と上は [trayPickupRadius] のまま。
  final double trayPickupDownBonus;

  FeelConfig copyWith({
    double? fingerOffset,
    double? hitboxPad,
    double? pickupScale,
    int? pickupMs,
    int? returnMs,
    double? snapRadius,
    double? dragStartSlop,
    double? pickupRadius,
    double? grabDirectionRatio,
    double? trayPickupRadius,
    double? trayPickupDownBonus,
  }) =>
      FeelConfig(
        fingerOffset: fingerOffset ?? this.fingerOffset,
        hitboxPad: hitboxPad ?? this.hitboxPad,
        pickupScale: pickupScale ?? this.pickupScale,
        pickupMs: pickupMs ?? this.pickupMs,
        returnMs: returnMs ?? this.returnMs,
        snapRadius: snapRadius ?? this.snapRadius,
        dragStartSlop: dragStartSlop ?? this.dragStartSlop,
        pickupRadius: pickupRadius ?? this.pickupRadius,
        grabDirectionRatio: grabDirectionRatio ?? this.grabDirectionRatio,
        trayPickupRadius: trayPickupRadius ?? this.trayPickupRadius,
        trayPickupDownBonus: trayPickupDownBonus ?? this.trayPickupDownBonus,
      );
}
