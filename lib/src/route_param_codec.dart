abstract class RouteParamCodec<T> {
  const RouteParamCodec();

  String encode(T value);

  T decode(String value);
}

String? encodeQueryParamValueOrNull<T>(RouteParamCodec<T> codec, T value) {
  if (value == null) {
    return null;
  }
  return (codec as dynamic).encode(value) as String;
}

T? decodeQueryParamValueOrNull<T>(RouteParamCodec<T> codec, String? value) {
  if (value == null) {
    return null;
  }
  return codec.decode(value);
}

class StringRouteParamCodec extends RouteParamCodec<String> {
  const StringRouteParamCodec();

  @override
  String encode(String value) => value;

  @override
  String decode(String value) => value;
}

class IntRouteParamCodec extends RouteParamCodec<int> {
  const IntRouteParamCodec();

  @override
  String encode(int value) => value.toString();

  @override
  int decode(String value) => int.parse(value);
}

class DoubleRouteParamCodec extends RouteParamCodec<double> {
  const DoubleRouteParamCodec();

  @override
  String encode(double value) => value.toString();

  @override
  double decode(String value) => double.parse(value);
}

class BoolRouteParamCodec extends RouteParamCodec<bool> {
  const BoolRouteParamCodec();

  @override
  String encode(bool value) => value.toString();

  @override
  bool decode(String value) {
    switch (value) {
      case 'true':
        return true;
      case 'false':
        return false;
      default:
        throw FormatException('Invalid bool route parameter value: $value');
    }
  }
}

class DateTimeIsoRouteParamCodec extends RouteParamCodec<DateTime> {
  const DateTimeIsoRouteParamCodec();

  @override
  String encode(DateTime value) => value.toIso8601String();

  @override
  DateTime decode(String value) => DateTime.parse(value);
}

class UriRouteParamCodec extends RouteParamCodec<Uri> {
  const UriRouteParamCodec();

  @override
  String encode(Uri value) => value.toString();

  @override
  Uri decode(String value) => Uri.parse(value);
}

class EnumRouteParamCodec<T extends Enum> extends RouteParamCodec<T> {
  final List<T> values;

  const EnumRouteParamCodec(this.values);

  @override
  String encode(T value) => value.name;

  @override
  T decode(String value) {
    return values.firstWhere(
      (candidate) => candidate.name == value,
      orElse: () {
        throw FormatException('Invalid enum route parameter value: $value');
      },
    );
  }
}
