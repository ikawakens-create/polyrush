/// パズル検証開発ツール（仕様書 § 19 / ADR-0008 対応）。
///
/// ## 目的
/// Phase 1 の最後の確認用 CLI ツール。lib/ のコードは一切変更しない開発専用ツール。
/// シードと難易度でパズルを生成・検証し、(1) 単発モードで盤面を ASCII 表示、
/// (2) 統計モードで難易度別に「生成失敗率・フォールバック率・解数分布・
/// 生成時間・試行回数」を集計し、仕様書 § 19 のマイルストーン
/// 「生成失敗率1%以下」を PASS/FAIL 判定する。
///
/// ## 使い方
///
///     dart run tool/puzzle_inspector.dart --help
///     dart run tool/puzzle_inspector.dart --seed=<整数> --difficulty=<easy|normal|hard>
///     dart run tool/puzzle_inspector.dart --seed=<整数> --difficulty=<easy|normal|hard> --raw
///     dart run tool/puzzle_inspector.dart --stats [--count=<整数>]
///
/// ## 座標系
/// (y, x) = (row, col)（ADR-0006）。y 昇順＝上→下、x 昇順＝左→右。
///
/// ## 生成規約
/// 生成は必ず VerifiedPuzzleGenerator 経由（ゲーム本体の規約＝ADR-0008 判断6）。
/// --raw の PuzzleGenerator.construct() 直呼びは検証用途に限る。

import 'dart:io';

import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/solver.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

void main(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printHelp();
    return;
  }

  if (args.contains('--stats')) {
    final countStr = _argValue(args, '--count') ?? '1000';
    final count = int.tryParse(countStr) ?? 1000;
    final allPass = _runStats(count);
    exit(allPass ? 0 : 1);
  }

  final seedStr = _argValue(args, '--seed');
  final diffStr = _argValue(args, '--difficulty');
  final raw = args.contains('--raw');

  if (seedStr == null || diffStr == null) {
    stderr.writeln('Error: --seed と --difficulty は必須です。--help を参照してください。');
    exit(1);
  }
  final seed = int.tryParse(seedStr);
  if (seed == null) {
    stderr.writeln('Error: --seed には整数を指定してください。');
    exit(1);
  }
  final difficulty = _parseDifficulty(diffStr);
  if (difficulty == null) {
    stderr.writeln(
      'Error: --difficulty には easy / normal / hard を指定してください。',
    );
    exit(1);
  }

  _runSingle(seed: seed, difficulty: difficulty, raw: raw);
}

// ── ヘルパー ────────────────────────────────────────────────────────────────

