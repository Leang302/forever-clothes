package com.forever.foreverapi.config;

import com.forever.foreverapi.client.minio.StorageService;
import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.service.AuthService;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.ProductRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

import java.io.InputStream;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** On first start: creates the admin account and loads the web app's catalogue + images into PostgreSQL/MinIO. */
@Slf4j
@Component
public class DataSeeder implements ApplicationRunner {

    private final AppProperties props;
    private final AuthService auth;
    private final ProductRepository products;
    private final StorageService storage;
    private final JsonMapper json;
    private final JdbcClient db;

    public DataSeeder(AppProperties props, AuthService auth, ProductRepository products, StorageService storage,
                      JsonMapper json, JdbcClient db) {
        this.props = props;
        this.auth = auth;
        this.products = products;
        this.storage = storage;
        this.json = json;
        this.db = db;
    }

    record SeedProduct(String name, String description, BigDecimal price, String category, String subCategory,
                       List<String> sizes, List<String> images, boolean bestseller, long createdAt) {
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        var seed = props.seed();
        if (!seed.enabled()) {
            return;
        }
        auth.createAdminIfMissing(seed.adminEmail(), seed.adminPassword());

        if (products.count() > 0) {
            return;
        }
        List<SeedProduct> items;
        try (InputStream in = new ClassPathResource("seed/products.json").getInputStream()) {
            items = json.readValue(in, new TypeReference<List<SeedProduct>>() {
            });
        }
        Set<String> uploaded = new HashSet<>();
        List<Product> batch = new ArrayList<>();
        for (SeedProduct s : items) {
            Product p = new Product();
            p.setName(s.name());
            p.setDescription(s.description());
            p.setPrice(s.price());
            p.setCategory(s.category());
            p.setSubCategory(s.subCategory());
            p.setSizes(s.sizes());
            p.setBestseller(s.bestseller());
            p.setCreatedAt(Instant.ofEpochMilli(s.createdAt()));
            p.setImages(s.images().stream().map(f -> "seed/" + f).toList());
            for (String file : s.images()) {
                if (uploaded.add(file)) {
                    uploadSeedImage(file);
                }
            }
            batch.add(p);
        }
        products.saveAll(batch); // one transaction: all or nothing
        // V3 backfills stock and categories from existing products, but on a fresh database it runs before
        // this seeder, so repeat that backfill here.
        db.sql("insert into product_inventory(product_id,size,stock) select product_id,size,20 from product_sizes"
                + " on conflict do nothing").update();
        db.sql("insert into categories(name) select distinct category from products on conflict do nothing").update();
        db.sql("insert into sub_categories(category_id,name) select distinct c.id, p.sub_category from products p"
                + " join categories c on c.name = p.category on conflict do nothing").update();
        log.info("Seeded {} products and {} images into MinIO", items.size(), uploaded.size());
    }

    private void uploadSeedImage(String file) throws Exception {
        String key = "seed/" + file;
        if (storage.exists(key)) {
            return;
        }
        ClassPathResource res = new ClassPathResource("seed/images/" + file);
        try (InputStream in = res.getInputStream()) {
            storage.put(key, in, res.contentLength(), "image/png");
        }
    }
}
