# ADR-0006: ポリオミノ座標の順序を (y, x) = (row, col) に統一する

## Status

Accepted (2026-05-20)

## Context

`lib/domain/puzzle/polyomino.dart` にて、ポリオミノの各セルを表す型として
Dart 3 の Record 型 `(int, int)` を採用した。

この型は「第1要素・第2要素」の順序を明示的に定義する必要があり、
慣例として以下の2つの選択肢が存在する。

| 順序 | 記法 | 用途での慣例 |
|---|---|---|
| `(x, y)` | `(col, row)` | 数学・画像座標（左→右が正 x） |
| `(y, x)` | `(row, col)` | 行列アクセス・グリッド処理 |

仕様書 `docs/SPECIFICATION.md` § 4.3.3 の擬似コード（`CountSolutions`）は
「最も左上のマス (x, y) を探す」と記述しており、`(x, y)` 順を示唆している。

一方 domain 層では、グリッドを `List<List<T>>` として扱う場合の慣例的アクセス
（`grid[row][col]`）と一致させることが開発ミスを減らす上で重要である。

また、後続タスクである `PuzzleGenerator`（§ 4.3.2）の擬似コードでも
行・列単位でのグリッド走査が中心となることが予想される。

## Decision

**domain 層では `Cell = (y, x) = (row, col)` の順に統一する。**

- 第1要素 = `y` = 行番号（row）。0 が最上行、増加方向は下。
- 第2要素 = `x` = 列番号（col）。0 が最左列、増加方向は右。

仕様書 § 4.3.3 の擬似コードは `(x, y)` 順で記述されているが、
これは設計意図の記述であり、実装上の座標順とは分離して扱う。
実装コードと仕様書の対応は `polyomino.dart` および `generator.dart` の
dartdoc コメントで明記し、読み替えが必要な箇所を明示する。

## Consequences

**ポジティブ：**

- `List<List<T>>` グリッドへのアクセス（`grid[y][x]`）と座標が直接対応し、
  インデックスの混乱によるバグを減らせる。
- row-major（行優先）の走査ループが自然に書ける。
  例: `for (int y = 0; y < height; y++) { for (int x = 0; x < width; x++) { ... } }`
- テストコードでの「上から左から」の可読性が高い。

**ネガティブ：**

- 仕様書の擬似コード（`(x, y)` 順）と実装の座標順が逆になるため、
  擬似コードを参照しながら実装する際に読み替えが必要になる。
  → 対処：`polyomino.dart` のライブラリ dartdoc に「座標系は (y, x) = (row, col)」と
  明記し、ADR へのリンクを添える。

**シリアライズ境界での扱い：**
仕様書 § 4.2.3 の操作ログフォーマットは `{"x": 3, "y": 2}` 形式で
定義されている。内部表現の `(y, x)` Record と外部表現の JSON キーの
対応は、データ層（`lib/data/models/`）でのシリアライズ時に集中的に
変換する。domain 層は常に `(y, x)` 順で動作し、外部表現の存在を
意識しなくてよい設計とする。

## References

- [docs/SPECIFICATION.md § 4.3.3 バックトラッキングによる「解の妥当性」検証](../SPECIFICATION.md#433-ステップ3バックトラッキングによる解の妥当性検証)
- [docs/SPECIFICATION.md § 4.2.3 Append-only 操作ログ](../SPECIFICATION.md#423-append-only-操作ログnalla-pass方式の応用)
- [lib/domain/puzzle/polyomino.dart](../../lib/domain/puzzle/polyomino.dart)