String? _argValue(List<String> args, String key) {
  final prefix = '$key=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

Difficulty? _parseDifficulty(String s) => switch (s) {
      'easy' => Difficulty.easy,
      'normal' => Difficulty.normal,
      'hard' => Difficulty.hard,
      _ => null,
    };

void _printHelp() {
  print('''
puzzle_inspector — パズル検証ツール（仕様書 § 19 マイルストーン用）

使い方:
  dart run tool/puzzle_inspector.dart --help
  dart run tool/puzzle_inspector.dart --seed=<整数> --difficulty=<easy|normal|hard> [--raw]
  dart run tool/puzzle_inspector.dart --stats [--count=<整数>]

オプション:
  --seed=<整数>          乱数シード（単発モード必須）
  --difficulty=<難易度>  easy / normal / hard（単発モード必須）
  --raw                  PuzzleGenerator.construct() の検証前盤面も表示（単発モード）
  --stats                統計モード: seed 0..count-1 で難易度別に集計する
  --count=<整数>         統計モードの件数（既定 1000）

座標系: (y, x) = (row, col)（ADR-0006）。y 昇順=上→下、x 昇順=左→右。

lib/ は変更しない開発専用ツール。終了コード: 0=成功, 1=失敗/FAIL。''');
}

// ── 単発モード ──────────────────────────────────────────────────────────────

void _runSingle({
  required int seed,
  required Difficulty difficulty,
  required bool raw,
}) {
  final result = VerifiedPuzzleGenerator.generate(
    difficulty: difficulty,
    seed: seed,
  );

  switch (result) {
    case Err(:final error):
      stderr.writeln('生成失敗: $error');
      exit(1);
    case Ok(:final value):
      _printBoard(value.puzzle, title: '=== 検証済みパズル ===');
      print('difficulty   : ${difficulty.name}');
      print('seed         : $seed');
      print('solutionCount: ${value.solutionCount}');
      print('attemptsUsed : ${value.attemptsUsed}');
      print('isFallback   : ${value.isFallback}');
      _printLegend(value.puzzle.blocks);
  }

  if (raw) {
    print('');
    _printRaw(seed: seed, difficulty: difficulty);
  }
}

/// 盤面を boundingBox 範囲で ASCII 表示する。
///
/// blocks[i] の cells に当たるマスに A, B, C… を割り当て、
/// frame 外（boundingBox 内でも frame に属さない）はスペースで表示する。
void _printBoard(GeneratedPuzzle puzzle, {String title = ''}) {
  if (title.isNotEmpty) print(title);

  final cellToBlock = <Cell, int>{};
  for (var i = 0; i < puzzle.blocks.length; i++) {
    for (final cell in puzzle.blocks[i].cells) {
      cellToBlock[cell] = i;
    }
  }

  final bb = puzzle.boundingBox;
  for (var y = bb.minY; y <= bb.maxY; y++) {
    final sb = StringBuffer();
    for (var x = bb.minX; x <= bb.maxX; x++) {
      final idx = cellToBlock[(y, x)];
      sb.write(idx != null ? String.fromCharCode(65 + idx) : ' ');
    }
    print(sb.toString());
  }
}

void _printLegend(List<PlacedBlock> blocks) {
  final parts = [
    for (var i = 0; i < blocks.length; i++)
      '${String.fromCharCode(65 + i)}=${blocks[i].source.id}',
  ];
  print('凡例         : ${parts.join('  ')}');
}

/// --raw 用: PuzzleGenerator.construct() を直接呼んで検証前の盤面と解数を表示する。
void _printRaw({required int seed, required Difficulty difficulty}) {
  print('=== 検証前（PuzzleGenerator.construct 直呼び / seed=$seed）===');
  try {
    final raw = PuzzleGenerator.construct(difficulty: difficulty, seed: seed);
    _printBoard(raw);
    final shapes = raw.blocks.map((b) => b.source).toList();
    // limit=10 で解数を確認（最大 10 まで）
    final count = PuzzleSolver.countSolutions(
      frame: raw.frame,
      shapes: shapes,
      limit: 10,
    );
    print('countSolutions（limit=10）: $count');
    _printLegend(raw.blocks);
  } on GenerationFailedException catch (e) {
    print('construct() 失敗（スキップ）: $e');
  }
}

// ── 統計モード ──────────────────────────────────────────────────────────────

bool _runStats(int count) {
  print('仕様書 § 19 マイルストーン「生成失敗率1%以下」の判定');
  print('seed: 0..${count - 1}  count=$count');
  print('');

  var allPass = true;
  for (final diff in Difficulty.values) {
    stdout.write('[${diff.name} 集計中...]');
    final stats = _collectStats(difficulty: diff, count: count);
    stdout.writeln(' 完了');
    _printStats(difficulty: diff, count: count, stats: stats);
    if (!stats.pass) allPass = false;
  }

  print('総合判定: ${allPass ? "PASS" : "FAIL"}');
  return allPass;
}

class _Stats {
  _Stats({
    required this.failCount,
    required this.fallbackCount,
    required this.successCount,
    required this.dist,
    required this.attemptsTotal,
    required this.attemptsMax,
    required this.timeTotalUs,
    required this.timeMaxUs,
    required this.totalCount,
  });

  final int failCount;
  final int fallbackCount;
  final int successCount;
  final Map<int, int> dist;
  final int attemptsTotal;
  final int attemptsMax;
  final int timeTotalUs;
  final int timeMaxUs;
  final int totalCount;

  double get failRate => totalCount > 0 ? failCount / totalCount : 0.0;
  bool get pass => failRate <= 0.01;
}

_Stats _collectStats({required Difficulty difficulty, required int count}) {
  var failCount = 0;
  var fallbackCount = 0;
  var successCount = 0;
  final dist = <int, int>{};
  var attemptsTotal = 0;
  var attemptsMax = 0;
  var timeTotalUs = 0;
  var timeMaxUs = 0;

  for (var seed = 0; seed < count; seed++) {
    final sw = Stopwatch()..start();
    final result = VerifiedPuzzleGenerator.generate(
      difficulty: difficulty,
      seed: seed,
    );
    sw.stop();
    final us = sw.elapsedMicroseconds;
    timeTotalUs += us;
    if (us > timeMaxUs) timeMaxUs = us;

    switch (result) {
      case Err():
        failCount++;
      case Ok(:final value):
        successCount++;
        if (value.isFallback) fallbackCount++;
        final sc = value.solutionCount;
        dist[sc] = (dist[sc] ?? 0) + 1;
        attemptsTotal += value.attemptsUsed;
        if (value.attemptsUsed > attemptsMax) attemptsMax = value.attemptsUsed;
    }
  }

  return _Stats(
    failCount: failCount,
    fallbackCount: fallbackCount,
    successCount: successCount,
    dist: dist,
    attemptsTotal: attemptsTotal,
    attemptsMax: attemptsMax,
    timeTotalUs: timeTotalUs,
    timeMaxUs: timeMaxUs,
    totalCount: count,
  );
}

void _printStats({
  required Difficulty difficulty,
  required int count,
  required _Stats s,
}) {
  final failRatePct = (s.failRate * 100).toStringAsFixed(2);
  final fbRate = s.successCount > 0
      ? '${(s.fallbackCount / s.successCount * 100).toStringAsFixed(2)}%'
      : '–';
  final avgAttempts = s.successCount > 0
      ? (s.attemptsTotal / s.successCount).toStringAsFixed(2)
      : '–';
  final avgTimeMs =
      count > 0 ? (s.timeTotalUs / count / 1000).toStringAsFixed(3) : '–';
  final maxTimeMs = (s.timeMaxUs / 1000).toStringAsFixed(3);

  final dist1 = s.dist[1] ?? 0;
  final dist2 = s.dist[2] ?? 0;
  final dist3 = s.dist[3] ?? 0;
  final dist4plus = s.dist.entries
      .where((e) => e.key >= 4)
      .fold<int>(0, (sum, e) => sum + e.value);

  final judgment = s.pass ? 'PASS' : 'FAIL';
  print('─── ${difficulty.name} (count=$count) $judgment ───');
  print('  ハード失敗数    : ${s.failCount}件 / 失敗率 $failRatePct%  → $judgment');
  print(
    '  フォールバック  : ${s.fallbackCount}件 / 率 $fbRate'
    '（成功${s.successCount}件中）',
  );
  print('  解数分布        : 1解=$dist1  2解=$dist2  3解=$dist3  4以上=$dist4plus');
  print('  試行回数(平均/最大): $avgAttempts / ${s.attemptsMax}');
  print('  生成時間ms(平均/最大): $avgTimeMs / $maxTimeMs');
  print('');
}
