# ADR-0009: 枠の単連結性を保証する層 (PlayablePuzzleGenerator) の導入

## Status

Proposed (2026-06-04)

## Context

### 解決したい問題

逆算生成法（仕様書 § 4.3.2）は「配置したブロック群の和集合」を枠とする。
ブロックは辺隣接で配置されるため枠は必ず連結になるが、生成器は
「内部に閉じ込められた空きマス（穴）」の有無を一切検査していない
（仕様書 § 4.3 の盲点）。

Phase 2 の board_preview_screen による 9 枚ギャラリー目視確認で、
中央に穴の空いた枠が生成されることが判明した（例: hard/seed=1 系統）。
本物のウボンゴの枠は全画像確認の結果「穴なし」であり、L字・凸・ギザギザ
といったデコボコは許容されるが、内部に囲まれた空間は許容されない。

正式な条件は「枠が 単連結（全マスが 4-連結で繋がり、かつ内部に
囲まれた穴が無い）であること」とする。

当初案「外周の辺の数を最小化する」は、突き詰めると枠が長方形へ寄り、
ウボンゴらしいデコボコが消えるため不採用とした。条件は「単連結」が正しい。

### 現状の部品（いずれも CLAUDE.md により変更禁止）

- PuzzleGenerator.construct(): 枠を 1 個生成。品質判定はしない。
- PuzzleSolver.countSolutions(): 解数を limit で頭打ちして数える。判定しない。
- VerifiedPuzzleGenerator.generate({difficulty, seed})
    → Result<VerifiedPuzzle, GenerationError>:
  construct を内部で呼び、解数 1〜3 を採用する検証層（ADR-0008）。
  サブシード派生・最大 8 回の検証リトライ・フォールバックを持つ。

### 制約

- puzzle_generator.dart / solver.dart / verified_puzzle_generator.dart /
  difficulty.dart / result.dart は変更禁止（CLAUDE.md）。
- GenerationError enum は変更禁止ファイル内に定義されているため、
  値を追加できない。
- 座標系は (y, x) = (row, col)（ADR-0006）。cell.$1 = y(行), cell.$2 = x(列)。
- ドメイン層のエラー伝達は Result<T, E> を用いる（仕様書 § 14.2, ADR-0005）。

### 前例

ADR-0008 は construct の外側に解数検証層を「被せる」ことで確定資産を
守った。本 ADR はその思想を踏襲し、枠形状の検証層をさらに外側に被せる。

## Decision

新ファイル 2 つを追加する。既存ファイルは一切変更しない。

- lib/domain/puzzle/frame_connectivity.dart : 単連結性の判定（純粋関数）
- lib/domain/puzzle/playable_puzzle_generator.dart : 検証＋再生成の層

以下、7 つの設計判断を確定する。

### 判断 1: 新規層として実装し、既存ファイルを変更しない（B案）

construct も VerifiedPuzzleGenerator も改造せず、その外側に層を足す。
新層は VerifiedPuzzleGenerator.generate を「呼ぶだけ」で成立し、
CLAUDE.md / ADR-0007 のガードレールと衝突しない。
「生成」「解数判定」「枠形状判定」という別々の関心事を別部品に分離する。

### 判断 2: 「単連結」の定義と判定アルゴリズム

単連結 = (a) 枠の全セルが 4-連結（上下左右隣接）で繋がっている、かつ
(b) 内部に外へ通じない空きマス（穴）が無い、の両方を満たすこと。

判定 isFrameSimplyConnected(frame):
- (a) 任意の 1 セルから 4-近傍 BFS し、到達数 = 全セル数 なら連結。
- (b) 枠の外接矩形を上下左右 1 マスずつ広げた領域の角（必ず空き）から
  空きマスを 4-連結で塗りつぶす（Flood Fill）。外接矩形内にある空きマスの
  うち塗りつぶしで到達できなかったマスが 1 つでもあれば「囲まれた穴」。

### 判断 3: 空きマスの塗りつぶしは 4-連結とする

ブロックは辺隣接でしか配置されないため、対角の隙間からピースは通れない。
よって対角ピンチで挟まれた空きマスも「実質的な穴」として弾くべきであり、
空き空間の塗りつぶしは 4-連結で行う。8-連結に変更してはならない。
（将来の読み手が「8 にすべきでは」と誤って変更しないよう明記する。）

### 判断 4: 新層は VerifiedPuzzleGenerator を包む（construct を直接呼ばない）

ADR-0008 判断 6「ゲーム本体はパズル取得に必ず VerifiedPuzzleGenerator を
経由する」を維持・拡張し、ゲーム本体は以後 PlayablePuzzleGenerator を
経由する規約とする。これにより解数検証と枠形状検証が両方保証される。

### 判断 5: 穴あき枠はサブシードを変えて再生成。上限 8 回

