package com.forever.foreverapi.model.entity;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.BatchSize;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "products")
@Getter
@Setter
@NoArgsConstructor
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @Column(columnDefinition = "text")
    private String description;

    private BigDecimal price;

    private String category;

    @Column(name = "sub_category")
    private String subCategory;

    private boolean bestseller;

    private boolean active = true;

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();

    @ElementCollection
    @CollectionTable(name = "product_sizes", joinColumns = @JoinColumn(name = "product_id"))
    @OrderColumn(name = "position")
    @Column(name = "size")
    @BatchSize(size = 100)
    private List<String> sizes = new ArrayList<>();

    @ElementCollection
    @CollectionTable(name = "product_images", joinColumns = @JoinColumn(name = "product_id"))
    @OrderColumn(name = "position")
    @Column(name = "image_key")
    @BatchSize(size = 100)
    private List<String> images = new ArrayList<>();
}
