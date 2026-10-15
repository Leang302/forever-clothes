package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.mapper.OrderMapper;
import com.forever.foreverapi.mapper.ProductMapper;
import com.forever.foreverapi.model.dto.OrderDtos.OrderResponse;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import com.forever.foreverapi.model.entity.Order;
import com.forever.foreverapi.model.entity.OrderStatus;
import com.forever.foreverapi.model.entity.PaymentMethod;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.OrderRepository;
import com.forever.foreverapi.repository.ProductRepository;
import com.forever.foreverapi.service.AdminSearchService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Builds the WHERE / ORDER BY in SQL (so sorting by computed values like stock works), fetches one page of ids,
 * then loads the entities and maps them with the regular mappers so responses match the rest of the API.
 */
@Service
public class AdminSearchServiceImpl implements AdminSearchService {

    private static final Map<String, String> ORDER_SORTS = Map.of(
            "newest", "o.created_at desc, o.id desc",
            "oldest", "o.created_at asc, o.id asc",
            "total_desc", "o.total desc, o.id desc",
            "total_asc", "o.total asc, o.id desc",
            "status", statusOrder() + ", o.created_at desc, o.id desc");

    private static final Map<String, String> PRODUCT_SORTS = Map.of(
            "newest", "p.created_at desc, p.id desc",
            "oldest", "p.created_at asc, p.id asc",
            "name_asc", "lower(p.name) asc, p.id asc",
            "name_desc", "lower(p.name) desc, p.id desc",
            "price_asc", "p.price asc, p.id asc",
            "price_desc", "p.price desc, p.id desc",
            "stock_asc", "coalesce(s.stock, 0) asc, p.id asc",
            "stock_desc", "coalesce(s.stock, 0) desc, p.id desc");

    private final JdbcClient db;
    private final OrderRepository orders;
    private final ProductRepository products;
    private final OrderMapper orderMapper;
    private final ProductMapper productMapper;

    public AdminSearchServiceImpl(JdbcClient db, OrderRepository orders, ProductRepository products,
                                  OrderMapper orderMapper, ProductMapper productMapper) {
        this.db = db;
        this.orders = orders;
        this.products = products;
        this.orderMapper = orderMapper;
        this.productMapper = productMapper;
    }

    @Transactional(readOnly = true)
    public PageResponse<OrderResponse> orders(String q, String status, String paymentMethod, Boolean paid,
                                              LocalDate from, LocalDate to, String coupon, String sort, int page, int size) {
        List<String> where = new ArrayList<>();
        Map<String, Object> params = new HashMap<>();
        if (q != null && !q.isBlank()) {
            String term = q.trim();
            String digits = term.startsWith("#") ? term.substring(1) : term;
            String idMatch = digits.matches("\\d{1,18}") ? "o.id = :qid or " : "";
            if (!idMatch.isEmpty()) params.put("qid", Long.parseLong(digits));
            where.add("(" + idMatch + "lower(o.first_name || ' ' || o.last_name) like :q or lower(o.email) like :q"
                    + " or o.phone like :q or lower(u.name) like :q or lower(u.email) like :q)");
            params.put("q", "%" + term.toLowerCase(Locale.ROOT) + "%");
        }
        if (status != null && !status.isBlank()) {
            where.add("o.status = :status");
            params.put("status", parse(OrderStatus.class, status, "status").name());
        }
        if (paymentMethod != null && !paymentMethod.isBlank()) {
            where.add("o.payment_method = :pm");
            params.put("pm", parse(PaymentMethod.class, paymentMethod, "payment method").name());
        }
        if (paid != null) {
            where.add("o.paid = :paid");
            params.put("paid", paid);
        }
        if (from != null) {
            where.add("o.created_at >= :from");
            params.put("from", Timestamp.from(from.atStartOfDay(ZoneOffset.UTC).toInstant()));
        }
        if (to != null) {
            where.add("o.created_at < :to");
            params.put("to", Timestamp.from(to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant()));
        }
        if (coupon != null && !coupon.isBlank()) {
            where.add("upper(o.coupon_code) = :coupon");
            params.put("coupon", coupon.trim().toUpperCase());
        }
        String base = " from orders o join users u on u.id = o.user_id" + whereClause(where);
        return page(base, ORDER_SORTS.getOrDefault(sort, ORDER_SORTS.get("newest")), "o.id", params, page, size,
                orders::findAllById, Order::getId, orderMapper::toResponse);
    }

