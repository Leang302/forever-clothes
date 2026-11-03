import '../entities/saved_address.dart';

abstract interface class AddressRepository {
  Future<List<SavedAddress>> list();

  Future<SavedAddress> add({
    required String label,
    required String firstName,
    required String lastName,
    required String email,
    required String street,
    required String city,
    required String state,
    required String zipcode,
    required String country,
    required String phone,
  });

  Future<void> remove(int addressId);
}
