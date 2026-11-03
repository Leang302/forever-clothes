import '../../domain/entities/saved_address.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/address_remote_data_source.dart';
import '../models/address_dto.dart';

class AddressRepositoryImpl implements AddressRepository {
  AddressRepositoryImpl(this._remote);

  final AddressRemoteDataSource _remote;

  @override
  Future<List<SavedAddress>> list() async =>
      (await _remote.list()).map((e) => e.toEntity()).toList();

  @override
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
  }) async => (await _remote.add(
    label: label,
    firstName: firstName,
    lastName: lastName,
    email: email,
    street: street,
    city: city,
    state: state,
    zipcode: zipcode,
    country: country,
    phone: phone,
  )).toEntity();

  @override
  Future<void> remove(int addressId) => _remote.remove(addressId);
}
