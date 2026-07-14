import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_first_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/multi_set_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

/// パズル生成器の切替トグル(ADR-0020 判断1)。
///
/// 段階的ロールアウトのためコンパイル時 const から開始する。既定は false=
/// 従来の V3/NonTrivial 経路。frame-first を実機評価する際に true にする。
/// 実機評価後に runtime 設定への昇格を検討(本 PR では扱わない)。
const bool kUseFrameFirstGenerator = true;

/// multi-set 消費トグル(ADR-0021 判断6 / A2方式・⑥-c)。
///
/// true のとき、1枠から複数の採用セット(variant)を取得し、seed から決定論的に
/// 1つを選んで出題する。枠が似ていても中身(分割)が変わるため別パズルとして成立する。
/// 戻り値契約は単一 VerifiedPuzzle のまま(play_screen は不変)。
/// 実機体感が芳しくない場合は false で ⑤ の frame-first 単一経路に戻せる。
/// A1(同一枠を「次へ」で巡回)は未実装・open。
const bool kUseMultiSetGenerator = true;

/// multi-set 経路で1枠から取得する variant の上限。
///
/// ⑥-a 計測では normal の distinct 採用構成が中央値72(easy は中央値3)。上限を
/// 大きくしても採用判定(countSolutions)のコストが増えるだけなので、体感上十分な
/// 範囲に抑える。1枠あたり実際に返る数は best-effort(1..この値)。
const int kMultiSetMaxVariants = 6;

/// トグルに従って生成器を選ぶ唯一の入口。全経路は同一シグネチャ・同一 Result 契約。
Result<VerifiedPuzzle, CompactPuzzleError> generateSelectedPuzzle({
  required Difficulty difficulty,
  required int seed,
}) {
  if (kUseMultiSetGenerator) {
    final r = MultiSetPuzzleGenerator.generate(
      difficulty: difficulty,
      seed: seed,
      maxVariants: kMultiSetMaxVariants,
    );
    switch (r) {
      case Ok(:final value):
        return Ok(_pickVariant(value, seed));
      case Err(:final error):
        return Err(error);
    }
  }
  return kUseFrameFirstGenerator
      ? FrameFirstPuzzleGenerator.generate(difficulty: difficulty, seed: seed)
      : NonTrivialPuzzleGenerator.generate(difficulty: difficulty, seed: seed);
}

/// [MultiSetPuzzle] の variants から seed 由来で1つを決定論的に選ぶ(A2方式)。
///
/// 同じ seed は常に同じ variant を返す(生成器全体の決定論契約を維持)。variants は
/// 1以上が保証されるため、必ず1つ選べる。
VerifiedPuzzle _pickVariant(MultiSetPuzzle m, int seed) {
  final n = m.variants.length;
  if (n == 1) return m.variants.first;
  // seed を撹拌して index 化(隣接 seed が同じ index に偏らないようにする)。
  final mixed = (seed * 2654435761) & 0x7FFFFFFF;
  return m.variants[mixed % n];
}
