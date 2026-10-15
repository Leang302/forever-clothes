-- Managed sub-categories, each belonging to one category. Products keep the sub-category name in
-- products.sub_category; the API only accepts names that exist under the product's category.
CREATE TABLE sub_categories (
    id          BIGSERIAL PRIMARY KEY,
    category_id BIGINT      NOT NULL REFERENCES categories (id) ON DELETE CASCADE,
    name        VARCHAR(40) NOT NULL
);
CREATE UNIQUE INDEX uq_sub_categories_category_name ON sub_categories (category_id, lower(name));

INSERT INTO sub_categories (category_id, name)
SELECT DISTINCT c.id, p.sub_category FROM products p JOIN categories c ON c.name = p.category
ON CONFLICT DO NOTHING;
