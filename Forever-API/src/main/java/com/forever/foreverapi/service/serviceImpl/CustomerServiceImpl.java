package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.mapper.ProductMapper;
import com.forever.foreverapi.model.dto.CustomerDtos.AddressRequest;
import com.forever.foreverapi.model.dto.CustomerDtos.AddressResponse;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import com.forever.foreverapi.model.entity.SavedAddress;
import com.forever.foreverapi.model.entity.WishlistItem;
import com.forever.foreverapi.repository.ProductRepository;
import com.forever.foreverapi.repository.SavedAddressRepository;
import com.forever.foreverapi.repository.UserRepository;
import com.forever.foreverapi.repository.WishlistItemRepository;
import com.forever.foreverapi.service.CustomerService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;

@Service
public class CustomerServiceImpl implements CustomerService {
    private final WishlistItemRepository wishlist;
    private final SavedAddressRepository addresses;
    private final UserRepository users;
    private final ProductRepository products;
    private final ProductMapper productMapper;

    public CustomerServiceImpl(WishlistItemRepository wishlist, SavedAddressRepository addresses,
                               UserRepository users, ProductRepository products, ProductMapper productMapper) {
        this.wishlist = wishlist; this.addresses = addresses; this.users = users;
        this.products = products; this.productMapper = productMapper;
    }

    @Override @Transactional(readOnly = true)
    public List<ProductResponse> wishlist(Long userId) {
        return wishlist.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(WishlistItem::getProduct).filter(p -> p.isActive()).map(productMapper::toResponse).toList();
    }

    @Override @Transactional
    public ProductResponse addWishlist(Long userId, Long productId) {
        var existing = wishlist.findByUserIdAndProductId(userId, productId);
        if (existing.isPresent()) return productMapper.toResponse(existing.get().getProduct());
        var item = new WishlistItem();
        item.setUser(users.findById(userId).orElseThrow(() -> ApiException.notFound("User not found")));
        item.setProduct(products.findByIdAndActiveTrue(productId).orElseThrow(() -> ApiException.notFound("Product not found")));
        wishlist.save(item);
        return productMapper.toResponse(item.getProduct());
    }

    @Override @Transactional
    public void removeWishlist(Long userId, Long productId) {
        wishlist.findByUserIdAndProductId(userId, productId).ifPresent(wishlist::delete);
    }

    @Override @Transactional(readOnly = true)
    public List<AddressResponse> addresses(Long userId) {
        var unique = new LinkedHashMap<String, AddressResponse>();
        addresses.findByUserIdOrderByCreatedAtDesc(userId).forEach(address ->
                unique.putIfAbsent(addressKey(address), response(address)));
        return List.copyOf(unique.values());
    }

    @Override @Transactional
    public AddressResponse addAddress(Long userId, AddressRequest r) {
        var existing = addresses.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .filter(address -> addressKey(address).equals(addressKey(r)))
                .findFirst();
        if (existing.isPresent()) return response(existing.get());

        var a = new SavedAddress();
        a.setUser(users.findById(userId).orElseThrow(() -> ApiException.notFound("User not found")));
        a.setLabel(r.label().trim()); a.setFirstName(r.firstName().trim()); a.setLastName(r.lastName().trim());
        a.setEmail(r.email().trim()); a.setStreet(r.street().trim()); a.setCity(r.city().trim());
        a.setState(r.state().trim()); a.setZipcode(r.zipcode().trim()); a.setCountry(r.country().trim());
        a.setPhone(r.phone().trim());
        return response(addresses.save(a));
    }

    @Override @Transactional
    public void deleteAddress(Long userId, Long addressId) {
        var a = addresses.findById(addressId).orElseThrow(() -> ApiException.notFound("Address not found"));
        if (!a.getUser().getId().equals(userId)) throw ApiException.notFound("Address not found");
        addresses.delete(a);
    }

    private static AddressResponse response(SavedAddress a) {
        return new AddressResponse(a.getId(), a.getLabel(), a.getFirstName(), a.getLastName(), a.getEmail(),
                a.getStreet(), a.getCity(), a.getState(), a.getZipcode(), a.getCountry(), a.getPhone());
    }

    private static String addressKey(SavedAddress a) {
        return addressKey(a.getLabel(), a.getFirstName(), a.getLastName(), a.getEmail(), a.getStreet(),
                a.getCity(), a.getState(), a.getZipcode(), a.getCountry(), a.getPhone());
    }

    private static String addressKey(AddressRequest a) {
        return addressKey(a.label(), a.firstName(), a.lastName(), a.email(), a.street(), a.city(), a.state(),
                a.zipcode(), a.country(), a.phone());
    }

    private static String addressKey(String... values) {
        return java.util.Arrays.stream(values)
                .map(value -> value == null ? "" : value.trim().toLowerCase(Locale.ROOT))
                .collect(java.util.stream.Collectors.joining("\u001f"));
    }
}
