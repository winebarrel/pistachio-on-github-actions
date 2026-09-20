-- public.post_tags
CREATE TABLE public.post_tags (
    post_id bigint NOT NULL,
    tag_id bigint NOT NULL,
    CONSTRAINT post_tags_pkey PRIMARY KEY (post_id, tag_id)
);

ALTER TABLE ONLY public.post_tags ADD CONSTRAINT post_tags_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.post_tags ADD CONSTRAINT post_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE;
