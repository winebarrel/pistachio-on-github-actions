-- public.refresh_tag_usage()
CREATE OR REPLACE PROCEDURE public.refresh_tag_usage()
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW tag_usage;
END;
$$;
