package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.service.CartService;

import com.forever.foreverapi.util.MediaUrls;
import com.forever.foreverapi.common.security.ShopperRef;
import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.mapper.ProductMapper;
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
import java.util.Map;

@Service
public class CartServiceImpl implements CartService {

    private static final int MAX_QTY = 99;

    private final CartItemRepository items;
    private final ProductRepository products;
    private final UserRepository users;
    private final MediaUrls media;
    private final AppProperties props;
    private final ProductMapper productMapper;
    private final com.forever.foreverapi.service.ShopperLocks locks;

    public CartServiceImpl(CartItemRepository items, ProductRepository products, UserRepository users,
                       MediaUrls media, AppProperties props, ProductMapper productMapper,
                       com.forever.foreverapi.service.ShopperLocks locks) {
        this.locks = locks;
        this.productMapper = productMapper;
        this.items = items;
        this.products = products;
        this.users = users;
        this.media = media;
        this.props = props;
    }

    @Transactional(readOnly = true)
    public CartResponse get(ShopperRef shopper) {
        return toResponse(items.findAllFor(shopper));
    }

    @Transactional
    public CartResponse add(ShopperRef shopper, Long productId, String size, int quantity) {
        locks.lock(shopper); // two adds of a new line would otherwise both insert and one would hit the unique index
        Product product = activeProduct(productId, size);
        CartItem item = items.findLine(shopper, productId, size).orElseGet(() -> {
            CartItem c = new CartItem();
            if (shopper.isGuest()) c.setGuestSessionId(shopper.guestSessionId());
            else c.setUser(users.getReferenceById(shopper.userId()));
            c.setProduct(product);
            c.setSize(size);
            return c;
        });
        int wanted = Math.min(item.getQuantity() + quantity, MAX_QTY);
        requireStock(product, size, wanted);
        item.setQuantity(wanted);
        items.save(item);
        return get(shopper);
    }

    /** quantity 0 removes the line. */
    @Transactional
    public CartResponse setQuantity(ShopperRef shopper, Long productId, String size, int quantity) {
        locks.lock(shopper);
        CartItem item = items.findLine(shopper, productId, size)
                .orElseThrow(() -> ApiException.notFound("Item is not in your cart"));
        if (quantity == 0) {
            items.delete(item);
        } else {
            requireStock(item.getProduct(), size, quantity);
            item.setQuantity(quantity);
        }
        items.flush();
        return get(shopper);
    }

    @Transactional
    public CartResponse remove(ShopperRef shopper, Long itemId) {
        locks.lock(shopper);
        items.findLineById(shopper, itemId).ifPresent(items::delete);
        items.flush();
        return get(shopper);
    }

    @Transactional
    public void clear(ShopperRef shopper) {
        items.deleteAllFor(shopper);
    }

    private Product activeProduct(Long productId, String size) {
        Product p = products.findByIdAndActiveTrue(productId)
                .orElseThrow(() -> ApiException.notFound("Product not found"));
        if (!p.getSizes().contains(size)) {
            throw ApiException.badRequest("INVALID_SIZE", "Size " + size + " is not available for this product");
        }
        return p;
    }

    /**
     * Advisory check so the shopper hears about it when adding, not at checkout. The authoritative,
     * race-safe check is the conditional decrement in CommerceService.reserve() when the order is placed.
     */
    private void requireStock(Product product, String size, int quantity) {
        int left = productMapper.stockFor(List.of(product.getId()))
                .getOrDefault(product.getId(), Map.of()).getOrDefault(size, 0);
        if (quantity > left) {
            throw ApiException.conflict("OUT_OF_STOCK", left == 0
                    ? product.getName() + " is out of stock in size " + size
                    : "Only " + left + " left of " + product.getName() + " in size " + size);
        }
    }

    private CartResponse toResponse(List<CartItem> list) {
        Map<Long, Map<String, Integer>> stock = productMapper.stockFor(
                list.stream().map(c -> c.getProduct().getId()).distinct().toList());
        List<CartLine> lines = list.stream().map(c -> {
            Product p = c.getProduct();
            BigDecimal line = p.getPrice().multiply(BigDecimal.valueOf(c.getQuantity()));
            String image = p.getImages().isEmpty() ? null : media.url(p.getImages().get(0));
            return new CartLine(c.getId(), p.getId(), p.getName(), p.getPrice(), image, c.getSize(),
                    c.getQuantity(), line,
                    stock.getOrDefault(p.getId(), Map.of()).getOrDefault(c.getSize(), 0));
        }).toList();
        BigDecimal subtotal = lines.stream().map(CartLine::lineTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
        int count = lines.stream().mapToInt(CartLine::quantity).sum();
        BigDecimal fee = lines.isEmpty() ? BigDecimal.ZERO : props.shop().deliveryFee();
        return new CartResponse(lines, count, subtotal, fee, subtotal.add(fee), props.shop().currency());
    }
}
