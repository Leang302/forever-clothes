import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/address_remote_data_source.dart';
import '../../data/repositories/address_repository_impl.dart';
import '../../domain/entities/saved_address.dart';
import '../../domain/repositories/address_repository.dart';

part 'address_providers.g.dart';

@Riverpod(keepAlive: true)
AddressRepository addressRepository(Ref ref) =>
    AddressRepositoryImpl(AddressRemoteDataSource(ref.watch(dioProvider)));

/// The signed-in user's saved addresses. Empty while logged out; reloads when the user changes.
@Riverpod(keepAlive: true)
class AddressesController extends _$AddressesController {
  @override
  Future<List<SavedAddress>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return ref.watch(addressRepositoryProvider).list();
  }

  AddressRepository get _repo => ref.read(addressRepositoryProvider);

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
  }) async {
    final saved = await _repo.add(
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
    );
    this.state = AsyncData([saved, ...this.state.value ?? const []]);
    return saved;
  }

  Future<void> remove(int addressId) async {
    await _repo.remove(addressId);
    state = AsyncData(
      (state.value ?? const []).where((a) => a.id != addressId).toList(),
    );
  }
}
