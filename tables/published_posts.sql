-- public.published_posts
CREATE OR REPLACE VIEW public.published_posts AS
SELECT p.id,
    p.title,
    p.body,
    p.published_at,
    u.display_name AS author,
    p.updated_at
   FROM posts p
     JOIN users u ON u.id = p.author_id
  WHERE p.status = 'published'::post_status;
