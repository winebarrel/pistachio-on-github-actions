-- public.post_views
CREATE TABLE public.post_views (
    post_id bigint NOT NULL,
    viewed_on date NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    CONSTRAINT post_views_pkey PRIMARY KEY (viewed_on, post_id)
)
PARTITION BY RANGE (viewed_on);
