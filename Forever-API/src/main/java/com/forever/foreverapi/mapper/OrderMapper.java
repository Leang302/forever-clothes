package com.forever.foreverapi.mapper;

import com.forever.foreverapi.util.MediaUrls;
import com.forever.foreverapi.model.dto.OrderDtos.AddressDto;
import com.forever.foreverapi.model.dto.OrderDtos.OrderItemResponse;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.entity.Order;
import com.forever.foreverapi.model.entity.ShippingAddress;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class OrderMapper {

    private final MediaUrls media;

    public OrderMapper(MediaUrls media) {
        this.media = media;
    }

    public ShippingAddress toEntity(AddressDto a) {
        return new ShippingAddress(a.firstName().trim(), a.lastName().trim(), a.email().trim(), a.street().trim(),
                a.city().trim(), a.state().trim(), a.zipcode().trim(), a.country().trim(), a.phone().trim());
    }

    public AddressDto toDto(ShippingAddress a) {
        return new AddressDto(a.getFirstName(), a.getLastName(), a.getEmail(), a.getStreet(), a.getCity(),
                a.getState(), a.getZipcode(), a.getCountry(), a.getPhone());
    }

    public OrderResponse toResponse(Order o) {
        List<OrderItemResponse> items = o.getItems().stream()
                .map(i -> new OrderItemResponse(i.getProductId(), i.getName(),
                        i.getImageKey() == null ? null : media.url(i.getImageKey()), i.getPrice(), i.getSize(),
                        i.getQuantity()))
                .toList();
        return new OrderResponse(o.getId(), o.getStatus(), o.getPaymentMethod(), o.isPaid(), o.getItemsAmount(),
                o.getDeliveryFee(), o.getDiscount(), o.getCouponCode(), o.getShippingMethod(), o.getTotal(),
                toDto(o.getAddress()), items, o.getUser().getId(), o.getCreatedAt(), o.getStatus().next());
    }
}
