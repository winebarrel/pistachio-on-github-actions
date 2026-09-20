-- public.comment_count(bigint)
CREATE OR REPLACE FUNCTION public.comment_count(post bigint)
    RETURNS bigint
    LANGUAGE plpgsql
    STABLE
    AS $$
DECLARE
    n bigint;
BEGIN
    SELECT count(*) INTO n FROM comments WHERE post_id = post;
    RETURN n;
END;
$$;
