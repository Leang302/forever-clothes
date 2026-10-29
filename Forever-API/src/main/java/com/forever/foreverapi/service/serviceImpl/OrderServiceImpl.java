package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.service.OrderService;
import com.forever.foreverapi.service.CommerceService;
import com.forever.foreverapi.service.NotificationService;
import com.forever.foreverapi.client.mail.EmailService;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.entity.CartItem;
import com.forever.foreverapi.repository.CartItemRepository;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.OrderDtos.PlaceOrderRequest;
import com.forever.foreverapi.mapper.OrderMapper;
import com.forever.foreverapi.model.entity.Order;
import com.forever.foreverapi.model.entity.OrderItem;
import com.forever.foreverapi.model.entity.OrderStatus;
import com.forever.foreverapi.model.entity.PaymentMethod;
import com.forever.foreverapi.repository.OrderRepository;
import com.forever.foreverapi.repository.ProductRepository;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;

@Service
public class OrderServiceImpl implements OrderService {

    private static final Set<OrderStatus> CANCELLABLE = EnumSet.of(OrderStatus.PAYMENT_PENDING, OrderStatus.ORDER_PLACED);
    private static final Sort NEWEST = Sort.by(Sort.Direction.DESC, "createdAt", "id");

    private final OrderRepository orders;
    private final CartItemRepository cartItems;
    private final UserRepository users;
    private final ProductRepository products;
    private final OrderMapper mapper;
    private final AppProperties props;
    private final CommerceService commerce;
    private final EmailService email;
    private final NotificationService notifications;

    public OrderServiceImpl(OrderRepository orders, CartItemRepository cartItems, UserRepository users, ProductRepository products,
                        OrderMapper mapper, AppProperties props, CommerceService commerce, EmailService email,
                        NotificationService notifications) {
        this.orders = orders;
        this.cartItems = cartItems;
        this.users = users;
        this.products = products;
        this.mapper = mapper;
        this.props = props;
        this.commerce = commerce;
        this.email = email;
        this.notifications = notifications;
    }

    private static String orderLink(Long id) {
        return "/admin/orders?q=%23" + id;
    }

    private void notifyNewOrder(Order o) {
        var a = o.getAddress();
        notifications.notifyAdmins(NotificationService.NEW_ORDER, "New order #" + o.getId(),
                a.getFirstName() + " " + a.getLastName() + " · $" + o.getTotal() + " · " + o.getItems().size()
                        + (o.getItems().size() == 1 ? " item" : " items"), orderLink(o.getId()));
    }

    @Transactional
    public OrderResponse place(Long userId, PlaceOrderRequest req) {
        List<CartItem> cart = selectedCartItems(userId, req.cartItemIds());
        if (cart.isEmpty()) {
            throw ApiException.badRequest("CART_EMPTY", "Your cart is empty");
        }

        Order order = new Order();
        order.setUser(users.getReferenceById(userId));
        order.setPaymentMethod(req.paymentMethod());
        order.setStatus(req.paymentMethod().isOnline() ? OrderStatus.PAYMENT_PENDING : OrderStatus.ORDER_PLACED);
        order.setAddress(mapper.toEntity(req.address()));

        BigDecimal itemsAmount = BigDecimal.ZERO;
        for (CartItem c : cart) {
            Product p = c.getProduct();
            if (!p.isActive()) {
                throw ApiException.conflict("PRODUCT_UNAVAILABLE", p.getName() + " is no longer available");
            }
            commerce.reserve(p.getId(), c.getSize(), c.getQuantity());
            OrderItem item = new OrderItem();
            item.setProductId(p.getId());
            item.setName(p.getName());
            item.setImageKey(p.getImages().isEmpty() ? null : p.getImages().get(0));
            item.setPrice(p.getPrice());
            item.setSize(c.getSize());
            item.setQuantity(c.getQuantity());
            order.addItem(item);
            itemsAmount = itemsAmount.add(p.getPrice().multiply(BigDecimal.valueOf(c.getQuantity())));
        }
        order.setItemsAmount(itemsAmount);
        var pricing = commerce.price(itemsAmount, req.couponCode(), req.shippingMethod(), userId);
        order.setDeliveryFee(pricing.deliveryFee());
        order.setDiscount(pricing.discount());
        order.setCouponCode(pricing.couponCode());
        order.setShippingMethod(pricing.shippingMethod());
        order.setTotal(itemsAmount.subtract(pricing.discount()).add(pricing.deliveryFee()));

        Order saved = orders.save(order);
        cartItems.deleteAll(cart); // only the lines that were bought
        if (req.paymentMethod() == PaymentMethod.COD) {
            email.sendOrderConfirmation(req.address().email(), saved.getId(), saved.getTotal());
            notifyNewOrder(saved); // online orders notify once paid
        }
        return mapper.toResponse(saved);
    }

