-- public.post_schedules
CREATE TABLE public.post_schedules (
    id bigint GENERATED ALWAYS AS IDENTITY,
    post_id bigint NOT NULL,
    during tstzrange NOT NULL,
    CONSTRAINT post_schedules_pkey PRIMARY KEY (id),
    CONSTRAINT post_schedules_during_excl EXCLUDE USING gist (during WITH &&)
);

ALTER TABLE ONLY public.post_schedules ADD CONSTRAINT post_schedules_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;
