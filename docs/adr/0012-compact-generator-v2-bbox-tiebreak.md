# ADR-0012: 充填率を高めるコンパクト枠生成層 V2 (CompactPuzzleGeneratorV2) の導入

## Status
Accepted (2026-06-06) — PR #54 で develop にマージ済み

## Context

### 解決したい問題
ADR-0010 で接触辺数の最大優先選択（CompactPuzzleGenerator）を導入し、normal/hard の充填率は約30%台から改善した。しかし実機プレビュー（seed 8/13/4 を目視）で、easy は充填率80%と良好な一方、normal/hard は依然57%付近にとどまり、本物ウボンゴの平均（約72%）に届いていない。加えて normal/seed=13 に縦4マスの直線棒、hard/seed=4 に1マスの突起や細いしっぽが見られ、「スカスカ・細長い」傾向が残る。

### 原因
CompactPuzzleGenerator は接触辺数が最大の候補を選ぶが、同点（接触辺数が等しい候補が複数）のときはランダムに選ぶ（ADR-0010 判断2）。塊の外周は広く、同点候補の多くは「外へ伸びる置き方」であるため、ランダム選択では外へ伸びがちになる。これが充填率の頭打ちの直接原因。

### 現状の部品（いずれも CLAUDE.md により変更禁止）
- PuzzleGenerator.construct / listPlacementCandidates / listBoundaryCells / isAdjacent
- PuzzleSolver.countSolutions
- isFrameSimplyConnected（ADR-0009）
- VerifiedPuzzleGenerator.generate（ADR-0008）
- PlayablePuzzleGenerator.generate（ADR-0009）
- CompactPuzzleGenerator.generate / CompactPuzzleError（ADR-0010 / 0011、PR #50 / #52、現在の本番経路）

### 制約
- 上記はすべて変更禁止。CompactPuzzleGenerator は ADR-0011 で禁止リスト登録済み。
- 座標系は (y, x) = (row, col)（ADR-0006）。
- エラー伝達は Result<T, E>（仕様書 §14.2, ADR-0005）。

### 前例
ADR-0008/0009/0010 は construct の外側に層を被せる B 案で確定資産を守った。本 ADR もこれを踏襲する。ただし対象は「フィルタ」ではなく「生成の選び方」なので、CompactPuzzleGenerator を改造せず、選び方を改良した新しい生成器を独立に追加する。

## Decision
新ファイル lib/domain/puzzle/compact_puzzle_generator_v2.dart を追加する。既存ファイルは一切変更しない。

### 判断1: 独立した新生成器として実装（B案）
CompactPuzzleGenerator を改造せず、その性質（同形重複の禁止・解数1〜3採用・穴なし・サブシード再生成・フォールバックなし）をすべて引き継いだ上で、候補選択のタイブレークだけを変えた新生成器を追加する。ゲーム本体はパズル取得に今後 CompactPuzzleGeneratorV2 を経由する規約とする（ADR-0010 判断1 をさらに更新）。

### 判断2: タイブレークを「外接矩形の面積が最小になる置き方」に変更（本丸）
候補選択を次の順序とする。
1. 接触辺数が最大の候補に絞る（ADR-0010 判断2 のまま、主役）。
2. その中で、配置後の枠（既配置セル ∪ 候補セル）の外接矩形の面積が最小になる候補を選ぶ。
3. なお同点なら、シード付き乱数で1つ選ぶ（決定論性を保つ）。
接触辺数の最大優先を主役に保ったまま、同点時に「外へ広げない置き方」を選ぶことで、ピースが内側に詰まり充填率が上がる。充填率を直接しきい値で縛らず選び方で自然に上げる点は ADR-0010 判断5 の思想を踏襲する。

### 判断2の補足: ADR-0009 で却下した「外周最小化」とは別物
ADR-0009 は「外周の辺数を最小化する」を主目的にすると長方形へ寄りウボンゴらしさが消えるため却下した。本判断は外接矩形面積をあくまで同点時のタイブレーク（脇役）に用いるのみで、主役は接触辺数最大のままである。したがって長方形化はせず、デコボコは保たれる。将来の読み手が「ADR-0009 で却下したのでは」と誤解しないよう明記する。

### 判断3: 解数検証・穴検証・同形重複回避・サブシード派生はそのまま引き継ぐ
解数は countSolutions(limit:4) で 1〜3 を採用し4以上は再生成（ADR-0008/0010）。穴は isFrameSimplyConnected で検証（ADR-0009/0010）。同形 source の重複は生成段階で候補から除外（ADR-0011）。(seed, attempt) から決定論的にサブシードを派生（32bit LCG、乗数1664525・加数1013904223・法2^32。hashCode は使わない）。private 関数は再利用できないため新ファイルに同種の小関数を持ち、dartdoc に出自を明記する。検証リトライ上限は名前付き定数 maxCompactRetries = 8。