    @Transactional(readOnly = true)
    public PageResponse<ProductResponse> products(String q, List<String> categories, List<String> subCategories, Boolean active,
                                                  String sort, int page, int size) {
        List<String> where = new ArrayList<>();
        Map<String, Object> params = new HashMap<>();
        if (q != null && !q.isBlank()) {
            String term = q.trim();
            String digits = term.startsWith("#") ? term.substring(1) : term;
            if (digits.matches("\\d{1,18}")) {
                where.add("(p.id = :qid or lower(p.name) like :q)");
                params.put("qid", Long.parseLong(digits));
            } else {
                where.add("lower(p.name) like :q");
            }
            params.put("q", "%" + term.toLowerCase(Locale.ROOT) + "%");
        }
        List<String> cats = split(categories);
        if (!cats.isEmpty()) {
            where.add("p.category in (:cats)");
            params.put("cats", cats);
        }
        List<String> subs = split(subCategories);
        if (!subs.isEmpty()) {
            where.add("p.sub_category in (:subs)");
            params.put("subs", subs);
        }
        if (active != null) {
            where.add("p.active = :active");
            params.put("active", active);
        }
        String base = " from products p left join (select product_id, sum(stock) as stock from product_inventory group by product_id) s"
                + " on s.product_id = p.id" + whereClause(where);
        String order = PRODUCT_SORTS.getOrDefault(sort, PRODUCT_SORTS.get("newest"));
        return page(base, order, "p.id", params, page, size, products::findAllById, Product::getId, productMapper::toResponse);
    }

    // ---- helpers ----

    private <E, R> PageResponse<R> page(String base, String orderBy, String idColumn, Map<String, Object> params, int page, int size,
                                        Function<List<Long>, List<E>> load, Function<E, Long> idOf, Function<E, R> mapper) {
        int p = Math.max(page, 0);
        int s = Math.min(Math.max(size, 1), 100);
        long total = db.sql("select count(*)" + base).params(params).query(Long.class).single();
        Map<String, Object> pageParams = new HashMap<>(params);
        pageParams.put("limit", s);
        pageParams.put("offset", (long) p * s);
        List<Long> ids = db.sql("select " + idColumn + base + " order by " + orderBy + " limit :limit offset :offset")
                .params(pageParams).query(Long.class).list();
        Map<Long, E> byId = load.apply(ids).stream().collect(Collectors.toMap(idOf, Function.identity()));
        List<R> content = ids.stream().map(byId::get).filter(Objects::nonNull).map(mapper).toList();
        int totalPages = (int) ((total + s - 1) / s);
        return new PageResponse<>(content, p, s, total, totalPages, p + 1 >= totalPages);
    }

    private static String whereClause(List<String> where) {
        return where.isEmpty() ? "" : " where " + String.join(" and ", where);
    }

    /** Accepts repeated params and comma-separated values (?category=Men&category=Women or ?category=Men,Women). */
    private static List<String> split(List<String> values) {
        if (values == null) return List.of();
        return values.stream().flatMap(v -> Arrays.stream(v.split(","))).map(String::trim).filter(v -> !v.isEmpty()).distinct().toList();
    }

    private static <T extends Enum<T>> T parse(Class<T> type, String value, String label) {
        try {
            return Enum.valueOf(type, value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw ApiException.badRequest("INVALID_FILTER", "Unknown " + label + ": " + value);
        }
    }

    /** Sort by position in the order lifecycle rather than alphabetically. */
    private static String statusOrder() {
        StringBuilder sb = new StringBuilder("case o.status");
        OrderStatus[] values = OrderStatus.values();
        for (int i = 0; i < values.length; i++) sb.append(" when '").append(values[i].name()).append("' then ").append(i);
        return sb.append(" else 99 end").toString();
    }
}
