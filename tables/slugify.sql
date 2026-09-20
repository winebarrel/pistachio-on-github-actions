-- public.slugify(text)
CREATE OR REPLACE FUNCTION public.slugify(t text)
    RETURNS text
    LANGUAGE sql
    IMMUTABLE STRICT PARALLEL SAFE
    AS $$ SELECT trim(both '-' from regexp_replace(lower(t), '[^a-z0-9]+', '-', 'g')) $$;
COMMENT ON FUNCTION public.slugify(text) IS 'Tag name -> URL slug';
