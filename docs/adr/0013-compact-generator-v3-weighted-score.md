# ADR-0013: 重み付きスコア選択によるコンパクト枠生成層 V3 (CompactPuzzleGeneratorV3) の導入

## Status
Proposed (2026-06-06)

## Context

### 解決したい問題
ADR-0012 の CompactPuzzleGeneratorV2（接触辺数の同点時に外接矩形面積を見るタイブレーク）を PR #54 で導入し、CI 実測（seed=1..300）で easy 0.68→0.73・normal 0.61→0.64・hard 0.60→0.64 と全難易度で非退行の改善を得た。easy は目標（本物ウボンゴ平均 約72%）に到達したが、normal/hard は 0.64 にとどまり目標に約8ポイント届かない。

### 原因
V2 のタイブレークは「接触辺数が最大の候補が複数ある（同点）」ときにしか作用しない。接触辺数が最大の候補が1つに決まる場面では、外への広がりに関係なくその候補が選ばれる。このため外への伸びを十分に抑えきれず、normal/hard で頭打ちになっている。

### 現状の部品（いずれも CLAUDE.md により変更禁止）
- PuzzleGenerator.construct / listPlacementCandidates / listBoundaryCells / isAdjacent
- PuzzleSolver.countSolutions
- isFrameSimplyConnected（ADR-0009）
- VerifiedPuzzleGenerator.generate（ADR-0008）
- PlayablePuzzleGenerator.generate（ADR-0009）
- CompactPuzzleGenerator.generate / CompactPuzzleError（ADR-0010/0011、PR #50/#52）
- CompactPuzzleGeneratorV2.generate（ADR-0012、PR #54、本ADR以前の本番経路）

### 制約
- 上記はすべて変更禁止。座標系は (y, x) = (row, col)（ADR-0006）。
- エラー伝達は Result<T, E>（仕様書 §14.2, ADR-0005）。

### 前例
ADR-0008/0009/0010/0012 は確定資産を改造せず外側に新層を足す B 案で進めた。本 ADR も踏襲し、V2 を改造せず選び方を変えた新生成器を独立に追加する。

## Decision
新ファイル lib/domain/puzzle/compact_puzzle_generator_v3.dart を追加する。既存ファイルは一切変更しない。

### 判断1: 独立した新生成器として実装（B案）
V2 を改造せず、その性質（同形重複の禁止・解数1〜3採用・穴なし・サブシード再生成・フォールバックなし）をすべて引き継いだ上で、候補選択の規則だけを変えた新生成器を追加する。ゲーム本体はパズル取得に今後 CompactPuzzleGeneratorV3 を経由する規約とする（ADR-0012 判断1 をさらに更新）。

### 判断2: 候補選択を「重み付きスコア最大」に変更（本丸）
各候補を score(candidate) = contactEdges - LAMBDA * bboxAreaAfter で評価し、最大の候補を選ぶ（同点なら乱数）。contactEdges と bboxAreaAfter の定義は ADR-0012 と同じ。LAMBDA は名前付き定数 kBboxPenaltyLambda = 0.5（暫定）。接触辺数が最大でなくても外への広がりが十分小さければ選ばれるため、V2 のタイブレーク（同点時のみ作用）より広い場面でコンパクト化が効く。これは ADR-0012 の中立・申し送り「タイブレークだけで不十分なら接触辺数と外接矩形面積を重み付き合成したスコアを別 ADR で検討する」に直接対応する。

### 判断3: LAMBDA は単一の名前付き定数とし、値は測定で決める暫定値とする
LAMBDA を大きくするほどコンパクト寄り（長方形寄り）になり、小さくするほど V2 寄りになる。初期値 0.5 は暫定。CI の充填率測定で normal/hard が目標へ近づくか・easy が過剰に長方形化して退行しないかを確認し、必要なら別 ADR で再調整する。マジックナンバーを避け本ファイル冒頭の定数1つに集約する。

### 判断4: 検証・重複回避・サブシード派生・非フォールバックは V2 を踏襲
解数1〜3採用（4以上再生成）、単連結検証、同形重複回避、(seed, attempt) からの決定論的サブシード派生（32bit LCG、乗数1664525・加数1013904223、法2^32）、リトライ上限 maxCompactRetries=8、フォールバックなし、エラー型 CompactPuzzleError・成功型 VerifiedPuzzle の流用。すべて ADR-0008/0009/0010/0011/0012 と同一。

### 判断5: 効果測定は CI テストで「V2 と V3 を並べて」行う
Code Web は実行できないため測定は CI テストとして設計する（CLAUDE.md 恒久ルール⑤）。難易度ごとに多数 seed（既定300件）で V2 と V3 の平均充填率を並べて出力し、井川が CI ログで比較する。V3 は correctness を hard assert する。

### 判断6: 非自明性は引き続き対象外
長い棒・細いしっぽ等の非自明性は別軸であり本 ADR の対象外（ADR-0012 判断6 と同じ）。コンパクト化により副次的に減ることを見込むが、必要なら実機再観測の上で別途検討する。一度に複数を縛らない。

### 判断7: 一本化（整理フェーズ）は目標到達の確認後
本 ADR で V2 も本番経路から外れ死んだコードがさらに増える。CI で normal/hard が目標へ十分近づいたと確認できたら、次タスクとして生成層の一本化（Compact/V2/V3 と Verified/Playable の棚卸し）を行う。確定資産変更を伴うため井川の許可必須（ADR-0012 判断7 を継承）。

## Consequences

### ポジティブ
- normal/hard の充填率が V2 より目標へ近づく見込み。easy の非退行を CI で確認する。
- 確定資産に一切触れないため破壊リスクがゼロ。失敗時はファイル削除で戻せる。
- 調整点が LAMBDA 1つに集約され、コンパクト⇔ウボンゴらしさのバランスを1パラメータで扱える。

### ネガティブ
- V2 とほぼ同型のコードが重複し死んだコードがさらに増える。→ 対処: 判断7 の一本化で解消する。本層はその前提（最終的な選び方の確定）と位置づける。
- LAMBDA を大きくしすぎると長方形化してウボンゴらしさが減るリスク。→ 対処: CI 測定で easy の退行を監視し、判断3 のとおり値を再調整する。

### 中立・申し送り
- CI 測定で normal/hard がなお目標に届かない／easy が長方形化して退行する場合は、LAMBDA の再調整、または非線形なペナルティ（外接矩形でなく実外周や凸包など）の検討を別 ADR で行う。まず LAMBDA=0.5 の効果を1点測ってから判断する。
- 非自明性は別軸（判断6）。
- 生成層の一本化は目標到達後（判断7）。

## References
- docs/SPECIFICATION.md §4.3.2 / §4.3.3 / §14.2
- ADR-0005 / 0006 / 0007 / 0008 / 0009 / 0010 / 0011 / 0012
- 実測（PR #54）: easy 0.68→0.73 / normal 0.61→0.64 / hard 0.60→0.64、Err=0
