import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_first_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

/// パズル生成器の切替トグル(ADR-0020 判断1)。
///
/// 段階的ロールアウトのためコンパイル時 const から開始する。既定は false=
/// 従来の V3/NonTrivial 経路。frame-first を実機評価する際に true にする。
/// 実機評価後に runtime 設定への昇格を検討(本 PR では扱わない)。
const bool kUseFrameFirstGenerator = true;

/// トグルに従って生成器を選ぶ唯一の入口。両生成器は同一シグネチャ・同一 Result 契約。
Result<VerifiedPuzzle, CompactPuzzleError> generateSelectedPuzzle({
  required Difficulty difficulty,
  required int seed,
}) {
  return kUseFrameFirstGenerator
      ? FrameFirstPuzzleGenerator.generate(difficulty: difficulty, seed: seed)
      : NonTrivialPuzzleGenerator.generate(difficulty: difficulty, seed: seed);
}
