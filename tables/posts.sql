-- public.posts
CREATE TABLE public.posts (
    id bigserial NOT NULL,
    author_id bigint NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    status post_status DEFAULT 'draft'::post_status NOT NULL,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT posts_pkey PRIMARY KEY (id),
    CONSTRAINT posts_check CHECK (status <> 'published'::post_status OR published_at IS NOT NULL)
);
CREATE INDEX posts_author_id_idx ON public.posts USING btree (author_id);
CREATE INDEX posts_created_idx ON public.posts USING btree (created_at DESC);
CREATE INDEX posts_published_idx ON public.posts USING btree (published_at DESC) WHERE (status = 'published'::post_status);

ALTER TABLE ONLY public.posts ADD CONSTRAINT posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY posts_modifiable ON public.posts FOR UPDATE USING ((author_id = (current_setting('app.user_id'::text, true))::bigint));
CREATE POLICY posts_visible ON public.posts FOR SELECT USING (((status = ANY (ARRAY['published'::post_status, 'pinned'::post_status])) OR (author_id = (current_setting('app.user_id'::text, true))::bigint)));

CREATE TRIGGER posts_set_updated_at BEFORE UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TABLE public.posts IS 'Blog posts';
COMMENT ON COLUMN public.posts.status IS 'draft -> published -> archived, or pinned';
