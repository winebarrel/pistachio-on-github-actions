-- public.tag_usage
CREATE MATERIALIZED VIEW public.tag_usage AS
SELECT t.id AS tag_id,
    t.name,
    count(pt.post_id) AS post_count
   FROM tags t
     LEFT JOIN post_tags pt ON pt.tag_id = t.id
  GROUP BY t.id, t.name;
CREATE INDEX tag_usage_post_count_idx ON public.tag_usage USING btree (post_count DESC);
CREATE UNIQUE INDEX tag_usage_tag_id_idx ON public.tag_usage USING btree (tag_id);
