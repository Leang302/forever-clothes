/// API numbers arrive as `int` or `double`; models always want `double`.
double doubleFromJson(Object? value) => (value as num).toDouble();
