package com.forever.foreverapi.service.serviceImpl;

import com.forever.foreverapi.service.ProductService;
import com.forever.foreverapi.service.CommerceService;

import com.forever.foreverapi.common.response.PageResponse;
import com.forever.foreverapi.client.minio.StorageService;
import com.forever.foreverapi.exception.ApiException;
import com.forever.foreverapi.model.dto.ProductDtos.FilterOptions;
import com.forever.foreverapi.model.dto.ProductDtos.ProductForm;
import com.forever.foreverapi.model.dto.ProductDtos.ProductResponse;
import com.forever.foreverapi.mapper.ProductMapper;
import com.forever.foreverapi.model.entity.Product;
import com.forever.foreverapi.repository.ProductRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@Service
public class ProductServiceImpl implements ProductService {

    public static final List<String> SORT_OPTIONS = List.of("relevant", "price_asc", "price_desc", "newest");
    private static final int MAX_IMAGES = 4;

    private final ProductRepository repo;
    private final ProductMapper mapper;
    private final StorageService storage;
    private final CommerceService commerce;

    public ProductServiceImpl(ProductRepository repo, ProductMapper mapper, StorageService storage, CommerceService commerce) {
        this.repo = repo;
        this.mapper = mapper;
        this.storage = storage;
        this.commerce = commerce;
    }

    @Transactional(readOnly = true)
    public PageResponse<ProductResponse> search(String q, List<String> categories, List<String> subCategories,
                                                String sort, int page, int size, boolean includeInactive) {
        Sort order = switch (sort == null ? "relevant" : sort) {
            case "price_asc" -> Sort.by("price").ascending().and(Sort.by("id"));
            case "price_desc" -> Sort.by("price").descending().and(Sort.by("id"));
            case "newest" -> Sort.by("createdAt").descending().and(Sort.by("id"));
            default -> Sort.by("id");
        };
        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100), order);
        Specification<Product> spec = (root, query, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (!includeInactive) {
                ps.add(cb.isTrue(root.get("active")));
            }
            if (q != null && !q.isBlank()) {
                ps.add(cb.like(cb.lower(root.get("name")), "%" + q.trim().toLowerCase(Locale.ROOT) + "%"));
            }
            if (categories != null && !categories.isEmpty()) {
                ps.add(root.get("category").in(categories));
            }
            if (subCategories != null && !subCategories.isEmpty()) {
                ps.add(root.get("subCategory").in(subCategories));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
        return PageResponse.of(repo.findAll(spec, pageable), mapper::toResponse);
    }

    @Transactional(readOnly = true)
    public ProductResponse get(Long id) {
        return mapper.toResponse(repo.findByIdAndActiveTrue(id).orElseThrow(() -> ApiException.notFound("Product not found")));
    }

    /** Admin view: also returns products that are hidden from the shop. */
    @Transactional(readOnly = true)
    public ProductResponse getForAdmin(Long id) {
        return mapper.toResponse(repo.findById(id).orElseThrow(() -> ApiException.notFound("Product not found")));
    }

    @Transactional(readOnly = true)
    public List<ProductResponse> latest(int limit) {
        return repo.findByActiveTrueOrderByCreatedAtDesc(PageRequest.of(0, clamp(limit))).stream()
                .map(mapper::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<ProductResponse> bestsellers(int limit) {
        return repo.findByActiveTrueAndBestsellerTrueOrderByCreatedAtDesc(PageRequest.of(0, clamp(limit))).stream()
                .map(mapper::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<ProductResponse> related(Long id, int limit) {
        Product p = repo.findByIdAndActiveTrue(id).orElseThrow(() -> ApiException.notFound("Product not found"));
        return repo.findByActiveTrueAndCategoryAndSubCategoryAndIdNotOrderByCreatedAtDesc(
                        p.getCategory(), p.getSubCategory(), id, PageRequest.of(0, clamp(limit))).stream()
                .map(mapper::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public FilterOptions filters() {
        return new FilterOptions(repo.distinctCategories(), repo.distinctSubCategories(), SORT_OPTIONS);
    }

    @Transactional
    public ProductResponse create(ProductForm form) {
        Product p = new Product();
        apply(p, form);
        replaceAll(p.getImages(), uploadAll(form.images()));
        if (p.getImages().isEmpty()) {
            throw ApiException.badRequest("IMAGE_REQUIRED", "At least one image is required");
        }
        Product saved = repo.save(p);
        commerce.syncInventory(saved.getId(), saved.getSizes());
        return mapper.toResponse(saved);
    }

    @Transactional
    public ProductResponse update(Long id, ProductForm form) {
        Product p = repo.findById(id).orElseThrow(() -> ApiException.notFound("Product not found"));
        apply(p, form);
        List<String> uploaded = uploadAll(form.images());
        if (!uploaded.isEmpty()) {
            List<String> old = new ArrayList<>(p.getImages());
            replaceAll(p.getImages(), uploaded);
            repo.save(p);
            old.stream().filter(k -> k.startsWith("products/")).forEach(storage::delete); // seed images ("seed/") are shared
        }
        Product saved = repo.save(p);
        commerce.syncInventory(saved.getId(), saved.getSizes());
        return mapper.toResponse(saved);
    }

    @Transactional
    public ProductResponse setActive(Long id, boolean active) {
        Product p = repo.findById(id).orElseThrow(() -> ApiException.notFound("Product not found"));
        p.setActive(active);
        return mapper.toResponse(p);
    }

    /** Soft delete: past orders keep referencing the product. */
    @Transactional
    public void delete(Long id) {
        setActive(id, false);
    }

    private void apply(Product p, ProductForm f) {
        p.setName(f.name().trim());
        p.setDescription(f.description().trim());
        p.setPrice(f.price());
        p.setCategory(commerce.requireCategory(f.category()));
        p.setSubCategory(commerce.requireSubCategory(p.getCategory(), f.subCategory()));
        p.setBestseller(Boolean.TRUE.equals(f.bestseller()));
        List<String> sizes = f.sizes().stream().flatMap(s -> java.util.Arrays.stream(s.split(",")))
                .map(String::trim).filter(s -> !s.isEmpty()).distinct().toList();
        if (sizes.isEmpty()) {
            throw ApiException.badRequest("SIZES_REQUIRED", "At least one size is required");
        }
        replaceAll(p.getSizes(), sizes);
    }

    /**
     * Mutates a managed collection in place. Assigning a new (e.g. immutable `Stream.toList()`) list to a
     * persistent entity makes Hibernate try to clear it during merge and fail.
     */
    private static void replaceAll(List<String> target, List<String> values) {
        target.clear();
        target.addAll(values);
    }

    private List<String> uploadAll(List<MultipartFile> files) {
        if (files == null) {
            return new ArrayList<>();
        }
        List<MultipartFile> real = files.stream().filter(f -> f != null && !f.isEmpty()).toList();
        if (real.size() > MAX_IMAGES) {
            throw ApiException.badRequest("TOO_MANY_IMAGES", "A product can have at most " + MAX_IMAGES + " images");
        }
        return new ArrayList<>(real.stream().map(f -> storage.uploadImage(f, "products")).toList());
    }

    private static int clamp(int limit) {
        return Math.min(Math.max(limit, 1), 50);
    }
}
