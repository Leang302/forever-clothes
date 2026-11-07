package com.forever.foreverapi.service;

import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.model.dto.OrderDtos.AddressDto;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.model.entity.CartItem;
import com.forever.foreverapi.model.entity.PaymentMethod;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.CartItemRepository;
import com.forever.foreverapi.repository.ProductRepository;
import com.forever.foreverapi.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * Runs against the dev database (rolled back afterwards). Covers the GAP-010 fix: a replayed/double-tapped
 * "place order" request must not create a second order.
 */
@SpringBootTest
@Transactional
class OrderServiceIdempotencyTest {

    @Autowired
    OrderService orders;
    @Autowired
    AuthService auth;
    @Autowired
    UserRepository users;
    @Autowired
    ProductRepository products;
    @Autowired
    CartItemRepository cartItems;

    /** A guest account is a real, disposable customer row — convenient for standing up a fresh test user. */
    @Autowired
    GuestSessionService guestSessions;

    private ShopperRef freshCustomer() {
        return new com.forever.foreverapi.TestShoppers(users, guestSessions).customer();
    }

    @Autowired
    org.springframework.jdbc.core.simple.JdbcClient db;

    /** Active products with a size in stock, as (product, size) — the dev catalogue also holds hidden/sold-out items. */
    private List<Object[]> buyable(int count) {
        return db.sql("select distinct on (p.id) p.id, i.size from products p join product_inventory i"
                        + " on i.product_id = p.id where p.active and i.stock > 0 order by p.id, i.size limit :n")
                .param("n", count)
                .query((rs, n) -> new Object[]{products.findById(rs.getLong(1)).orElseThrow(), rs.getString(2)})
                .list();
    }

    private void addToCart(ShopperRef shopper, Object[] productAndSize) {
        CartItem item = new CartItem();
        item.setUser(users.getReferenceById(shopper.userId()));
        item.setProduct((Product) productAndSize[0]);
        item.setSize((String) productAndSize[1]);
        item.setQuantity(1);
        cartItems.save(item);
        cartItems.flush();
    }

    private PlaceOrderRequest request(String idempotencyKey) {
        AddressDto address = new AddressDto("Jane", "Doe", "jane@example.com", "1 Main St", "Phnom Penh",
                "Phnom Penh", "12000", "Cambodia", "012345678");
        return new PlaceOrderRequest(address, PaymentMethod.COD, null, null, null, idempotencyKey);
    }

    @Test
    void replayingTheSameIdempotencyKeyReturnsTheOriginalOrderInsteadOfCreatingASecondOne() {
        ShopperRef userId = freshCustomer();
        addToCart(userId, buyable(1).getFirst());
        String key = UUID.randomUUID().toString();

        OrderResponse first = orders.place(userId, request(key));
        // The cart is now empty; a naive re-run of place() would throw CART_EMPTY. The idempotency
        // check must short-circuit before that and hand back the order the first call already made.
        OrderResponse replay = orders.place(userId, request(key));

        assertEquals(first.id(), replay.id());
        assertEquals(1, orders.mine(userId.userId(), 0, 10).content().size());
    }

    @Test
    void differentIdempotencyKeysStillProduceSeparateOrders() {
        ShopperRef userId = freshCustomer();
        List<Object[]> catalog = buyable(2);
        addToCart(userId, catalog.get(0));
        OrderResponse first = orders.place(userId, request(UUID.randomUUID().toString()));
        // A different product/size, not a re-add of the same line: avoids a transient unique-constraint
        // conflict between this insert and the first order's still-unflushed cart-item delete.
        addToCart(userId, catalog.get(1));
        OrderResponse second = orders.place(userId, request(UUID.randomUUID().toString()));

        org.assertj.core.api.Assertions.assertThat(first.id()).isNotEqualTo(second.id());
    }

    @Test
    void anotherCustomersIdempotencyKeyCannotBeReplayedToReadTheirOrder() {
        ShopperRef owner = freshCustomer();
        addToCart(owner, buyable(1).getFirst());
        String key = UUID.randomUUID().toString();
        orders.place(owner, request(key));

        ShopperRef attacker = freshCustomer();
        assertThrows(com.forever.foreverapi.exception.ApiException.class, () -> orders.place(attacker, request(key)));
    }
}
