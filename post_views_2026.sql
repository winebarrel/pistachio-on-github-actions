-- public.post_views_2026
CREATE TABLE public.post_views_2026 PARTITION OF public.post_views FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
