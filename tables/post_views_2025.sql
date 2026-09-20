-- public.post_views_2025
CREATE TABLE public.post_views_2025 PARTITION OF public.post_views FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
