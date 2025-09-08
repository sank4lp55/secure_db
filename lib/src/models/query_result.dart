/// Result wrapper for database queries
class QueryResult<T> {
  final List<T> data;
  final int count;
  final bool hasMore;
  final String? error;
  final Duration? executionTime;

  const QueryResult({
    required this.data,
    required this.count,
    this.hasMore = false,
    this.error,
    this.executionTime,
  });

  /// Create a successful result
  factory QueryResult.success(
    List<T> data, {
    bool hasMore = false,
    Duration? executionTime,
  }) {
    return QueryResult(
      data: data,
      count: data.length,
      hasMore: hasMore,
      executionTime: executionTime,
    );
  }

  /// Create an error result
  factory QueryResult.error(String error) {
    return QueryResult(
      data: [],
      count: 0,
      error: error,
    );
  }

  /// Check if the result is successful
  bool get isSuccess => error == null;

  /// Check if the result has an error
  bool get hasError => error != null;

  /// Check if the result is empty
  bool get isEmpty => data.isEmpty;

  /// Check if the result is not empty
  bool get isNotEmpty => data.isNotEmpty;

  /// Get the first item or null
  T? get first => data.isNotEmpty ? data.first : null;

  /// Get the last item or null
  T? get last => data.isNotEmpty ? data.last : null;

  /// Transform the data to another type
  QueryResult<R> map<R>(R Function(T item) mapper) {
    if (hasError) {
      return QueryResult.error(error!);
    }

    try {
      final mappedData = data.map(mapper).toList();
      return QueryResult(
        data: mappedData,
        count: mappedData.length,
        hasMore: hasMore,
        executionTime: executionTime,
      );
    } catch (e) {
      return QueryResult.error('Error mapping data: $e');
    }
  }

  /// Filter the data
  QueryResult<T> where(bool Function(T item) predicate) {
    if (hasError) {
      return QueryResult.error(error!);
    }

    try {
      final filteredData = data.where(predicate).toList();
      return QueryResult(
        data: filteredData,
        count: filteredData.length,
        hasMore: hasMore,
        executionTime: executionTime,
      );
    } catch (e) {
      return QueryResult.error('Error filtering data: $e');
    }
  }

  /// Take only the first n items
  QueryResult<T> take(int count) {
    if (hasError) {
      return QueryResult.error(error!);
    }

    final takenData = data.take(count).toList();
    return QueryResult(
      data: takenData,
      count: takenData.length,
      hasMore: data.length > count,
      executionTime: executionTime,
    );
  }

  /// Skip the first n items
  QueryResult<T> skip(int count) {
    if (hasError) {
      return QueryResult.error(error!);
    }

    final skippedData = data.skip(count).toList();
    return QueryResult(
      data: skippedData,
      count: skippedData.length,
      hasMore: hasMore,
      executionTime: executionTime,
    );
  }

  @override
  String toString() {
    if (hasError) {
      return 'QueryResult.error($error)';
    }
    return 'QueryResult(count: $count, hasMore: $hasMore, executionTime: $executionTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryResult<T> &&
        other.data == data &&
        other.count == count &&
        other.hasMore == hasMore &&
        other.error == error &&
        other.executionTime == executionTime;
  }

  @override
  int get hashCode {
    return Object.hash(data, count, hasMore, error, executionTime);
  }
}

/// Paginated result for large datasets
class PaginatedResult<T> extends QueryResult<T> {
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  PaginatedResult({
    required super.data,
    required super.count,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    super.hasMore,
    super.error,
    super.executionTime,
  }) : totalPages = (totalCount / pageSize).ceil();

  /// Create a successful paginated result
  factory PaginatedResult.success(
    List<T> data, {
    required int page,
    required int pageSize,
    required int totalCount,
    Duration? executionTime,
  }) {
    final totalPages = (totalCount / pageSize).ceil();
    final hasMore = page < totalPages;

    return PaginatedResult(
      data: data,
      count: data.length,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      hasMore: hasMore,
      executionTime: executionTime,
    );
  }

  /// Create an error paginated result
  factory PaginatedResult.error(String error) {
    return PaginatedResult(
      data: [],
      count: 0,
      page: 0,
      pageSize: 0,
      totalCount: 0,
      error: error,
    );
  }

  /// Check if there's a next page
  bool get hasNextPage => page < totalPages;

  /// Check if there's a previous page
  bool get hasPreviousPage => page > 1;

  /// Get the next page number
  int? get nextPage => hasNextPage ? page + 1 : null;

  /// Get the previous page number
  int? get previousPage => hasPreviousPage ? page - 1 : null;

  @override
  String toString() {
    if (hasError) {
      return 'PaginatedResult.error($error)';
    }
    return 'PaginatedResult(page: $page/$totalPages, count: $count/$totalCount, executionTime: $executionTime)';
  }
}
