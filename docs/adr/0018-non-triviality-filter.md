# ADR-0018: 生成パズルの非自明性フィルタ (separable 棄却＆再生成)

- Status: Proposed (2026-06-21)

## Context

ADR-0017 で導入した計測専用層 (PuzzleMetrics) を多数 seed で実行し、井川 + Opus で
目視較正を行った。その結果:

- straightCutSeparable（枠を直線1本でピースを跨がせず2分割できる＝独立した小問題に
  分解でき自明）が、人の目で見た「易しさ」と最もよく一致する主指標だった。
- separable_rate は EASY 64% / NORMAL 36% / HARD 41%。
- 風車系（rotationalSymmetry90 / 180）は、現行のランダム埋め生成器ではほぼ発生せず、
  かつ正方形枠でしか定義されないため、フィルタには採用しない（記録のみ）。
- protrusionRatio は難易度が上がるほど低下（EASY 0.135 → HARD 0.096）し、補助指標として
  方向は正しい。
- orientationUsageRatio は EASY 0.567 / NORMAL 0.675 / HARD 0.650。解の約6割のピースは
  非カノニカル向きで嵌っているが、現行ゲームは回転・反転操作が無くその向きのまま手渡す。
  潜在的な回転の難しさをタダで捨てている。これは回転・反転の独立 ADR の根拠とする
  （本 ADR の対象外）。

ねらい: 「難しいはずなのに自明」な NORMAL/HARD パズルを減らし、噛み合った
（non-separable な）配置を標準にする。EASY は易しくて良い難易度なので対象外とする。

## Decision

### 判断1: 非自明性フィルタのラッパーを新規追加（B案踏襲）
新ファイル lib/domain/puzzle/non_trivial_puzzle_generator.dart を追加する。
CompactPuzzleGeneratorV3.generate を public API として呼び出すだけのラッパーとし、
生成器・ソルバ等の確定資産は一切変更しない。判定には ADR-0017 の computePuzzleMetrics
を用いる。

### 判断2: フィルタ対象は NORMAL / HARD のみ。EASY は素通し
EASY は 64% が separable だが、易しいこと自体が適正な難易度設計であり、ここを弾くと
再試行コストの割に旨みが薄い。NORMAL/HARD で separable が出る「難しいはずなのに自明」を
主たる是正対象とする。EASY は V3 の結果をそのまま返す。

### 判断3: separable 棄却＆再生成
maxAttempts（既定 20）以内で seed を変えながら生成し、最初に得られた non-separable
(straightCutSeparable == false) なパズルを採用する。NORMAL/HARD で non-separable が
得られる確率は約 0.6 なので、平均 1.5〜1.7 回程度の試行で済む見込み。

### 判断4: フォールバックは「protrusion 最小の separable 候補」。プレイヤーを止めない
maxAttempts を使い切っても non-separable が得られない稀なケースでは、生成済み候補のうち
protrusionRatio が最小のものを返す。生成は決して「パズル無し」を返してはならない。
VerifiedPuzzle.isFallback の意味は既存（ソルバ検証由来）のまま保持し、非自明性
フォールバックでこのフラグを上書きしない（混同を避ける）。

### 判断5: 風車系はフィルタ不採用
rotationalSymmetry90 / 180 は較正の結果フィルタに用いない。PuzzleMetrics 上の指標
としては残し、将来の観測・回転導入後の再評価に備える。

### 判断6: 呼び出し側を新ラッパーへ切替
現在パズル生成を呼んでいる箇所（確定資産外のアプリ層）を、新ラッパー経由に切り替える。
切替先が不明・確定資産内である場合は、実装を止めて報告する（推測で改変しない）。

### 判断7: 効果確認（測ってから次の思想）
フィルタ適用後、NORMAL/HARD の separable_rate がほぼ 0 になることをレポートテストで
確認する。これは ADR-0010 判断5「本丸 → 効果確認 → 次」を踏襲する。

## Consequences

### ポジティブ
- 「難しいはずなのに自明」な NORMAL/HARD パズルが大幅に減る。
- 生成器の中核に触れない最小リスクの変更（B案）。
- プレイヤーを決して止めないフォールバック設計。

### ネガティブ
- NORMAL/HARD の生成試行が平均 1.5〜1.7 倍に増える（許容範囲）。
- EASY は対象外のため separable が残るが、これは意図的。

## References
- ADR-0017（非自明性メトリクス計測専用層、本 ADR の前提）
- ADR-0010 判断5（本丸 → 効果確認 → 次）
- ADR-0008（確定資産を改造せず外側に足す B案）
