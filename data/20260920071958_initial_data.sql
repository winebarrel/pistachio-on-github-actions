-- Seed data for the demo blog.

INSERT INTO users (email, display_name, links) VALUES
    ('ada@example.com',  'Ada Lovelace', ROW('https://ada.example.com', 'ada')::social_links),
    ('alan@example.com', 'Alan Turing',  ROW('https://alan.example.com', 'alan')::social_links),
    ('grace@example.com', 'Grace Hopper', NULL);

INSERT INTO tags (name, slug) VALUES
    ('PostgreSQL', 'postgresql'),
    ('Schema Migration', 'schema-migration'),
    ('CI', 'ci');

INSERT INTO posts (author_id, title, body, status, published_at)
SELECT u.id, 'Declarative schema management', 'Describe the schema you want and let the tool work out the DDL.', 'published', now() - interval '7 days'
FROM users u WHERE u.email = 'ada@example.com';

INSERT INTO posts (author_id, title, body, status, published_at)
SELECT u.id, 'Running plan on every pull request', 'A diff you can read is worth more than a migration you cannot.', 'pinned', now() - interval '3 days'
FROM users u WHERE u.email = 'alan@example.com';

INSERT INTO posts (author_id, title, body, status)
SELECT u.id, 'Notes on partitioned tables', 'Still figuring out where the partition boundaries should go.', 'draft'
FROM users u WHERE u.email = 'grace@example.com';

INSERT INTO comments (post_id, author_id, body)
SELECT p.id, u.id, 'This is roughly how Terraform feels, but for DDL.'
FROM posts p, users u
WHERE p.title = 'Declarative schema management' AND u.email = 'alan@example.com';

INSERT INTO comments (post_id, author_id, body)
SELECT p.id, u.id, 'The skipped drops in the plan output are a nice touch.'
FROM posts p, users u
WHERE p.title = 'Declarative schema management' AND u.email = 'grace@example.com';

INSERT INTO post_tags (post_id, tag_id)
SELECT p.id, t.id
FROM posts p, tags t
WHERE (p.title = 'Declarative schema management' AND t.slug IN ('postgresql', 'schema-migration'))
   OR (p.title = 'Running plan on every pull request' AND t.slug IN ('ci', 'schema-migration'));

INSERT INTO post_schedules (post_id, during)
SELECT p.id, tstzrange('2026-01-01', '2026-06-30')
FROM posts p WHERE p.title = 'Declarative schema management';

INSERT INTO post_schedules (post_id, during)
SELECT p.id, tstzrange('2026-07-01', '2026-12-31')
FROM posts p WHERE p.title = 'Running plan on every pull request';

INSERT INTO post_views (post_id, viewed_on, views)
SELECT p.id, d::date, (random() * 100)::int
FROM posts p, generate_series('2025-12-28'::date, '2026-01-03'::date, interval '1 day') d
WHERE p.status <> 'draft';

REFRESH MATERIALIZED VIEW tag_usage;
