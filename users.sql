-- public.users
CREATE TABLE public.users (
    id bigserial NOT NULL,
    email email_address NOT NULL,
    display_name text NOT NULL,
    links social_links,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT users_pkey PRIMARY KEY (id),
    CONSTRAINT users_email_key UNIQUE (email)
);
