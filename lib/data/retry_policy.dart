import 'dart:async';

import 'package:http/http.dart' as http;

class CircuitBreakerOpenException implements Exception {
  const CircuitBreakerOpenException({required this.retryAfter});

  final Duration retryAfter;

  @override
  String toString() {
    return 'Circuit breaker open; retry after ${retryAfter.inMilliseconds}ms.';
  }
}

class RetryExhaustedException implements Exception {
  const RetryExhaustedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 3),
    this.backoffMultiplier = 2,
    this.failureThreshold = 5,
    this.circuitOpenFor = const Duration(seconds: 20),
    this.requestTimeout = const Duration(seconds: 10),
  });

  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final int failureThreshold;
  final Duration circuitOpenFor;
  final Duration requestTimeout;

  Duration backoffForAttempt(int attempt) {
    final scaledMilliseconds =
        initialDelay.inMilliseconds *
        _pow(backoffMultiplier, attempt - 1).toInt();
    final cappedMilliseconds = scaledMilliseconds.clamp(
      initialDelay.inMilliseconds,
      maxDelay.inMilliseconds,
    );
    return Duration(milliseconds: cappedMilliseconds);
  }

  bool isRetryableResponse(http.Response response) {
    return response.statusCode == 429 || response.statusCode >= 500;
  }

  bool isRetryableError(Object error) {
    return error is TimeoutException || error is http.ClientException;
  }
}

class RetryHttpClient {
  RetryHttpClient({
    required http.Client client,
    this.policy = const RetryPolicy(),
  }) : _client = client;

  final http.Client _client;
  final RetryPolicy policy;

  int _consecutiveFailures = 0;
  DateTime? _openedAt;
  bool _halfOpenProbeInFlight = false;

  Future<http.Response> execute(
    Future<http.Response> Function(http.Client client) request, {
    required bool isIdempotent,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= policy.maxAttempts; attempt++) {
      _guardCircuit();

      try {
        final response = await request(_client).timeout(policy.requestTimeout);
        if (!policy.isRetryableResponse(response)) {
          _recordSuccess();
          return response;
        }

        if (!isIdempotent || attempt == policy.maxAttempts) {
          _recordFailure();
          throw RetryExhaustedException(
            'Retry limit reached. Last status: ${response.statusCode}.',
          );
        }

        _recordFailure();
      } catch (error) {
        lastError = error;
        if (error is CircuitBreakerOpenException) {
          rethrow;
        }

        if (!isIdempotent ||
            !policy.isRetryableError(error) ||
            attempt == policy.maxAttempts) {
          _recordFailure();
          rethrow;
        }

        _recordFailure();
      }

      await Future<void>.delayed(policy.backoffForAttempt(attempt));
    }

    throw RetryExhaustedException(
      'Retry limit reached with no successful response. Last error: $lastError',
    );
  }

  void close() {
    _client.close();
  }

  void _guardCircuit() {
    final openedAt = _openedAt;
    if (openedAt == null) {
      return;
    }

    final elapsed = DateTime.now().difference(openedAt);
    if (elapsed < policy.circuitOpenFor) {
      throw CircuitBreakerOpenException(
        retryAfter: policy.circuitOpenFor - elapsed,
      );
    }

    if (_halfOpenProbeInFlight) {
      throw const CircuitBreakerOpenException(
        retryAfter: Duration(milliseconds: 500),
      );
    }

    _halfOpenProbeInFlight = true;
  }

  void _recordSuccess() {
    _consecutiveFailures = 0;
    _openedAt = null;
    _halfOpenProbeInFlight = false;
  }

  void _recordFailure() {
    if (_halfOpenProbeInFlight) {
      _halfOpenProbeInFlight = false;
      _openedAt = DateTime.now();
      _consecutiveFailures = policy.failureThreshold;
      return;
    }

    _consecutiveFailures += 1;
    if (_consecutiveFailures >= policy.failureThreshold) {
      _openedAt = DateTime.now();
    }
  }
}

double _pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
