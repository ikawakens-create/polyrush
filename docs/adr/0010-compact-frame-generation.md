# ADR-0010: 噛み合い優先のコンパクト枠生成層 (CompactPuzzleGenerator) の導入

## Status

Proposed (2026-06-06)

## Context

### 解決したい問題

実機プレビュー（候補A / PR #47）での目視確認により、生成される枠が
本物のウボンゴと比べて「スカスカで細長い」ことが判明した。プレビューに
充填率表示を追加して観測した結果、normal / hard では充填率が 60% を
超えることが稀で、多くが 30% 台であった。

本物ウボンゴの台紙9枚を実測した充填率は平均約 72%（範囲 60〜92%）で、
「ほぼ長方形だが角が1〜2マス欠けた」コンパクトな形が大多数である。
ウボンゴの面白さの核は「3〜5個のピースがどう組み合わさってこの塊に
なるのか」という意外性であり、ピース同士が深く噛み合っていることが前提。
現状のスカスカな枠ではピースの境界が一目で分かり、その意外性が失われている。

### 原因（コード調査で特定）

PuzzleGenerator.construct（確定資産）の配置ロジックを調査した結果、
原因は候補選択の1行に特定された:

```dart
final chosen = candidates[random.nextInt(candidates.length)];
```

listPlacementCandidates が「1辺以上隣接する有効な全候補」を列挙した後、
その中から完全ランダムに1つを選んでいる。優先順位・スコアリングは無い。
塊の外周は広いため候補の大多数は「外へ伸びる位置」であり、ランダム選択
ではほぼ毎回それが選ばれる。これがスカスカ・細長い枠が生まれる直接原因。

### 現状の部品（いずれも CLAUDE.md により変更禁止）

- PuzzleGenerator.construct({difficulty, seed, ...}): 枠を1個生成。品質判定なし。
- PuzzleGenerator.listPlacementCandidates(oriented, placedCells):
  配置候補を全列挙する @visibleForTesting 公開関数。
- PuzzleGenerator.listBoundaryCells / isAdjacent: 同じく公開済み補助関数。
- PuzzleSolver.countSolutions({frame, shapes, limit}): 解数を limit 頭打ちで数える。
- isFrameSimplyConnected(frame): 単連結性を判定する独立公開関数（ADR-0009）。
- VerifiedPuzzleGenerator.generate({difficulty, seed}): 解数検証層（ADR-0008）。
- PlayablePuzzleGenerator.generate({difficulty, seed}): 穴検証層（ADR-0009）。

調査で判明した制約:
- Verified / Playable はいずれも「seed を渡して内部で construct させる」
  入り口しか持たず、「出来上がった枠を外から受け取って検証だけする」
  入り口を持たない。よって Compact が作った枠を既存層に渡して検証だけ
  させることはできない。

### 制約

- puzzle_generator.dart / solver.dart / verified_puzzle_generator.dart /
  playable_puzzle_generator.dart / frame_connectivity.dart / difficulty.dart /
  result.dart は変更禁止（CLAUDE.md）。
- 座標系は (y, x) = (row, col)（ADR-0006）。
- ドメイン層のエラー伝達は Result<T, E> を用いる（仕様書 § 14.2, ADR-0005）。

### 前例

ADR-0008・0009 は construct の外側に検証層を「被せる」ことで確定資産を
守った。本 ADR はその思想を踏襲するが、フィルタ（選別）ではなく
ジェネレータ（生成の仕方）の問題であるため、被せるだけでは解決しない。
母集団の大多数が低品質なため、しきい値フィルタでは Err 連発になる。
よって「生成の段階で良い枠を作る」新しい生成器そのものを追加する。

## Decision

新ファイル lib/domain/puzzle/compact_puzzle_generator.dart を追加する。
既存ファイルは一切変更しない。以下、7つの設計判断を確定する。

### 判断 1: Compact を独立した最外層の生成器として実装する（B案）

construct を改造せず、また Verified / Playable も呼ばない、独立した
生成器として新規実装する。Compact は公開済み部品
（listPlacementCandidates / countSolutions / isFrameSimplyConnected）を
組み合わせて、自前で「生成 → 解数検証 → 穴検証」を行う。

ゲーム本体はパズル取得に今後 CompactPuzzleGenerator を経由する規約とする
（ADR-0008 判断6・ADR-0009 判断4をさらに更新）。

理由: 原因はフィルタではなく生成ロジックにあるため、Verified/Playable を
被せても無力。生成段階で噛み合いを優先する新生成器が必要。Verified/Playable
には「出来上がった枠を検証だけする入り口」が無いため、それらを再利用する
には @visibleForTesting の overrideConstruct を本番転用するか確定資産変更が
必要になり、いずれも歪む。独立実装が最も素直。

### 判断 2: 候補選択は「接触辺数 最大優先、同点はランダム」（本丸）

Compact の核。construct のランダム選択を、噛み合い優先の選択に置き換える。

- listPlacementCandidates で候補を全列挙する（construct と同じ部品を使う）。
- 各候補について「接触辺数」を数える。接触辺数 = その候補ピースの各セルが、
  既配置セルと辺で接している箇所の総数。
- 接触辺数が最大の候補を選ぶ。最大が複数あればその中からランダムに1つ
  （自然な多様性を残すため）。

接触辺数を最大化すると、ピースが深く噛み合い、結果として枠が四角く詰まる。
充填率を直接計算せずとも、噛み合いを最大化することで充填率は自然に上がる。

### 判断 3: 解数検証は countSolutions を limit=4 で自前で呼ぶ

