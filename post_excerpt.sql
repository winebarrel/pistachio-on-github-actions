-- public.post_excerpt(text, integer)
CREATE OR REPLACE FUNCTION public.post_excerpt(body text, len integer DEFAULT 140)
    RETURNS text
    LANGUAGE sql
    IMMUTABLE
    AS $$ SELECT left(body, len) $$;
