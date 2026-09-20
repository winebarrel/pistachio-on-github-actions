-- public.comments
CREATE TABLE public.comments (
    id bigserial NOT NULL,
    post_id bigint NOT NULL,
    author_id bigint NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT comments_pkey PRIMARY KEY (id)
);
CREATE INDEX comments_post_id_idx ON public.comments USING btree (post_id);

ALTER TABLE ONLY public.comments ADD CONSTRAINT comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.comments ADD CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;

CREATE TRIGGER comments_notify AFTER INSERT ON comments FOR EACH ROW EXECUTE FUNCTION notify_comment();
ALTER TABLE public.comments DISABLE TRIGGER comments_notify;
CREATE TRIGGER comments_set_updated_at BEFORE INSERT OR UPDATE ON comments FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TABLE public.comments IS 'Reader comments on a post';