VerifiedPuzzleGenerator.generate(seed) は決定論的なので、同じ seed の
再呼び出しは同じ穴あき枠を返す。これを避け、(seed, attempt) から
決定論的にサブシードを派生させて呼び直す。

- 派生は ADR-0008 § サブシード派生と同系の 32bit LCG（Numerical Recipes の
  乗数 1664525・加数 1013904223、法 2^32）で行う。hashCode は使わない。
- VerifiedPuzzleGenerator 内の _deriveSubSeed は private で再利用できないため、
  新ファイルに同種の小関数を持つ。確定資産を公開化のためだけに触らない判断。
  この軽微な重複は許容し、dartdoc で ADR-0008 を参照する。
- 検証リトライ上限は名前付き定数 maxFrameRetries = 8。

### 判断 6: フォールバックしない（ADR-0008 との意図的な相違）

ADR-0008 は解 4 以上しか作れなかった場合「最善のもの」を返すフォールバックを
持つ。本層は持たない。穴あき枠は「やや劣る成功」ではなく「視覚的に壊れた問題」
であり、ユーザーに提示すべきでない。

- 8 回すべてで穴あきだった → Err(noSimplyConnectedFrame)
- 8 回すべてで下層が失敗した → Err(generationFailed)

8 回独立に再ロールして全て穴あきは通常まず起きない。起きた場合は生成器・
難易度設定の系統的異常のサインであり、Err として表に出すのが正しい。
呼び出し側（将来の Phase 2）は Err を必ず分岐処理し、握りつぶさないこと。

### 判断 7: エラー型は新規 enum、戻り値の成功型は VerifiedPuzzle を流用

GenerationError は変更禁止ファイル内のため値を追加できない。新ファイルに
PlayablePuzzleError { generationFailed, noSimplyConnectedFrame } を定義する。
成功型は新設せず VerifiedPuzzle を流用する（型の表面を最小化）。
公開メソッドは Result<VerifiedPuzzle, PlayablePuzzleError> を返す。
「単連結が保証されている」ことは PlayablePuzzleGenerator 経由で得たという
出所により担保する。

## Consequences

### ポジティブ

- ウボンゴらしい「穴なしデコボコ枠」が初めて保証される。hard/seed=1 系統の
  既知問題が解消される。
- 確定資産に一切触れないため ADR-0007 が問題視した破壊リスクがゼロ。
- isFrameSimplyConnected は純粋関数で再利用・単体テストが容易。

### ネガティブ

- リトライ層が 3 段になる（下表）。説明的な定数名で区別する。

  | リトライ | 場所 | 数える対象 |
  |---|---|---|
  | 配置リトライ（10回） | puzzle_generator.dart | 1 個の枠を組む途中の詰まり直し |
  | 解数検証リトライ（8回） | verified_puzzle_generator.dart | 簡単すぎる問題の没回数 |
  | 枠形状リトライ（8回・新規） | playable_puzzle_generator.dart | 穴あき枠の没回数 |

- 穴検査が解数検証「より後」に走るため、穴あき枠で消費した解数検証が無駄に
  なりうる。VerifiedPuzzleGenerator を変更できない以上、検査順は再編できない。
  穴は少数派であり影響は軽微。
- サブシード派生の小重複（判断 5）。dartdoc で出自を明記して許容する。

### 中立・申し送り

- 穴の発生率（却下率）は難易度依存。テストで難易度別に多数シードを生成し、
  穴ゼロと「Err が出ない（リトライ予算が足りる）」ことを実測する。却下率が
  異常に高ければ 8 ではなく生成器・難易度設定の見直しサインとして井川へ報告。
- 単連結・解 1〜3 でも配置が規則的すぎて閃きの余地が乏しい枠（「風車」状の
  自明配置など）が出うる。これは穴とは別軸（非自明性）の課題であり、本 ADR の
  対象外。ADR-0009 マージ後に実機で発生頻度を観測し、目立つようなら別 ADR
  （非自明性フィルタ、探索量メトリクス等）として B 案思想で設計する。
- 仕様書 § 4.3.4（seed 文字列）と実装（seed int）の不整合（Issue #31）は
  ステージ2 の課題として引き続き保留。

## References

- docs/SPECIFICATION.md § 4.3.2 逆算生成法 / § 4.3.3 解の妥当性検証 / § 14.2 Result 型
- ADR-0005: Result 型によるエラーハンドリング
- ADR-0006: ポリオミノ座標の順序 (y, x)
- ADR-0007: Claude セッションのリポジトリ状態取り違え事故の防止
- ADR-0008: 解数検証付きパズル生成層 (VerifiedPuzzleGenerator)
- lib/domain/puzzle/verified_puzzle_generator.dart（Task 5 / PR #23）
