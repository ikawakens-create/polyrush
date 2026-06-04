/// [Result] 型 — 仕様書 § 14.2 準拠のエラーハンドリング基盤。
///
/// ドメイン層・データ層では例外を投げる代わりに [Result] を返す。
/// sealed class であるため、呼び出し側の switch 文によって [Ok] と [Err] の
/// 両方を必ず処理することをコンパイラレベルで強制し、例外の取りこぼしを防ぐ。
///
/// ## 使い方
/// ```dart
/// Result<int, String> safeDivide(int a, int b) {
///   if (b == 0) return const Err('division by zero');
///   return Ok(a ~/ b);
/// }
///
/// final result = safeDivide(10, 2);
/// switch (result) {
///   case Ok(:final value): print('Result: $value');
///   case Err(:final error): print('Error: $error');
/// }
/// ```
library;

/// 処理の成功または失敗を型安全に表す sealed class（仕様書 § 14.2）。
sealed class Result<T, E> {
  const Result();
}

/// 成功を表す [Result] のサブクラス。[value] に成功値を保持する。
class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);

  /// 成功値。
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, E> && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'Ok($value)';
}

/// 失敗を表す [Result] のサブクラス。[error] にエラー値を保持する。
class Err<T, E> extends Result<T, E> {
  const Err(this.error);

  /// エラー値。
  final E error;

  @override
  bool operator ==(Object other) =>
      other is Err<T, E> && other.error == error;

  @override
  int get hashCode => Object.hash(runtimeType, error);

  @override
  String toString() => 'Err($error)';
}
