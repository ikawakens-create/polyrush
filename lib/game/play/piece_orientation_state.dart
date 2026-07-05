import 'dart:math';

import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';

/// スクランブル用の乱数を puzzle.seed から決定論的に派生させる際のマジック値。
///
/// 共有のシード派生ユーティリティが存在しないため、ADR-0019 の指示どおり
/// `Random(puzzle.seed ^ 固定マジック値)` を用いる。'SCRB' の ASCII 値。
const int _scrambleSeedMagic = 0x53435242;

/// プレイ中のピースごとの「現在の向き」を保持する薄い層（ADR-0019）。
///
/// 確定資産（PolyominoTransformer / PlacedBlock）はラップして使うだけ。
/// タップによる 90 度回転（rotateCw）と左右反転（flip）を提供する。
class PieceOrientationState {
  PieceOrientationState.fromPuzzle(GeneratedPuzzle puzzle)
    : _orientations = [for (final b in puzzle.blocks) b.orientation];

  /// 初期向きをスクランブルして初期化する（ADR-0019 ③）。
  ///
  /// 難易度別の floor/cap 方式で「解の向きと偶然一致する数」を制御する:
  /// - easy: floor=1 / cap=1。候補は block.orientation を基準にした回転のみ
  ///   （反転は含めない。タップ回転だけで必ず解けることを保証するため）。
  /// - normal/hard: floor=0 / cap=2。候補は allUniqueOrientations（反転込み）。
  /// 対称ピース（allUniqueOrientations が1種のみ）は floor/cap のカウント対象外。
  /// 乱数は puzzle.seed から決定論的に派生するため、同じ puzzle は常に同じ
  /// 初期向きになる。
  PieceOrientationState.scrambled(GeneratedPuzzle puzzle, Difficulty difficulty)
    : _orientations = _buildScrambled(puzzle, difficulty);

  final List<PolyominoData> _orientations;

  /// 保持しているピース数。
  int get length => _orientations.length;

  /// ピース [index] の現在の向き。
  PolyominoData orientationOf(int index) => _orientations[index];

  /// ピース [index] を時計回りに 90 度回転する（結果は正規化済み）。
  void rotateCw(int index) {
    _orientations[index] = PolyominoTransformer.rotate90(_orientations[index]);
  }

  /// ピース [index] を反時計回りに 90 度回転する（結果は正規化済み）。
  ///
  /// 待ちなし方式のダブルタップ（②.5/③ 追補）で、1 回目のタップで即座に
  /// 適用された回転を取り消してから反転するために使う。
  /// rotate90 を 3 回適用するだけのラップ（確定資産 PolyominoTransformer 不触）。
  void rotateCcw(int index) {
    var v = _orientations[index];
    for (var i = 0; i < 3; i++) {
      v = PolyominoTransformer.rotate90(v);
    }
    _orientations[index] = v;
  }

  /// ピース [index] を左右反転する（結果は正規化済み・ADR-0019 追補）。
  ///
  /// 確定資産 PolyominoTransformer.flipHorizontal を呼ぶだけのラップ。
  /// flipHorizontal 1 種 + rotateCw で全 8 向きに到達できる。
  void flip(int index) {
    _orientations[index] = PolyominoTransformer.flipHorizontal(
      _orientations[index],
    );
  }

  /// 難易度別の floor（最低一致数）/ cap（一致数上限）。ADR-0019 追補参照。
  static ({int floor, int cap}) _floorCapFor(Difficulty difficulty) {
    return switch (difficulty) {
      Difficulty.easy => (floor: 1, cap: 1),
      Difficulty.normal => (floor: 0, cap: 2),
      Difficulty.hard => (floor: 0, cap: 2),
    };
  }

  /// ピースの候補向きを作る。
  ///
  /// easy は block.orientation を基準にした回転のみ（反転は含めない）。
  /// normal/hard は allUniqueOrientations（反転込み全向き）。
  static List<PolyominoData> _candidatesFor(
    PlacedBlock block,
    Difficulty difficulty,
  ) {
    if (difficulty != Difficulty.easy) {
      return PolyominoTransformer.allUniqueOrientations(block.source).toList();
    }
    final seen = <String>{};
    final result = <PolyominoData>[];
    var current = block.orientation;
    for (var i = 0; i < 4; i++) {
      if (seen.add(current.cells.toString())) {
        result.add(current);
      }
      current = PolyominoTransformer.rotate90(current);
    }
    return result;
  }

  static List<PolyominoData> _buildScrambled(
    GeneratedPuzzle puzzle,
    Difficulty difficulty,
  ) {
    final blocks = puzzle.blocks;
    final random = Random(puzzle.seed ^ _scrambleSeedMagic);

    final candidates = <List<PolyominoData>>[];
    final isSymmetric = <bool>[];
    for (final b in blocks) {
      candidates.add(_candidatesFor(b, difficulty));
      isSymmetric.add(
        PolyominoTransformer.allUniqueOrientations(b.source).length == 1,
      );
    }

    final result = [for (final b in blocks) b.orientation];
    final nonSymmetricIndices = [
      for (var i = 0; i < blocks.length; i++)
        if (!isSymmetric[i]) i,
    ];

    final floorCap = _floorCapFor(difficulty);

    if (floorCap.floor > 0) {
      final shuffled = List<int>.from(nonSymmetricIndices)..shuffle(random);
      final floorSet = shuffled.take(floorCap.floor).toSet();
      for (final i in nonSymmetricIndices) {
        if (floorSet.contains(i)) {
          result[i] = blocks[i].orientation;
        } else {
          final nonMatching = candidates[i]
              .where((c) => c != blocks[i].orientation)
              .toList();
          result[i] = nonMatching[random.nextInt(nonMatching.length)];
        }
      }
    } else {
      for (final i in nonSymmetricIndices) {
        final cs = candidates[i];
        result[i] = cs[random.nextInt(cs.length)];
      }
      final matchedIndices = nonSymmetricIndices
          .where((i) => result[i] == blocks[i].orientation)
          .toList();
      if (matchedIndices.length > floorCap.cap) {
        final shuffledMatched = List<int>.from(matchedIndices)..shuffle(random);
        final excess = shuffledMatched.take(
          matchedIndices.length - floorCap.cap,
        );
        for (final i in excess) {
          final nonMatching = candidates[i]
              .where((c) => c != blocks[i].orientation)
              .toList();
          result[i] = nonMatching[random.nextInt(nonMatching.length)];
        }
      }
    }

    return result;
  }
}
