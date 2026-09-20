-- public.notify_comment()
CREATE OR REPLACE FUNCTION public.notify_comment()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM pg_notify('comments', NEW.post_id::text);
    RETURN NULL;
END;
$$;
