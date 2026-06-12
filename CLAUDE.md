# CLAUDE.md - polyrush プロジェクト作業ガイド

このファイルは Claude (Code Web / Opus / その他のセッション) が
polyrush リポジトリで作業する際に必ず守るべきルールを定義する。

すべてのタスクは、このファイルを読んでから開始すること。

---

## 🚨 最重要: 作業開始時の環境チェック

**いかなるタスクも、以下のチェックを完了してから着手すること。**
このステップを省略するとリポジトリの状態を取り違え、既存の成果を
上書きしたり、孤立ブランチを作成する事故につながる。

```bash
# 1. リモートの最新を取得
git fetch origin

# 2. 開発ベースブランチに移動
git checkout develop

# 3. リモートと同期
git pull origin develop

# 4. 現在の状態を確認
git log --oneline -5
git branch -a
ls lib/domain/puzzle/
```

### 期待される結果
- 現在ブランチ: `develop`
- 直近コミットに過去のマージ履歴が見える
- `lib/domain/puzzle/` 配下に既存の Task 成果ファイルが存在

### 結果が期待と異なる場合
- 作業を停止する
- ユーザーに状況を報告する
- **絶対に「ファイルが無いから作り直そう」と判断しない**

---

## 🌳 ブランチ運用

- ベースブランチ: `develop`(`main` ではない)
- 機能ブランチ命名: `feature/<task-name>`(例: `feature/puzzle-generator`)
- ドキュメントのみの変更: `docs/<task-name>`
- すべての PR は `develop` を base に作成
- 直接 `develop` や `main` にコミットしない
- 自動命名ブランチ(`claude/xxx-XXXXX`)は禁止 → 下記「自動命名ブランチの禁止」を厳守

### 🚫 自動命名ブランチの禁止(Code Web 向け・厳守)

Code Web は放置すると `claude/implement-xxx-XXXXX` のような自動命名ブランチを
作る癖があるが、本プロジェクトでは禁止である。ブランチは必ず指示文で与えられた
名前で、develop から手動で切ること:

- 手順: `git checkout develop` → `git pull origin develop` → `git checkout -b <指示された名前>`
- 命名: `feature/xxx`(機能) または `docs/xxx`(ドキュメントのみ)
- `git checkout -b` を自分の判断で勝手な名前(特に `claude/...`)で実行しない
- 指示文にブランチ名の指定が無いときは、推測で作らずユーザーに名前を確認する

#### 例外: システム割当ブランチ(2026-06-11 改定)

Code Web のセッションがシステムによって claude/xxx ブランチを
強制割当し、手動命名が不可能な場合に限り、そのブランチでの作業を
例外として許容する。ただし以下を必ず守ること:

- 作業前に、ブランチが develop の最新コミットを含むことを確認する
  (含まない場合は git merge develop で取り込む)
- PR は必ず develop を base に作成する(main は禁止)
- 完了報告に「システム割当ブランチを使用した」旨を明記する

この例外はブランチ名のみに適用される。develop 以外を base にした
PR 作成や、環境チェックの省略は引き続き禁止である。

---

## 📂 既存ファイル変更ポリシー

過去のタスクで develop にマージ済みのファイルは「確定済み資産」である。
新規タスクで以下のファイルを変更してはいけない:

