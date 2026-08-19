typedef Json = Map<String, dynamic>;
String urlCiudadania = 'https://efe.dev.mp.gob.bo/login';

class ValueTipo<T> {
  ValueTipo({required this.id, this.value});
  final int id;
  final T? value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ValueTipo<T> && other.id == id && other.value == value;
  }

  @override
  int get hashCode => Object.hash(id, value);
}
