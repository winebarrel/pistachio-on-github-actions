-- public.post_ref_seq
CREATE SEQUENCE public.post_ref_seq
    AS bigint
    START WITH 1000
    INCREMENT BY 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;