- `lib/domain/puzzle/polyomino.dart` (Task 1)
- `lib/domain/puzzle/polyomino_transformer.dart` (Task 2)
- `lib/domain/puzzle/puzzle_generator.dart` (Task 3)
- `lib/domain/puzzle/difficulty.dart` (Task 3)
- `lib/domain/puzzle/solver.dart` (Task 4)
- `lib/domain/puzzle/verified_puzzle_generator.dart` (Task 5)
- `lib/domain/puzzle/frame_connectivity.dart` (ADR-0009 / PR #45)
- `lib/domain/puzzle/playable_puzzle_generator.dart` (ADR-0009 / PR #45)
- `lib/domain/puzzle/compact_puzzle_generator.dart` (ADR-0010 / PR #50)
- `lib/domain/puzzle/compact_puzzle_generator_v2.dart`（ADR-0012 / PR #54）— 現在の本番経路。改造禁止。改良は新層を足す。
- `lib/domain/puzzle/compact_puzzle_generator_v3.dart`（ADR-0013 / PR #56）— 現在の本番経路。改造禁止。改良は新層を足す。
- `lib/game/board/grid_geometry.dart` (PR #37)
- `lib/core/result.dart` (Task 5)
- `docs/adr/*.md` (合意済みの設計判断)
- `pubspec.yaml` (依存変更は別途相談)
- `lib/game/play/placement_logic.dart` (Phase 2 / 配置ロジック本体。改造禁止。改良は新層を足す)
- `lib/game/play/confetti_physics.dart` (Phase 2 / 紙吹雪パラメータ実機確定値: 80個・1.4秒・上40%。改造禁止)
- `lib/ui/screens/play/tray_layout.dart` (Phase 2 / トレイ左詰めA方式の確定ロジック。改造禁止)

※ board_painter.dart / board_preview_screen.dart は候補A（本番プレビュー差し替え）で編集中のため意図的に未追加。候補A完了後に board_painter.dart を追加する。

これらの API を変更する必要が生じた場合:
1. 作業を停止
2. ユーザーに「変更が必要な理由」を報告
3. ユーザーの判断を待つ(独断で変更しない)

---

## 🎯 座標系規約 (ADR-0006)

ポリオミノ・グリッドの座標は **`(y, x) = (row, col)`** の順で統一。

- 第1要素: `y` (行、上から下に増加)
- 第2要素: `x` (列、左から右に増加)

詳細: `docs/adr/0006-polyomino-coordinate-order.md`

---

## 🧪 テスト規約

- 既存テストファイルのスタイル (group ネスト、`reason=` 付き expect) に揃える
- ストレステスト等の重いテストは `@Tags(['slow'])` で別レーン
- カバレッジ 100% を目標
- `dart analyze` でエラー・警告ゼロ
- `dart format` 適用済み

---

## 🤝 マルチ AI 運用について

このプロジェクトでは以下の役割分担で開発する:

- **Claude Opus** (claude.ai): 設計、レビュー、判断
- **Claude Code Web**: 実装、テスト
- **人間 (井川)**: 最終判断、マージ、運営、AI 間の情報受け渡し

Code Web は実装に集中し、設計判断はユーザー経由で Opus に委ねる。
不明点は推測せず、ユーザーに質問すること。

### Opus への依頼出力ルール（重要・恒久）

このルールは Opus（claude.ai のレビュー・設計担当）に向けたもの。
過去の運用で判明した非効率・事故を防ぐため、以下を恒久ルールとする。

1. **完成形を直接出す**
   Opus が Code Web 向けの指示文・コード・ファイル内容を出すときは、
   「後で完全版を出しましょうか？」等の確認や前置きを挟まず、
   最初から「Code Web にそのまま貼れる完成形」を直接出すこと。
   井川（初心者）の往復負担を最小化することを最優先する。

2. **ブランチ名を必ず検証する**
   Code Web は放置すると claude/xxx-XXXXX 形式の自動命名ブランチを
   作る癖があり、これは本 CLAUDE.md のブランチ規約違反である。
   - Opus は指示文に必ず正しいブランチ名（feature/xxx, docs/xxx 等）を
     明示する。
   - Code Web の完了報告を受けたら、Opus はブランチ名が規約通りかを
     必ず確認する。違反していたら、マージ前に正しいブランチで
     作り直すよう指示する。

3. **GitHub 画面でできる軽作業の進め方は「井川が選ぶ」**
   - ファイル1個の追加・1行修正のような小さな編集について、Opus は「Code Web に任せる方法」と「井川が GitHub 画面で直接やる方法（クリック単位の番号付き手順つき・飛び先 URL 付き）」の両方を示し、どちらを採るかは井川が決める。
   - 既定は井川の安心を最優先する。少しでも不安なら Code Web に任せてよく、Opus は直接ルートを押し付けない。
   - 往復削減は副次的な目的にすぎず、最優先は「井川が間違えず・不安なく進められる」こと。
   - PR のマージ、CI 結果の確認など、もともと人間（井川）にしかできない作業は従来どおり井川が行う。

4. **正本と写しの同期**
   本 CLAUDE.md や ADR・仕様書を更新したら、リポジトリの正本を先に
   更新し、その後プロジェクトナレッジ（claude.ai 側）の写しにも
   同じ内容を反映する。正本だけ／写しだけの更新は食い違いを生むため
   禁止。「正本を直す → 写しを同期する」の順を守る。

5. **タスクは「誰が実際に動かすか」を明示して設計する**
   Code Web 環境には Dart / Flutter が無く、コードを実行できない。
   実行・テスト・整形・数値計測を担うのは CI（GitHub Actions）である。
   - したがって Opus は、「成果物が実行されて初めて価値を持つ」種類の
     タスク（数値計測・ベンチマーク・統計集計など）を、必ず CI が
     走らせる形（テスト等）で設計すること。
   - Code Web に `dart run` / `flutter run` 等のローカル実行をさせる
     前提の指示を出さない。実行結果が必要な場合は、それを検証する
     テストとして書かせ、CI の合否・ログで確認する流れにする。
   - これは Opus 自身の設計時の責務であり、Code Web 側の制約
     （「Code Web の環境制約」セクション）と対になるものである。

### Code Web の環境制約 (既知)

- Code Web は GitHub Actions の CI ログにアクセスできない
  (git プロキシは git 通信専用、gh CLI 未インストール、WebFetch は要ログイン)。
  CI 結果の確認はユーザーが GitHub Web UI から行う。
- Code Web のセッションは状態を持たない。タスク開始時に必ず
  冒頭の「作業開始時の環境チェック」を実行すること。
- Code Web はセッション開始時に Flutter SDK が自動セットアップされ、
  flutter コマンド（flutter analyze / flutter test 等）をセッション内で
  実行できる（ADR-0007 関連 / PR #73 で導入）。したがって実装タスクには
  flutter test の実行と、その結果（件数・pass/fail・所要時間）の報告を
  含めてよい。ただし CI ログ自体は依然 Code Web から見えないため、
  最終的な合否確認はユーザーが GitHub Web UI で行う点は変わらない。

### Opus への受け渡し形式 (Code Web 向け)

Opus はリポジトリに直接アクセスできず、ユーザーが手動でコピペして運ぶ。
そのため Code Web は、Opus に渡る前提の出力を以下の形式で提出すること:

- レビュー対象のコード・ログは、コピペしやすい単一の塊で出力する
  (前置きの説明や装飾を最小化。ただし**中身は省略しない**
  ──「短くする」と「中身を削る」は別。レビューに必要な全文は必ず出す)
- 長くなる場合は「(1/N)」「(2/N)」と明記して分割出力する
- 分割位置は意味の切れ目 (ファイル境界、グループ境界) にする
- ファイルごとに `## ファイル名` の見出しを付ける
- 井川がコピペして運ぶ Code Web の出力（調査結果・レビュー対象・PR 説明文など）は次を厳守する:
  - 回答全体を 1つのコードブロックにまとめる（コピペが1回で済むように）。
  - その中で入れ子のコードフェンス（バッククォート3個）を使わない。ファイルの中身は ===== ファイル名 ===== のような区切り線で示す。
  - PR 説明文などにシェルの heredoc 囲い文字（$(cat <<'EOF' ... EOF) など）を入れない。
  - Opus はこれらを、Code Web へ渡す指示文の中にも毎回明記する。

### Opus の責務: 運用改善の提案

Opus は、Code Web との連携や現在の運用の中で、より簡単・効率的・
API 消費を抑えられる方法に気づいた場合、必ずユーザーに提案すること。例:

- 会話が長くなりすぎた場合の新規チャット / プロジェクトへの移行提案
- 手作業の往復を減らす仕組み化の提案
- CI 結果をファイル出力させて Code Web が読めるようにする等の改善

---

## 📋 タスク完了時の報告フォーマット

タスク完了時は以下を必ず含めて報告すること:

1. **環境チェックの結果**(`git log` `ls` の出力を貼る)
2. **作成ファイル一覧**(「新規」「変更」を明示)
3. **削除/変更した既存ファイル**(あれば理由とともに)
4. **テスト結果**(件数、pass/fail、所要時間)
5. **指示書からの逸脱があれば明記**
6. **PR URL**(まだなら理由を説明)

### handoff ファイルの更新(ADR-0016・必須)

タスク完了時、上記 1〜6 の報告に「次セッションへの申し送り」を加えた
内容で docs/handoff/LATEST.md を上書きし、同じ PR に含めること。
新しいファイルは作らず、常に LATEST.md の 1 ファイルを上書きする
(過去分は git 履歴で参照できる)。コードの全文は書かない。
また、新タスク開始時は環境チェックの後に docs/handoff/LATEST.md を
読み、直近の文脈を把握してから着手すること。

---

## 📚 関連ドキュメント

- 仕様書: `docs/SPECIFICATION.md`
- ADR 一覧: `docs/adr/`
- 開発ステップ: `docs/SPECIFICATION.md` § 19
- 本ガイドの根拠: `docs/adr/0007-claude-session-guardrails.md`
