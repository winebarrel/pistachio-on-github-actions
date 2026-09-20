-- public.tags
CREATE TABLE public.tags (
    id bigserial NOT NULL,
    name text NOT NULL,
    CONSTRAINT tags_pkey PRIMARY KEY (id),
    CONSTRAINT tags_name_key UNIQUE (name)
);
