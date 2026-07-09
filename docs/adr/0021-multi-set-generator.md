# ADR-0021: multi-set 生成 capability (MultiSetPuzzleGenerator) の追加

- Status: **Accepted**(capability 範囲・Opus 判断で確定 2026-07-xx / Fable レビューは
  重 API 回避のため任意)。**消費モデル(⑥-c)は未確定=open**。実機評価後に本 ADR を追補する。
- 前提: ⑥-a 計測CI(PR #101)。ADR-0020(枠ファースト生成器)。
- 分割: ⑥-a=計測(済) / ⑥-b=本 ADR の capability(本 PR) / ⑥-c=消費側配線(別 PR・未着手)。

## Context

### 目的
実物ウボンゴの「1枠を複数通りで解く」に対応し、1つの枠から相異なる採用ピースセットを
複数取得する capability を用意する。効果は (1) 「少し似た枠」でも中身(分割)が変われば別
パズルとして成立しバリエーションが増える、(2) 将来のデイリー/タイムアタック(全員同じ枠)の
下地(ADR-0020 判断10)。

### ⑥-a 計測結果(PR #101・実パイプラインの採用ルール適用後の distinct 採用構成数/枠)
- easy  : 中央値3 / 最大12 / 最小0
- normal: 中央値72 / 最大213 / 最小20(うち非separable 中央値39)
- hard  : 中央値107 / 最大315 / 最小0(うち非separable 中央値56)

含意: 1枠→複数セットは技術的に十分成立(normal/hard は中央値でも数十〜百通り)。ただし
easy/hard に「採用0の枠(min=0)」が存在するため、K を固定要求せず best-effort とする。
また「採用数 = distinct構成数」が全難易度で一致したため、追加の重複排除は不要。

### 現状の消費側(参考・本 ADR では変更しない)
play_screen は generateSelectedPuzzle(difficulty, seed) で1枠→1セットを受け取り、「次へ」で
新 seed=新枠を出す。同一枠を複数セットで解く導線は存在しない。これをどう変えるか(消費モデル)は
プロダクト判断であり、feasibility 数値からは導けないため本 ADR では確定しない(下記 判断6)。

## Decision

### 判断1: 新ファイルでラップ追加(B案)。確定資産は不変。
lib/domain/puzzle/multi_set_puzzle_generator.dart を新規追加。FrameGenerator /
enumerateDistinctPieceSets / FrameTiler / PuzzleSolver.countSolutions /
computePuzzleMetrics を変更せず利用する。FrameFirstPuzzleGenerator も変更しない
(採用判定ロジックは本ファイル内に同型で持つ。B案の許容する重複)。

### 判断2: API と戻り値
generate({required Difficulty, required int seed, int maxVariants=8, int maxAttempts=20})
→ Result<MultiSetPuzzle, CompactPuzzleError>。
MultiSetPuzzle = { Set<Cell> frame, String canonicalKey, List<VerifiedPuzzle> variants }。
各 variant は同一 frame を過不足なく敷く別構成。variants.length は 1..maxVariants。

### 判断3: best-effort(K は上限であって割当数ではない)
採用セットを走査順に最大 maxVariants 個集める。採用0の枠は次サブシードの枠へ。全試行で
採用0のとき Err(anyFrame あり=qualityNotMet / 枠生成すら不可=generationFailed)。easy は
実際に3前後しか返らないことがあるが正常(⑥-a min=0/中央値3 と整合)。

### 判断4: distinctness = ピース構成(source id multiset)
列挙器が構成の重複を出さないため、走査で得た採用セットは自動的に相異なる構成になる
(⑥-a で採用数=distinct構成数を確認済み)。追加の dedup は行わない。「K 個が知覚的に
十分違って見えるか(構成が似た variant の体感差)」は未検証=将来のポリッシュ(YAGNI)。

### 判断5: 採用選別は ADR-0018/0020 を踏襲
easy はフィルタ対象外。normal/hard は非separable(良形)を優先採用し、maxVariants に満たない
ときのみ protrusionRatio 昇順で separable を補充する(同一枠内・count は遅延評価)。
FrameFirstPuzzleGenerator が「単一の best を全 attempt 横断で保持」するのに対し、本器は
「同一枠内でフォールバックを解決」する簡素化を採る(意図的な差。⑥-a で非separable が
潤沢=典型ケースでは差が出ない)。

### 判断6: 消費モデルは open(⑥-c・実機評価で確定)
「同じ枠を『次へ』で巡回(A1)」か「枠を選び1構成をランダム出題(A2)」等は、体感優先の
プロダクト判断として実機評価で決める。本 ADR は capability のみを確定し、消費側配線を
ブロックしない位置づけ。決定後に本 ADR を追補する。

### 判断7: 決定論・枠選定
セット走査順は FrameFirstPuzzleGenerator と同一のサブシード派生で Fisher-Yates
シャッフル。枠は単一生成と同じ決定論プロセスで得る(選び直さない=easy 枠単調問題・
ADR-0020 判断6 を再発させない)。同じ (difficulty, seed, maxVariants) は常に同一結果。
典型ケースでは variants.first は単一生成の結果と一致する意図。

### 判断8: frozen 登録
本ファイルと frame-first 系4ファイル(frame_generator / frame_tiler /
piece_set_enumerator / frame_first_puzzle_generator)を CLAUDE.md の変更禁止リストへ
登録する(以後はラップして追加)。

## Consequences

### ポジティブ
- 1枠→複数セットのウボンゴ的体験の土台が完成。確定資産は不変で失敗時の影響が局所的。
- canonicalKey 保持によりデイリー/タイムアタックの枠ID下地が整う。
- capability は消費者ゼロでも性質テスト(決定論・被覆・up-to-K・distinct構成)が CI で叩く。

### ネガティブ / 申し送り
- 採用判定ロジックが FrameFirstPuzzleGenerator と一部重複(B案の許容範囲。将来の生成層
  一本化・ADR-0013 判断7 の棚卸し対象に含める)。
- 判断5 のフォールバックは frame-first と探索粒度が微差(同一枠内 vs 全attempt横断)。
  典型ケースでは非顕在だが、稀な all-separable 枠で結果が分岐しうる点を明記しておく。
- 消費モデル(判断6)が未確定。⑥-c で実機評価のうえ追補する。

## References
- ADR-0020(枠ファースト生成器・判断4正準形/判断7非自明性/判断10将来下地)
- ⑥-a 計測: PR #101 / docs/handoff/LATEST.md
- ADR-0008(解数1〜3・VerifiedPuzzle)/ ADR-0017(metrics)/ ADR-0018(非自明性フィルタ)