    @Transactional(readOnly = true)
    public PageResponse<OrderResponse> mine(Long userId, int page, int size) {
        return PageResponse.of(orders.findCustomerVisibleByUserId(userId, PaymentMethod.COD, pageable(page, size)),
                mapper::toResponse);
    }

    @Transactional(readOnly = true)
    public OrderResponse getMine(Long userId, Long id) {
        return mapper.toResponse(orders.findByIdAndUserId(id, userId)
                .orElseThrow(() -> ApiException.notFound("Order not found")));
    }

    @Transactional
    public OrderResponse cancel(Long userId, Long id) {
        Order o = orders.findByIdAndUserId(id, userId).orElseThrow(() -> ApiException.notFound("Order not found"));
        if (!CANCELLABLE.contains(o.getStatus())) {
            throw ApiException.conflict("ORDER_NOT_CANCELLABLE", "This order can no longer be cancelled");
        }
        o.setStatus(OrderStatus.CANCELLED);
        o.setCancelledBy("CUSTOMER");
        o.getItems().forEach(i -> { if (i.getProductId() != null) commerce.restore(i.getProductId(), i.getSize(), i.getQuantity()); });
        var a = o.getAddress();
        notifications.notifyAdmins(NotificationService.ORDER_CANCELLED, "Order #" + o.getId() + " cancelled by the customer",
                a.getFirstName() + " " + a.getLastName() + " · $" + o.getTotal() + " · stock was put back", orderLink(o.getId()));
        return mapper.toResponse(o);
    }

    @Transactional
    public void abortOnlinePayment(Long userId, Long id) {
        Order order = orders.findByIdAndUserId(id, userId)
                .orElseThrow(() -> ApiException.notFound("Order not found"));
        if (!order.getPaymentMethod().isOnline() || order.isPaid()
                || order.getStatus() != OrderStatus.PAYMENT_PENDING) {
            throw ApiException.conflict("PAYMENT_NOT_PENDING", "This payment can no longer be cancelled");
        }

        var user = users.getReferenceById(userId);
        order.getItems().forEach(item -> {
            if (item.getProductId() == null) return;
            var cartItem = cartItems.findByUserIdAndProductIdAndSize(userId, item.getProductId(), item.getSize())
                    .orElseGet(() -> {
                        var created = new CartItem();
                        created.setUser(user);
                        created.setProduct(products.getReferenceById(item.getProductId()));
                        created.setSize(item.getSize());
                        return created;
                    });
            cartItem.setQuantity(cartItem.getQuantity() + item.getQuantity());
            cartItems.save(cartItem);
            commerce.restore(item.getProductId(), item.getSize(), item.getQuantity());
        });
        order.setStatus(OrderStatus.CANCELLED);
        order.setCancelledBy("CUSTOMER");
        order.setCancelReason("Online payment was not completed");
    }

    // ---- admin ----

    @Transactional(readOnly = true)
    public PageResponse<OrderResponse> all(OrderStatus status, int page, int size) {
        var pageable = pageable(page, size);
        return PageResponse.of(status == null ? orders.findAll(pageable) : orders.findByStatus(status, pageable),
                mapper::toResponse);
    }

