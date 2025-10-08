/// Result of models fetch operation
class ModelsResult {
  /// List of model data maps
  final List<Map<String, dynamic>> models;

  /// Whether the models list is from fallback (not from API)
  final bool isFallback;

  /// Optional error message explaining why fallback was used
  final String? fallbackReason;

  ModelsResult({
    required this.models,
    required this.isFallback,
    this.fallbackReason,
  });

  /// Create a successful API fetch result
  factory ModelsResult.fromApi(List<Map<String, dynamic>> models) {
    return ModelsResult(
      models: models,
      isFallback: false,
    );
  }

  /// Create a fallback result with error reason
  factory ModelsResult.fallback(
    List<Map<String, dynamic>> fallbackModels,
    String reason,
  ) {
    return ModelsResult(
      models: fallbackModels,
      isFallback: true,
      fallbackReason: reason,
    );
  }
}