### 判断4: フォールバックしない／エラー型は CompactPuzzleError を流用
ADR-0009/0010 と同じくフォールバックを持たない。8回すべて失敗したら Err を返す。エラーモードは Compact と同一（生成失敗・品質未達）なので新規 enum を作らず既存の CompactPuzzleError { generationFailed, qualityNotMet } を流用する。成功型も VerifiedPuzzle を流用（isFallback は常に false）。公開メソッドは Result<VerifiedPuzzle, CompactPuzzleError> を返す。

### 判断5: 効果測定は CI テストで「旧 Compact と新 V2 を並べて」行う
Code Web 環境は実行できないため効果測定は CI のテストとして設計する（CLAUDE.md 恒久ルール⑤）。難易度ごとに多数 seed（既定300件）を生成し、旧 Compact と新 V2 の平均充填率を並べて出力し、井川が CI ログで比較する。新 V2 は correctness を hard assert する。

### 判断6: 非自明性は本 ADR の対象外（ただし副次的な改善を見込む）
長い棒・細いしっぽ等の非自明性は別軸であり本 ADR の対象外（ADR-0009/0010/0011 と同じ整理）。ただし棒やしっぽは「外への突起」でもあるため、判断2 により副次的に減ることを見込む。マージ後に実機で残存頻度を再観測し、なお目立つ場合に限り別途（ADR-0013 候補）非自明性メトリクスを検討する。一度に複数を縛らない（ADR-0010 判断5 の教訓）。

### 判断7: 生成層の一本化（整理フェーズ）は本改良の実証後に行う
本 ADR により Verified/Playable に続いて Compact も本番経路から外れ死んだコードが増える。ADR-0010 が予告した「Compact が十分な品質を出せたら一本化を検討」という整理フェーズの引き金が本改良の実証後である。CI で充填率が目標に届いたら、次タスクとして生成層の棚卸し・一本化（確定資産変更を伴うため井川の許可必須）を行う。

## Consequences

### ポジティブ
- normal/hard の充填率が目標（約72%）へ近づく見込み。easy の非退行を CI で確認する。
- 確定資産に一切触れないため ADR-0007 が問題視した破壊リスクがゼロ。失敗時はファイル削除で戻せる。
- 外接矩形面積という単一メトリクスのタイブレークのみで、チューニング parameter を持たず解釈しやすい。

### ネガティブ
- Compact とほぼ同型のコードが重複し死んだコードが増える（Verified/Playable に続き Compact も本番から外れる）。→ 対処: 判断7 の整理フェーズで一本化する。本改良はその前提（正しい選び方の実証）と位置づける。
- 解数検証・穴検証・サブシード派生が ADR-0008/0009/0010 と一部重複する。→ 対処: dartdoc で各 ADR を参照し許容（既存判断と同じ）。

### 中立・申し送り
- CI 測定で normal/hard の平均充填率がなお72%に届かない場合、タイブレークだけでは不十分なサイン。次手として接触辺数と外接矩形面積を重み付き合成したスコア（contact − λ・bboxArea の最大化）や別メトリクスを別 ADR で検討する。まず本タイブレークの効果を1つだけ測ってから判断する。
- 非自明性（長い棒・風車状の自明配置）は別軸。判断6 のとおり再観測後に別途検討。
- 仕様書 §4.3.4（seed 文字列）と実装（seed int）の不整合（Issue #31）はステージ2の課題として保留。

## 実測結果（PR #54 / CI、seed=1..300）
- easy : OLD avg fill 0.68 → NEW 0.73（目標72%に到達）。Err=0。
- normal: OLD avg fill 0.61 → NEW 0.64（+3pt、目標未達）。Err=0。
- hard : OLD avg fill 0.60 → NEW 0.64（+4pt、目標未達）。Err=0。
- correctness（解数1〜3・単連結・同形重複なし・isFallback=false）は全難易度で hard assert を通過。
- 判定: タイブレークは全難易度で非退行の改善を確認。easy は卒業。normal/hard は中立・申し送りの「重み付きスコア」を次手（ADR-0013）として実施する。

## References
- docs/SPECIFICATION.md §4.3.2 / §4.3.3 / §14.2
- ADR-0005 / 0006 / 0007 / 0008 / 0009 / 0010 / 0011
- CompactPuzzleGenerator（PR #50）, 同形重複回避（PR #52）
- 実機観測: easy/seed=8 充填率80%、normal/seed=13 57%・縦4直線棒、hard/seed=4 57%・突起/しっぽ
