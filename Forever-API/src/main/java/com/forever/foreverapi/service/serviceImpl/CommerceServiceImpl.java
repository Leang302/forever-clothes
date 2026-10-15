package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.CommerceDtos.*;
import com.forever.foreverapi.service.CommerceService;
import com.forever.foreverapi.service.CouponService;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

@Service
public class CommerceServiceImpl implements CommerceService {
    private final JdbcClient db;
    private final AppProperties props;
    private final CouponService coupons;
    public CommerceServiceImpl(JdbcClient db, AppProperties props, CouponService coupons) { this.db = db; this.props = props; this.coupons = coupons; }

    public CheckoutOptions checkoutOptions() {
        var standard = props.shop().deliveryFee();
        return new CheckoutOptions(List.of(new ShippingOption("STANDARD", "Standard delivery", standard, "3–5 business days"),
                new ShippingOption("EXPRESS", "Express delivery", standard.add(new BigDecimal("10.00")), "1–2 business days")));
    }

    public Pricing price(BigDecimal amount, String rawCoupon, String rawShipping) {
        return price(amount, rawCoupon, rawShipping, null);
    }

    public Pricing price(BigDecimal amount, String rawCoupon, String rawShipping, Long userId) {
        String shipping = "EXPRESS".equalsIgnoreCase(rawShipping) ? "EXPRESS" : "STANDARD";
        BigDecimal fee = checkoutOptions().shippingMethods().stream().filter(s -> s.code().equals(shipping)).findFirst().orElseThrow().fee();
        String code = rawCoupon == null || rawCoupon.isBlank() ? null : rawCoupon.trim().toUpperCase();
        BigDecimal discount = code == null ? BigDecimal.ZERO : coupons.discountFor(code, amount, userId);
        return new Pricing(discount, code, fee, shipping);
    }

    public void reserve(Long productId, String size, int quantity) {
        int changed = db.sql("update product_inventory set stock=stock-:qty where product_id=:id and size=:size and stock>=:qty")
                .param("qty", quantity).param("id", productId).param("size", size).update();
        if (changed == 0) throw ApiException.conflict("OUT_OF_STOCK", "Not enough stock for size " + size);
    }
    public void restore(Long productId, String size, int quantity) {
        db.sql("update product_inventory set stock=stock+:qty where product_id=:id and size=:size")
                .param("qty", quantity).param("id", productId).param("size", size).update();
    }
    public void syncInventory(Long productId, List<String> sizes) {
        for (String size : sizes) db.sql("insert into product_inventory(product_id,size,stock) values(:id,:size,20) on conflict do nothing")
                .param("id", productId).param("size", size).update();
        db.sql("delete from product_inventory where product_id=:id and size not in (:sizes)")
                .param("id", productId).param("sizes", sizes).update();
    }
    public List<InventoryRow> inventory() {
        return db.sql("select i.product_id,p.name,i.size,i.stock from product_inventory i join products p on p.id=i.product_id order by i.stock,p.name,i.size")
                .query((rs, n) -> new InventoryRow(rs.getLong(1), rs.getString(2), rs.getString(3), rs.getInt(4), rs.getInt(4) <= 5)).list();
    }
    public void setStock(Long id, String size, int stock) {
        if (db.sql("update product_inventory set stock=:stock where product_id=:id and size=:size").param("stock", stock).param("id", id).param("size", size).update() == 0)
            throw ApiException.notFound("Product size not found");
    }
    /** Managed categories with how many products (all / visible) use each one. */
    public List<CategoryRow> categories() {
        return db.sql("""
                select c.id, c.name, c.active, count(p.id), count(p.id) filter (where p.active)
                from categories c left join products p on p.category = c.name
                group by c.id order by c.name""")
                .query((rs, n) -> new CategoryRow(rs.getLong(1), rs.getString(2), rs.getBoolean(3), rs.getLong(4), rs.getLong(5))).list();
    }
    public CategoryRow addCategory(String name) {
        try {
            return db.sql("insert into categories(name) values(:name) returning id,name,active").param("name", name.trim())
                    .query((rs, n) -> new CategoryRow(rs.getLong(1), rs.getString(2), rs.getBoolean(3), 0, 0)).single();
        } catch (DuplicateKeyException e) { throw ApiException.conflict("CATEGORY_EXISTS", "Category already exists"); }
    }
    /** Refuses to delete a category that products still use, so they don't end up with an unmanaged category. */
    public void deleteCategory(Long id) {
        long used = db.sql("select count(*) from products p join categories c on c.name = p.category where c.id = :id")
                .param("id", id).query(Long.class).single();
        if (used > 0) {
            throw ApiException.conflict("CATEGORY_IN_USE",
                    "Category is used by " + used + (used == 1 ? " product" : " products") + ". Move or delete them first.");
        }
        db.sql("delete from categories where id=:id").param("id", id).update();
    }
    public List<CustomerRow> customers() {
        return db.sql("select u.id,u.name,u.email,u.phone,count(o.id),coalesce(sum(case when o.status<>'CANCELLED' then o.total else 0 end),0),u.created_at from users u left join orders o on o.user_id=u.id where u.role='USER' group by u.id order by u.created_at desc")
                .query((rs,n) -> new CustomerRow(rs.getLong(1),rs.getString(2),rs.getString(3),rs.getString(4),rs.getLong(5),rs.getBigDecimal(6),rs.getTimestamp(7).toInstant())).list();
    }
    public Analytics analytics() {
        var revenue = db.sql("select (created_at at time zone 'UTC')::date,coalesce(sum(total),0) from orders where status<>'CANCELLED' and created_at>=now()-interval '30 days' group by 1 order by 1")
                .query((rs,n) -> new RevenuePoint(rs.getDate(1).toLocalDate(),rs.getBigDecimal(2))).list();
        var top = db.sql("select oi.product_id,oi.name,sum(oi.quantity),sum(oi.price*oi.quantity) from order_items oi join orders o on o.id=oi.order_id where o.status<>'CANCELLED' group by oi.product_id,oi.name order by sum(oi.quantity) desc limit 5")
                .query((rs,n) -> new TopProduct(rs.getObject(1,Long.class),rs.getString(2),rs.getLong(3),rs.getBigDecimal(4))).list();
        long low = db.sql("select count(*) from product_inventory where stock<=5").query(Long.class).single();
        return new Analytics(revenue, top, low);
    }
}