    @Transactional(readOnly = true)
    public PageResponse<OrderResponse> forCustomer(Long userId, int page, int size) {
        return PageResponse.of(orders.findByUserId(userId, pageable(page, size)), mapper::toResponse);
    }

    @Transactional
    public OrderResponse updateStatus(Long id, OrderStatus status, String rawReason) {
        Order o = orders.findById(id).orElseThrow(() -> ApiException.notFound("Order not found"));
        if (status == o.getStatus()) return mapper.toResponse(o);
        if (!o.getStatus().next().contains(status)) {
            throw ApiException.conflict("INVALID_STATUS_CHANGE", invalidChangeMessage(o.getStatus(), status));
        }
        String reason = rawReason == null ? "" : rawReason.trim();
        if (status == OrderStatus.CANCELLED && reason.length() < 5) {
            throw ApiException.badRequest("CANCEL_REASON_REQUIRED", "Tell the customer why the order is cancelled (at least 5 characters)");
        }
        o.setStatus(status);
        if (status == OrderStatus.CANCELLED) {
            o.setCancelReason(reason);
            o.setCancelledBy("ADMIN");
            o.getItems().forEach(i -> { if (i.getProductId() != null) commerce.restore(i.getProductId(), i.getSize(), i.getQuantity()); });
            var a = o.getAddress();
            email.sendOrderCancelled(a.getEmail(), a.getFirstName(), o.getId(), o.getTotal(), reason);
        }
        if (status == OrderStatus.DELIVERED && o.getPaymentMethod() == PaymentMethod.COD) {
            o.setPaid(true); // cash collected on delivery
        }
        return mapper.toResponse(o);
    }

    /** The cart lines being checked out: all of them, or only [ids] when the customer picked some. */
    private List<CartItem> selectedCartItems(Long userId, List<Long> ids) {
        List<CartItem> all = cartItems.findAllByUser(userId);
        if (ids == null || ids.isEmpty()) return all;
        Set<Long> wanted = Set.copyOf(ids);
        List<CartItem> selected = all.stream().filter(c -> wanted.contains(c.getId())).toList();
        if (selected.size() != wanted.size()) {
            throw ApiException.conflict("CART_CHANGED", "Some selected items are no longer in your cart. Please review your cart and try again");
        }
        return selected;
    }

    private static String invalidChangeMessage(OrderStatus from, OrderStatus to) {
        if (from == OrderStatus.DELIVERED || from == OrderStatus.CANCELLED) return "A " + label(from) + " order cannot change status";
        if (from == OrderStatus.PAYMENT_PENDING) return "This order is still waiting for payment; it can only be cancelled";
        if (to == OrderStatus.CANCELLED) return "An order cannot be cancelled once it has shipped";
        if (to == OrderStatus.PAYMENT_PENDING) return "An order cannot go back to waiting for payment";
        if (to.ordinal() < from.ordinal()) return "An order cannot move back from " + label(from) + " to " + label(to);
        return "Move the order one step at a time: next is " + label(from.next().get(0));
    }

    private static String label(OrderStatus status) {
        return status.name().toLowerCase().replace('_', ' ');
    }

    @Transactional
    public void confirmOnlinePayment(Long orderId) {
        Order order = orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order not found"));
        if (!order.getPaymentMethod().isOnline()) throw ApiException.badRequest("PAYMENT_MISMATCH", "Order is not an online payment order");
        if (!order.isPaid()) {
            order.setPaid(true);
            // A payment that lands after the order was cancelled is recorded but does not revive the order.
            if (order.getStatus() == OrderStatus.PAYMENT_PENDING) {
                order.setStatus(OrderStatus.ORDER_PLACED);
                email.sendOrderConfirmation(order.getAddress().getEmail(), order.getId(), order.getTotal());
                notifyNewOrder(order);
            }
        }
    }

    @Transactional
    public void recordKhqrPayment(Long orderId, String md5) {
        orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order not found")).setKhqrMd5(md5);
    }

    private static org.springframework.data.domain.Pageable pageable(int page, int size) {
        return PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100), NEWEST);
    }
}
