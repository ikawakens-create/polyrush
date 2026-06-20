import 'package:flutter/services.dart';

/// プレイ操作の触覚フィードバック(ADR-0014 の FeelConfig 思想に倣い
/// 強度の対応を 1 か所に集約する)。
///
/// 将来、設定画面の「ハプティクス ON/OFF」はこのクラスの enabled で
/// 制御する想定。現時点では常時 ON。
class PlayHaptics {
  PlayHaptics._();

  /// 設定画面実装時に外部から切り替える(現状は常時 true)
  static bool enabled = true;

  /// ピースを掴んだ瞬間: 軽い手応え
  static void pickup() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  /// グリッドへの吸着成功: 中程度の「カチッ」
  static void snap() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// 配置不可: 強めの「ブブッ」で失敗を伝える
  static void invalid() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// パズル完成: 強い達成感
  static void complete() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }
}
