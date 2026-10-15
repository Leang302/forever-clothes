-- Products must now use a managed category. Add a category row for any category products already use
-- (e.g. one deleted earlier, or products seeded after V3 ran on an empty database).
INSERT INTO categories (name)
SELECT DISTINCT p.category FROM products p
WHERE NOT EXISTS (SELECT 1 FROM categories c WHERE lower(c.name) = lower(p.category))
ON CONFLICT DO NOTHING;