生成した枠の解数を countSolutions（limit=4）で数え、4 未満（1〜3）なら
採用、4 以上なら再生成する。閾値と意味は ADR-0008 を踏襲する。

ADR-0008 のロジックと一部重複するが、ADR-0009 のサブシード派生重複と
同様に許容する。dartdoc に ADR-0008 への参照を明記する。
Compact は噛み合い優先で質の良い枠を作るため、解数過多で弾かれる率は
低いと見込む（実測はテストで行う / 後述）。

### 判断 4: 穴検証は isFrameSimplyConnected を自前で呼ぶ

ADR-0009 の単連結判定を流用する。これは独立公開関数なのでそのまま呼べる。
噛み合い優先で詰めた枠は穴が空きにくいと見込むが、保証はしないため検証は
必須とする。

### 判断 5: 充填率の下限チェックは入れない（まず本丸だけ）

判断 2 の噛み合い優先により充填率は自然に上がるはずであり、充填率の下限
チェック（しきい値フィルタ）は導入しない。理由:

- 原因（ランダム選択）を直接断つ判断 2 が本丸であり、充填率チェックは
  対症療法。二重に縛ると Err が増える。
- まず判断 2 のみで実機の充填率を観測し（プレビューに表示済み）、それでも
  不足なら別 ADR で充填率下限や別メトリクスを足す。1つずつ効果を確認する。

### 判断 6: リトライ・サブシード派生・フォールバック

- 解数過多または穴ありで没にした場合、(seed, attempt) から決定論的に
  サブシードを派生させて再生成する。派生は ADR-0008/0009 と同系の
  32bit LCG（Numerical Recipes 乗数 1664525・加数 1013904223、法 2^32）。
  hashCode は使わない。
- 検証リトライ上限は名前付き定数 maxCompactRetries = 8。
- フォールバックは持たない（ADR-0009 判断6と同じ思想）。スカスカ・穴あき・
  解数過多はいずれも「提示すべきでない品質」であり、妥協提示しない。
  8回すべて失敗したら Err を返す。

### 判断 7: エラー型は新規 enum、成功型は VerifiedPuzzle を流用

成功型は新設せず VerifiedPuzzle を流用する（型の表面を最小化）。
solutionCount / attemptsUsed / isFallback フィールドを持つが、Compact は
フォールバックしないため isFallback は常に false とする。

エラー型は新規 enum CompactPuzzleError { generationFailed, qualityNotMet }
を定義する。
- generationFailed: 全試行で construct 相当の枠生成自体に失敗（候補枯渇）。
- qualityNotMet: 生成はできたが、全試行で解数過多または穴ありだった。

公開メソッドは Result<VerifiedPuzzle, CompactPuzzleError> を返す。

## Consequences

### ポジティブ

- 噛み合い優先により、本物ウボンゴに近いコンパクトな枠が生成される見込み。
- 確定資産に一切触れない。ADR-0007 が問題視した破壊リスクがゼロ。
- 公開済み部品の組み合わせで実現でき、失敗時はファイル削除で元に戻せる。
- 接触辺数という単一メトリクスで、井川が指摘した「噛み合いの浅さ」を
  直接狙い撃ちにできる。

### ネガティブ

- 解数検証ロジックが ADR-0008 と一部重複する（dartdoc 参照で許容）。
- Compact 導入により Verified / Playable が本番経路から外れ、テスト・ツール
  以外で使われなくなる（死んだコード化の懸念）。→ 下記「技術的負債」参照。

### 中立・申し送り

- 技術的負債（重要）: 本来、スカスカな枠の根本原因は construct の
  候補ランダム選択にある。理想は construct 側の修正だが、確定資産であること・
  影響範囲が大きいことから、現時点では外側の新生成器で対処する。この
  「外側に積む」方式は層が増えるほど保守性が下がるリスクがあり、特に
  Compact 導入後は Verified / Playable が本番経路から外れ死んだコードに
  なる懸念がある。将来、Compact が実機で十分な品質を出せたら、その知見を
  元に生成層全体を棚卸しし、construct への一本化（リファクタリング）を
  検討する。本件は宿題リストに「整理フェーズ」として明記する。

- 解数過多・穴の却下率（= リトライ消費）は難易度依存。テストで難易度別に
  多数シードを生成し、Err が出ない（リトライ予算が足りる）ことと、充填率が
  改善することを実測する。却下率が異常に高ければ 8 ではなく生成ロジックの
  見直しサイン。

- 充填率がそれでも本物（平均72%）に届かない場合、接触辺数最大化だけでは
  不十分なサイン。別 ADR で充填率下限や別メトリクス（外接矩形面積ペナルティ等）
  を検討する。

- 仕様書 § 4.3.4（seed 文字列）と実装（seed int）の不整合（Issue #31）は
  ステージ2の課題として引き続き保留。

## References

- docs/SPECIFICATION.md § 4.3.2 逆算生成法 / § 4.3.3 解の妥当性検証 / § 14.2 Result 型
- ADR-0005: Result 型によるエラーハンドリング
- ADR-0006: ポリオミノ座標の順序 (y, x)
- ADR-0007: Claude セッションのリポジトリ状態取り違え事故の防止
- ADR-0008: 解数検証付きパズル生成層 (VerifiedPuzzleGenerator)
- ADR-0009: 枠の単連結性を保証する層 (PlayablePuzzleGenerator)
- lib/domain/puzzle/puzzle_generator.dart（construct / listPlacementCandidates）
- 本物ウボンゴ台紙9枚の充填率実測（平均約72%、範囲60〜92%）
- 候補A実機観測（PR #47、normal/hard の充填率が多く30%台）
