-- public.email_address
CREATE DOMAIN public.email_address AS text
    CONSTRAINT email_address_check CHECK ((VALUE ~ '^[^@]+@[^@]+\.[^@]+$'::text));
