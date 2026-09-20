-- public.slugify(text)
CREATE OR REPLACE FUNCTION public.slugify(t text)
    RETURNS text
    LANGUAGE sql
    IMMUTABLE STRICT
    AS $$ SELECT lower(replace(t, ' ', '-')) $$;
COMMENT ON FUNCTION public.slugify(text) IS 'Tag name -> URL slug';
