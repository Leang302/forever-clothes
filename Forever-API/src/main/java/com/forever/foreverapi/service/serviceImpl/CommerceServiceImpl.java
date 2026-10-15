package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.CommerceDtos.*;
import com.forever.foreverapi.service.CommerceService;
import com.forever.foreverapi.service.CouponService;
import com.forever.foreverapi.service.NotificationService;
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
    private final NotificationService notifications;
    public CommerceServiceImpl(JdbcClient db, AppProperties props, CouponService coupons, NotificationService notifications) {
        this.db = db; this.props = props; this.coupons = coupons; this.notifications = notifications;
    }

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
        Integer left = db.sql("update product_inventory set stock=stock-:qty where product_id=:id and size=:size and stock>=:qty"
                        + " returning stock")
                .param("qty", quantity).param("id", productId).param("size", size).query(Integer.class).optional().orElse(null);
        if (left == null) throw ApiException.conflict("OUT_OF_STOCK", "Not enough stock for size " + size);
        // Notify once, when this order takes the size to the low-stock level (same threshold as the inventory page).
        if (left <= LOW_STOCK && left + quantity > LOW_STOCK) {
            String name = db.sql("select name from products where id=:id").param("id", productId).query(String.class).single();
            notifications.notifyAdmins(NotificationService.LOW_STOCK,
                    left == 0 ? "Out of stock: " + name + " (" + size + ")" : "Low stock: " + name + " (" + size + ")",
                    left == 0 ? "Size " + size + " is sold out." : "Only " + left + " left in size " + size + ".",
                    "/admin/inventory");
        }
    }

    private static final int LOW_STOCK = 5;
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
    public CategoryRow addCategory(String rawName) {
        String name = validCategoryName(rawName, null);
        try {
            return db.sql("insert into categories(name) values(:name) returning id,name,active").param("name", name)
                    .query((rs, n) -> new CategoryRow(rs.getLong(1), rs.getString(2), rs.getBoolean(3), 0, 0)).single();
        } catch (DuplicateKeyException e) { throw categoryExists(name); }
    }

    @Transactional
    public CategoryRow renameCategory(Long id, String rawName) {
        String old = categoryName(id);
        String name = validCategoryName(rawName, id);
        db.sql("update categories set name=:name where id=:id").param("name", name).param("id", id).update();
        db.sql("update products set category=:name where category=:old").param("name", name).param("old", old).update();
        return categories().stream().filter(c -> c.id().equals(id)).findFirst().orElseThrow();
    }

    @Transactional
    public MoveProductsResult moveProducts(Long fromId, Long targetId, Long targetSubCategoryId, List<Long> productIds) {
        String from = categoryName(fromId);
        if (fromId.equals(targetId) && targetSubCategoryId == null) {
            throw ApiException.badRequest("SAME_CATEGORY", "Choose a different category or a sub-category to move the products to");
        }
        String target = categoryName(targetId);
        String sub = null;
        if (targetSubCategoryId != null) {
            SubCategoryRow row = subCategory(targetSubCategoryId);
            if (!row.categoryId().equals(targetId)) {
                throw ApiException.badRequest("OTHER_CATEGORY", "\"" + row.name() + "\" is not a sub-category of \"" + target + "\"");
            }
            sub = row.name();
        }
        boolean all = productIds == null || productIds.isEmpty();
        if (!all) {
            long inSource = db.sql("select count(*) from products where id in (:ids) and category=:from")
                    .param("ids", productIds).param("from", from).query(Long.class).single();
            if (inSource != productIds.stream().distinct().count()) {
                throw ApiException.conflict("PRODUCTS_CHANGED",
                        "Some selected products are no longer in \"" + from + "\". Refresh and try again.");
            }
        }
        // Without a target sub-category the products keep their own (coalesce with a null param = unchanged).
        String set = "update products set category=:target, sub_category=coalesce(cast(:sub as varchar), sub_category)"
                + " where category=:from";
        int moved = (all ? db.sql(set) : db.sql(set + " and id in (:ids)").param("ids", productIds))
                .param("target", target).param("sub", sub).param("from", from).update();
        if (sub == null) {
            // Moved products keep their sub-category, so make sure the target category has it too.
            db.sql("insert into sub_categories(category_id,name) select distinct :targetId, sub_category from products"
                    + " where category=:target on conflict do nothing").param("targetId", targetId).param("target", target).update();
        }
        return new MoveProductsResult(moved, target, sub);
    }

    /** A category that products still use can only be deleted by moving them somewhere else in the same step. */
    @Transactional
    public void deleteCategory(Long id, Long moveToId, Long moveToSubId) {
        String name = categoryName(id);
        long used = db.sql("select count(*) from products where category=:name").param("name", name).query(Long.class).single();
        if (used > 0) {
            if (moveToId == null) {
                throw ApiException.conflict("CATEGORY_IN_USE", "\"" + name + "\" still has " + used
                        + (used == 1 ? " product" : " products") + ". Choose a category to move them to before deleting it.");
            }
            if (moveToId.equals(id)) {
                throw ApiException.badRequest("SAME_CATEGORY", "Choose another category to move the products to");
            }
            moveProducts(id, moveToId, moveToSubId, null);
        }
        db.sql("delete from categories where id=:id").param("id", id).update();
    }

    public String requireCategory(String name) {
        String wanted = name == null ? "" : name.trim();
        return db.sql("select name from categories where lower(name)=lower(:name)").param("name", wanted)
                .query(String.class).optional()
                .orElseThrow(() -> ApiException.badRequest("UNKNOWN_CATEGORY",
                        "Category \"" + wanted + "\" does not exist. Add it on the Categories page first."));
    }

    private String categoryName(Long id) {
        return db.sql("select name from categories where id=:id").param("id", id).query(String.class).optional()
                .orElseThrow(() -> ApiException.notFound("Category not found"));
    }

    public List<SubCategoryRow> subCategories(Long categoryId) {
        String category = categoryName(categoryId);
        return db.sql("""
                select s.id, s.category_id, s.name, count(p.id)
                from sub_categories s left join products p on p.category = :category and lower(p.sub_category) = lower(s.name)
                where s.category_id = :id group by s.id order by lower(s.name)""")
                .param("category", category).param("id", categoryId)
                .query((rs, n) -> new SubCategoryRow(rs.getLong(1), rs.getLong(2), rs.getString(3), rs.getLong(4))).list();
    }

    public SubCategoryRow addSubCategory(Long categoryId, String rawName) {
        String category = categoryName(categoryId);
        String name = validSubCategoryName(rawName, categoryId, category, null);
        try {
            Long id = db.sql("insert into sub_categories(category_id,name) values(:id,:name) returning id")
                    .param("id", categoryId).param("name", name).query(Long.class).single();
            return new SubCategoryRow(id, categoryId, name, 0);
        } catch (DuplicateKeyException e) {
            throw ApiException.conflict("SUB_CATEGORY_EXISTS", "\"" + category + "\" already has a sub-category named \"" + name + "\"");
        }
    }

    @Transactional
    public SubCategoryRow renameSubCategory(Long id, String rawName) {
        SubCategoryRow sub = subCategory(id);
        String category = categoryName(sub.categoryId());
        String name = validSubCategoryName(rawName, sub.categoryId(), category, id);
        db.sql("update sub_categories set name=:name where id=:id").param("name", name).param("id", id).update();
        db.sql("update products set sub_category=:name where category=:category and lower(sub_category)=lower(:old)")
                .param("name", name).param("category", category).param("old", sub.name()).update();
        return subCategory(id);
    }

    /** A sub-category that products still use can only be deleted by moving them to another one of the same category. */
    @Transactional
    public void deleteSubCategory(Long id, Long moveToId) {
        SubCategoryRow sub = subCategory(id);
        if (sub.productCount() > 0) {
            String category = categoryName(sub.categoryId());
            if (moveToId == null) {
                throw ApiException.conflict("SUB_CATEGORY_IN_USE", "\"" + sub.name() + "\" still has " + sub.productCount()
                        + (sub.productCount() == 1 ? " product" : " products") + ". Choose a sub-category to move them to before deleting it.");
            }
            if (moveToId.equals(id)) {
                throw ApiException.badRequest("SAME_SUB_CATEGORY", "Choose a different sub-category to move the products to");
            }
            SubCategoryRow target = subCategory(moveToId);
            if (!target.categoryId().equals(sub.categoryId())) {
                throw ApiException.badRequest("OTHER_CATEGORY", "Products can only move to a sub-category of \"" + category + "\"");
            }
            db.sql("update products set sub_category=:target where category=:category and lower(sub_category)=lower(:old)")
                    .param("target", target.name()).param("category", category).param("old", sub.name()).update();
        }
        db.sql("delete from sub_categories where id=:id").param("id", id).update();
    }

    public String requireSubCategory(String category, String name) {
        String wanted = name == null ? "" : name.trim();
        return db.sql("select s.name from sub_categories s join categories c on c.id = s.category_id"
                        + " where c.name=:category and lower(s.name)=lower(:name)")
                .param("category", category).param("name", wanted).query(String.class).optional()
                .orElseThrow(() -> ApiException.badRequest("UNKNOWN_SUB_CATEGORY", "\"" + wanted + "\" is not a sub-category of \""
                        + category + "\". Add it on the Categories page first."));
    }

    private SubCategoryRow subCategory(Long id) {
        Long categoryId = db.sql("select category_id from sub_categories where id=:id").param("id", id).query(Long.class).optional()
                .orElseThrow(() -> ApiException.notFound("Sub-category not found"));
        return subCategories(categoryId).stream().filter(s -> s.id().equals(id)).findFirst().orElseThrow();
    }

    private String validSubCategoryName(String raw, Long categoryId, String category, Long exceptId) {
        String name = cleanName(raw, "Sub-category");
        db.sql("select name from sub_categories where category_id=:category and lower(name)=lower(:name) and id<>:id")
                .param("category", categoryId).param("name", name).param("id", exceptId == null ? -1L : exceptId)
                .query(String.class).optional()
                .ifPresent(existing -> {
                    throw ApiException.conflict("SUB_CATEGORY_EXISTS", "\"" + category + "\" already has a sub-category named \"" + existing + "\"");
                });
        return name;
    }

    /** Trims and collapses spaces, then checks length and characters. */
    private static String cleanName(String raw, String label) {
        String name = raw == null ? "" : raw.trim().replaceAll("\\s+", " ");
        if (name.isEmpty()) throw ApiException.badRequest("INVALID_NAME", label + " name is required");
        if (name.length() > 40) throw ApiException.badRequest("INVALID_NAME", label + " name must be 40 characters or fewer");
        if (!CATEGORY_NAME.matcher(name).matches()) {
            throw ApiException.badRequest("INVALID_NAME", label + " name may only contain letters, numbers, spaces, & ' and -");
        }
        return name;
    }

    /** Valid, case-insensitively unique category name. */
    private String validCategoryName(String raw, Long exceptId) {
        String name = cleanName(raw, "Category");
        db.sql("select name from categories where lower(name)=lower(:name) and id<>:id")
                .param("name", name).param("id", exceptId == null ? -1L : exceptId).query(String.class).optional()
                .ifPresent(existing -> { throw categoryExists(existing); });
        return name;
    }

    private static final java.util.regex.Pattern CATEGORY_NAME = java.util.regex.Pattern.compile("^[\\p{L}\\p{N}][\\p{L}\\p{N} &'-]*$");

    private static ApiException categoryExists(String name) {
        return ApiException.conflict("CATEGORY_EXISTS", "A category named \"" + name + "\" already exists");
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
