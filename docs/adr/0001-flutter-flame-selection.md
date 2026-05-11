# ADR-0001: Flutter + Flame をフロントエンド技術スタックとして採用する

## Status

Accepted

## Context

PolyRush はスマホ・タブレット両対応の 2D 図形パズルゲームである。
以下の要件を同時に満たす技術スタックを選定する必要があった。

- Android Phone / Tablet の単一コードベース対応
- ゲームループを通じた **60fps** 描画の安定確保
- ドラッグ・スナップ・回転・反転といった精細なタッチ操作の実装
- Claude Code との親和性が高く、開発者が自然言語指示のみで実装を進められる
- 将来的な iOS / Web（PWA）への展開可能性

詳細な選定基準は [docs/SPECIFICATION.md § 2.1](../SPECIFICATION.md#21-フロントエンドクライアント) を参照。

## Decision

**Flutter 3.x（Dart）** をアプリフレームワークとして採用し、
**Flame Engine 1.x** をゲーム描画エンジンとして組み合わせる。

- Flutter は `LayoutBuilder` + `MediaQuery` によりスマホ / タブレット両レイアウトを単一コードベースで切り替えられる。
- Flame は Flutter 公式が認める 2D ゲームエンジンであり、Canvas 描画ベースで 60fps を出しやすい。コンポーネント設計（FCS）によりブロック・グリッドを構造化しやすく、`HitboxComponent` の拡張でタッチ精度も担保できる。
- Hot Reload により UI の微調整サイクルが極めて速く、Claude Code Web との反復開発に適している。

## Consequences

**ポジティブ：**

- Android / iOS / Web をほぼ同一コードで対応できる（将来拡張コスト低減）
- Dart は型安全で、Claude Code が生成するコードの品質が安定しやすい
- `flutter_test` + `golden_toolkit` による UI テストが充実しており、CI 組み込みが容易
- `flame_audio`・`HapticFeedback` など周辺パッケージが揃っており、SE / 触覚フィードバックを追加コストなく実装できる

**ネガティブ：**

- Flutter / Flame のメジャーバージョンアップによる破壊的変更リスクがある（→ `pubspec.lock` 固定・半年ごとの計画更新で対処）
- Dart の学習コストが発生する（ただし Claude Code Web が実装を代行するため軽微）
- 3D 対応や超高精細な物理演算は苦手（本ゲームの要件には該当しない）

## Alternatives Considered

| 候補 | 採用しなかった理由 |
|---|---|
| Unity (C#) | オーバースペック。APK サイズが大きく、Claude Code での自動補完が冗長になりやすい |
| React Native + Skia | ゲームループで 60fps 維持が不安定。JS ブリッジ層がボトルネックになる |
| Native Kotlin (Jetpack Compose) | 性能は最高だが iOS 展開不可。開発工数が約 2 倍になる |
| PWA (Capacitor) | ドラッグ精度・60fps 保証が困難 |

## References

- [docs/SPECIFICATION.md § 2.1 フロントエンド（クライアント）](../SPECIFICATION.md#21-フロントエンドクライアント)
- [Flutter 公式ドキュメント](https://flutter.dev/docs)
- [Flame Engine 公式ドキュメント](https://docs.flame-engine.org/)
