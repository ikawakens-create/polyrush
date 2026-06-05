/// 枠の単連結性を保証するパズル生成層（ADR-0009）。
///
/// ## 役割
/// [VerifiedPuzzleGenerator.generate] を呼び、単連結性が保証されない枠を
/// 弾いて再生成する最外層。ゲーム本体はパズル取得にこのクラスを経由する
/// （ADR-0009 判断4）。
///
/// ## 参照
/// - docs/adr/0009-simply-connected-frame.md
/// - docs/adr/0008-verified-puzzle-generation.md（サブシード派生の前例）
library;

import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_connectivity.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

/// 枠形状リトライの上限回数（ADR-0009 判断5）。
const int maxFrameRetries = 8;

/// [PlayablePuzzleGenerator.generate] が失敗した場合のエラー種別
/// （ADR-0009 判断7）。
enum PlayablePuzzleError {
  /// 全試行で [VerifiedPuzzleGenerator.generate] が Err を返し、
  /// パズルを 1 個も生成できなかった。
  generationFailed,

  /// パズルは生成できたが、全試行で枠が単連結でなかった。
  noSimplyConnectedFrame,
}

/// 解数検証 + 枠形状検証済みパズル生成エンジン（ADR-0009）。
///
/// インスタンス化禁止。公開 API は [generate] のみ。
class PlayablePuzzleGenerator {
  PlayablePuzzleGenerator._();

  /// 単連結な枠を持つパズルを 1 つ生成する（ADR-0009 判断4〜7）。
  ///
  /// - [difficulty]: パズルの難易度。
  /// - [seed]: 乱数シード。同じ引数で呼ぶと常に同じ結果を返す（決定論的）。
  ///
  /// 戻り値:
  /// - [Ok]: 単連結な枠を持ち、解が 1〜3 通りの [VerifiedPuzzle]。
  /// - [Err]([PlayablePuzzleError.generationFailed]): 全試行で下層が失敗。
  /// - [Err]([PlayablePuzzleError.noSimplyConnectedFrame]): 生成はできたが
  ///   全試行で枠に穴があった。
  static Result<VerifiedPuzzle, PlayablePuzzleError> generate({
    required Difficulty difficulty,
    required int seed,
  }) {
    var anySucceeded = false;
    for (var attempt = 0; attempt < maxFrameRetries; attempt++) {
      final s = _deriveFrameSeed(seed, attempt);
      final r = VerifiedPuzzleGenerator.generate(
        difficulty: difficulty,
        seed: s,
      );
      switch (r) {
        case Ok(value: final vp):
          anySucceeded = true;
          if (isFrameSimplyConnected(vp.puzzle.frame)) {
            return Ok(vp);
          }
        case Err():
          break;
      }
    }
    return Err(
      anySucceeded
          ? PlayablePuzzleError.noSimplyConnectedFrame
          : PlayablePuzzleError.generationFailed,
    );
  }

  /// 元シードと試行インデックスから決定論的にサブシードを派生させる
  /// （ADR-0009 判断5 / ADR-0008 § サブシード派生参照）。
  ///
  /// 32bit マスクの LCG（Numerical Recipes 乗数 1664525・加数 1013904223）。
  /// attempt 最大 7 の範囲でオーバーフローしない。
  static int _deriveFrameSeed(int seed, int attempt) {
    var x = (seed ^ (attempt * 0x9E3779B1)) & 0xFFFFFFFF;
    x = (x * 1664525 + 1013904223) & 0xFFFFFFFF;
    return x;
  }
}
