package com.forever.foreverapi.repository;

import com.forever.foreverapi.model.entity.Product;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface ProductRepository extends JpaRepository<Product, Long>, JpaSpecificationExecutor<Product> {

    Optional<Product> findByIdAndActiveTrue(Long id);

    long countByActive(boolean active);

    List<Product> findByActiveTrueOrderByCreatedAtDesc(Pageable pageable);

    List<Product> findByActiveTrueAndBestsellerTrueOrderByCreatedAtDesc(Pageable pageable);

    List<Product> findByActiveTrueAndCategoryAndSubCategoryAndIdNotOrderByCreatedAtDesc(
            String category, String subCategory, Long id, Pageable pageable);

    @Query("select distinct p.category from Product p where p.active = true order by p.category")
    List<String> distinctCategories();

    @Query("select distinct p.subCategory from Product p where p.active = true order by p.subCategory")
    List<String> distinctSubCategories();
}
