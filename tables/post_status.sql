-- public.post_status
CREATE TYPE public.post_status AS ENUM (
    'draft',
    'published',
    'archived',
    'pinned'
);
