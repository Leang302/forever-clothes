package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.service.CartService;

import com.forever.foreverapi.util.MediaUrls;
import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.CartDtos.CartLine;
import com.forever.foreverapi.model.dto.CartDtos.CartResponse;
import com.forever.foreverapi.model.entity.CartItem;
import com.forever.foreverapi.repository.CartItemRepository;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.ProductRepository;
import com.forever.foreverapi.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class CartServiceImpl implements CartService {

    private static final int MAX_QTY = 99;

    private final CartItemRepository items;
    private final ProductRepository products;
    private final UserRepository users;
    private final MediaUrls media;
    private final AppProperties props;

    public CartServiceImpl(CartItemRepository items, ProductRepository products, UserRepository users,
                       MediaUrls media, AppProperties props) {
        this.items = items;
        this.products = products;
        this.users = users;
        this.media = media;
        this.props = props;
    }

    @Transactional(readOnly = true)
    public CartResponse get(Long userId) {
        return toResponse(items.findAllByUser(userId));
    }

    @Transactional
    public CartResponse add(Long userId, Long productId, String size, int quantity) {
        Product product = activeProduct(productId, size);
        CartItem item = items.findByUserIdAndProductIdAndSize(userId, productId, size).orElseGet(() -> {
            CartItem c = new CartItem();
            c.setUser(users.getReferenceById(userId));
            c.setProduct(product);
            c.setSize(size);
            return c;
        });
        item.setQuantity(Math.min(item.getQuantity() + quantity, MAX_QTY));
        items.save(item);
        return get(userId);
    }

    /** quantity 0 removes the line. */
    @Transactional
    public CartResponse setQuantity(Long userId, Long productId, String size, int quantity) {
        CartItem item = items.findByUserIdAndProductIdAndSize(userId, productId, size)
                .orElseThrow(() -> ApiException.notFound("Item is not in your cart"));
        if (quantity == 0) {
            items.delete(item);
        } else {
            item.setQuantity(quantity);
        }
        items.flush();
        return get(userId);
    }

    @Transactional
    public CartResponse remove(Long userId, Long itemId) {
        items.findByIdAndUserId(itemId, userId).ifPresent(items::delete);
        items.flush();
        return get(userId);
    }

    @Transactional
    public void clear(Long userId) {
        items.deleteAllByUser(userId);
    }

    private Product activeProduct(Long productId, String size) {
        Product p = products.findByIdAndActiveTrue(productId)
                .orElseThrow(() -> ApiException.notFound("Product not found"));
        if (!p.getSizes().contains(size)) {
            throw ApiException.badRequest("INVALID_SIZE", "Size " + size + " is not available for this product");
        }
        return p;
    }

    private CartResponse toResponse(List<CartItem> list) {
        List<CartLine> lines = list.stream().map(c -> {
            Product p = c.getProduct();
            BigDecimal line = p.getPrice().multiply(BigDecimal.valueOf(c.getQuantity()));
            String image = p.getImages().isEmpty() ? null : media.url(p.getImages().get(0));
            return new CartLine(c.getId(), p.getId(), p.getName(), p.getPrice(), image, c.getSize(),
                    c.getQuantity(), line);
        }).toList();
        BigDecimal subtotal = lines.stream().map(CartLine::lineTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
        int count = lines.stream().mapToInt(CartLine::quantity).sum();
        BigDecimal fee = lines.isEmpty() ? BigDecimal.ZERO : props.shop().deliveryFee();
        return new CartResponse(lines, count, subtotal, fee, subtotal.add(fee), props.shop().currency());
    }
}
