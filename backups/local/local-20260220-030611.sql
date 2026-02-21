


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."group_role" AS ENUM (
    'owner',
    'member'
);


ALTER TYPE "public"."group_role" OWNER TO "postgres";


CREATE TYPE "public"."habit_type" AS ENUM (
    'binary',
    'dhikr'
);


ALTER TYPE "public"."habit_type" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_group_with_owner"("group_name" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_group_id uuid;
  v_user_id uuid := auth.uid();
  v_name text := trim(group_name);
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_name is null or v_name = '' then
    raise exception 'Group name is required';
  end if;

  insert into public.groups (owner_id, name)
  values (v_user_id, v_name)
  returning id into v_group_id;

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, v_user_id, 'owner')
  on conflict (group_id, user_id) do update
    set role = 'owner';

  return v_group_id;
end;
$$;


ALTER FUNCTION "public"."create_group_with_owner"("group_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.profiles (id)
  values (new.id);
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_group_member"("p_group_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1
    from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_group_member"("p_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_group_by_code"("invite_code" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_group_id uuid;
  v_user_id uuid := auth.uid();
  v_code text := upper(trim(invite_code));
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_code is null or v_code = '' then
    raise exception 'Invalid invite code';
  end if;

  select id into v_group_id
  from public.groups
  where upper(code) = v_code;

  if v_group_id is null then
    raise exception 'Invalid invite code';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, v_user_id, 'member')
  on conflict (group_id, user_id) do nothing;

  return v_group_id;
end;
$$;


ALTER FUNCTION "public"."join_group_by_code"("invite_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_nudge_day_utc"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.day := (new.created_at at time zone 'utc')::date;
  return new;
end;
$$;


ALTER FUNCTION "public"."set_nudge_day_utc"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."device_tokens" (
    "user_id" "uuid" NOT NULL,
    "platform" "text" NOT NULL,
    "token" "text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "device_tokens_platform_check" CHECK (("platform" = ANY (ARRAY['ios'::"text", 'android'::"text", 'web'::"text"])))
);


ALTER TABLE "public"."device_tokens" OWNER TO "postgres";


COMMENT ON TABLE "public"."device_tokens" IS 'FCM / APNs push notification tokens';



CREATE TABLE IF NOT EXISTS "public"."group_members" (
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."group_role" DEFAULT 'member'::"public"."group_role" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."group_members" OWNER TO "postgres";


COMMENT ON TABLE "public"."group_members" IS 'Maps users to groups with their role';



CREATE TABLE IF NOT EXISTS "public"."group_shared_habits" (
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "habit_id" "uuid" NOT NULL,
    "shared" boolean DEFAULT true NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."group_shared_habits" OWNER TO "postgres";


COMMENT ON TABLE "public"."group_shared_habits" IS 'Per-group, per-user habit sharing toggle';



CREATE TABLE IF NOT EXISTS "public"."groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "code" "text" DEFAULT "substr"("replace"(("gen_random_uuid"())::"text", '-'::"text", ''::"text"), 1, 8) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."groups" OWNER TO "postgres";


COMMENT ON TABLE "public"."groups" IS 'Accountability groups with shareable invite code';



CREATE TABLE IF NOT EXISTS "public"."habit_completions" (
    "user_id" "uuid" NOT NULL,
    "habit_id" "uuid" NOT NULL,
    "day_date" "date" NOT NULL,
    "value" integer DEFAULT 0 NOT NULL,
    "completed_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."habit_completions" OWNER TO "postgres";


COMMENT ON TABLE "public"."habit_completions" IS 'Daily completion records — one row per habit per day';



CREATE TABLE IF NOT EXISTS "public"."habits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "icon" "text",
    "type" "public"."habit_type" DEFAULT 'binary'::"public"."habit_type" NOT NULL,
    "target_count" integer,
    "schedule" "text" DEFAULT 'daily'::"text" NOT NULL,
    "weekdays" smallint[] DEFAULT '{}'::smallint[],
    "reminder_enabled" boolean DEFAULT false NOT NULL,
    "reminder_time" time without time zone,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "dhikr_target_required" CHECK ((("type" <> 'dhikr'::"public"."habit_type") OR (("target_count" IS NOT NULL) AND ("target_count" > 0)))),
    CONSTRAINT "habits_schedule_supported" CHECK (("schedule" = ANY (ARRAY['daily'::"text", 'weekly'::"text"]))),
    CONSTRAINT "reminder_requires_time" CHECK ((("reminder_enabled" = false) OR ("reminder_time" IS NOT NULL))),
    CONSTRAINT "weekdays_valid_range" CHECK ((("weekdays" IS NULL) OR ("weekdays" <@ ARRAY[(1)::smallint, (2)::smallint, (3)::smallint, (4)::smallint, (5)::smallint, (6)::smallint, (7)::smallint]))),
    CONSTRAINT "weekly_requires_weekdays" CHECK ((("schedule" <> 'weekly'::"text") OR (("weekdays" IS NOT NULL) AND (("array_length"("weekdays", 1) >= 1) AND ("array_length"("weekdays", 1) <= 7)))))
);


ALTER TABLE "public"."habits" OWNER TO "postgres";


COMMENT ON TABLE "public"."habits" IS 'User-defined habits (binary or dhikr counter)';



CREATE TABLE IF NOT EXISTS "public"."nudges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "from_user_id" "uuid" NOT NULL,
    "to_user_id" "uuid" NOT NULL,
    "habit_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "day" "date" NOT NULL
);


ALTER TABLE "public"."nudges" OWNER TO "postgres";


COMMENT ON TABLE "public"."nudges" IS 'Remind-a-friend nudge log (rate-limited at DB level)';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" "text",
    "is_admin" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles" IS 'User profile linked 1-to-1 with auth.users';



CREATE TABLE IF NOT EXISTS "public"."quotes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "locale" "text" DEFAULT 'en'::"text" NOT NULL,
    "text" "text" NOT NULL,
    "source" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "quotes_locale_check" CHECK (("locale" = ANY (ARRAY['en'::"text", 'kk'::"text", 'ru'::"text"])))
);


ALTER TABLE "public"."quotes" OWNER TO "postgres";


COMMENT ON TABLE "public"."quotes" IS 'Curated inspirational quotes';



CREATE TABLE IF NOT EXISTS "public"."saved_quotes" (
    "user_id" "uuid" NOT NULL,
    "quote_id" "uuid" NOT NULL,
    "saved_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."saved_quotes" OWNER TO "postgres";


COMMENT ON TABLE "public"."saved_quotes" IS 'User bookmarked quotes';



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("user_id", "token");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_pkey" PRIMARY KEY ("group_id", "user_id");



ALTER TABLE ONLY "public"."group_shared_habits"
    ADD CONSTRAINT "group_shared_habits_pkey" PRIMARY KEY ("group_id", "user_id", "habit_id");



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."habit_completions"
    ADD CONSTRAINT "habit_completions_pkey" PRIMARY KEY ("user_id", "habit_id", "day_date");



ALTER TABLE ONLY "public"."habits"
    ADD CONSTRAINT "habits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nudges"
    ADD CONSTRAINT "nudges_one_per_day" UNIQUE ("group_id", "from_user_id", "to_user_id", "habit_id", "day");



ALTER TABLE ONLY "public"."nudges"
    ADD CONSTRAINT "nudges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."quotes"
    ADD CONSTRAINT "quotes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."saved_quotes"
    ADD CONSTRAINT "saved_quotes_pkey" PRIMARY KEY ("user_id", "quote_id");



CREATE INDEX "device_tokens_user_idx" ON "public"."device_tokens" USING "btree" ("user_id");



CREATE INDEX "group_members_group_idx" ON "public"."group_members" USING "btree" ("group_id");



CREATE INDEX "group_members_user_group_idx" ON "public"."group_members" USING "btree" ("user_id", "group_id");



CREATE INDEX "group_members_user_idx" ON "public"."group_members" USING "btree" ("user_id");



CREATE INDEX "group_members_user_updated_idx" ON "public"."group_members" USING "btree" ("user_id", "updated_at" DESC);



CREATE INDEX "group_shared_habits_group_shared_user_habit_idx" ON "public"."group_shared_habits" USING "btree" ("group_id", "shared", "user_id", "habit_id");



CREATE INDEX "group_shared_habits_group_user_idx" ON "public"."group_shared_habits" USING "btree" ("group_id", "user_id");



CREATE INDEX "group_shared_habits_habit_idx" ON "public"."group_shared_habits" USING "btree" ("habit_id");



CREATE INDEX "group_shared_habits_user_habit_group_idx" ON "public"."group_shared_habits" USING "btree" ("user_id", "habit_id", "group_id");



CREATE INDEX "habit_completions_habit_date_idx" ON "public"."habit_completions" USING "btree" ("habit_id", "day_date" DESC);



CREATE INDEX "habit_completions_user_date_idx" ON "public"."habit_completions" USING "btree" ("user_id", "day_date" DESC);



CREATE INDEX "habit_completions_user_habit_updated_idx" ON "public"."habit_completions" USING "btree" ("user_id", "habit_id", "updated_at" DESC);



CREATE INDEX "habits_user_archived_sort_idx" ON "public"."habits" USING "btree" ("user_id", "archived", "sort_order");



CREATE UNIQUE INDEX "habits_user_id_id_uidx" ON "public"."habits" USING "btree" ("user_id", "id");



CREATE INDEX "nudges_group_created_idx" ON "public"."nudges" USING "btree" ("group_id", "created_at" DESC);



CREATE INDEX "nudges_sender_day_idx" ON "public"."nudges" USING "btree" ("from_user_id", "day" DESC);



CREATE INDEX "nudges_to_user_day_idx" ON "public"."nudges" USING "btree" ("to_user_id", "day" DESC);



CREATE INDEX "quotes_locale_active_sort_idx" ON "public"."quotes" USING "btree" ("locale", "active", "sort_order");



CREATE INDEX "saved_quotes_user_idx" ON "public"."saved_quotes" USING "btree" ("user_id", "saved_at" DESC);



CREATE INDEX "saved_quotes_user_updated_idx" ON "public"."saved_quotes" USING "btree" ("user_id", "updated_at" DESC);



CREATE OR REPLACE TRIGGER "set_completions_updated_at" BEFORE UPDATE ON "public"."habit_completions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_device_tokens_updated_at" BEFORE UPDATE ON "public"."device_tokens" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_group_members_updated_at" BEFORE UPDATE ON "public"."group_members" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_groups_updated_at" BEFORE UPDATE ON "public"."groups" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_habits_updated_at" BEFORE UPDATE ON "public"."habits" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_quotes_updated_at" BEFORE UPDATE ON "public"."quotes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_saved_quotes_updated_at" BEFORE UPDATE ON "public"."saved_quotes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_shared_habits_updated_at" BEFORE UPDATE ON "public"."group_shared_habits" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_nudges_set_day_utc" BEFORE INSERT ON "public"."nudges" FOR EACH ROW EXECUTE FUNCTION "public"."set_nudge_day_utc"();



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_shared_habits"
    ADD CONSTRAINT "group_shared_habits_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_shared_habits"
    ADD CONSTRAINT "group_shared_habits_habit_id_fkey" FOREIGN KEY ("habit_id") REFERENCES "public"."habits"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_shared_habits"
    ADD CONSTRAINT "group_shared_habits_habit_owner_fk" FOREIGN KEY ("user_id", "habit_id") REFERENCES "public"."habits"("user_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_shared_habits"
    ADD CONSTRAINT "group_shared_habits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."habit_completions"
    ADD CONSTRAINT "habit_completions_habit_id_fkey" FOREIGN KEY ("habit_id") REFERENCES "public"."habits"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."habit_completions"
    ADD CONSTRAINT "habit_completions_habit_owner_fk" FOREIGN KEY ("user_id", "habit_id") REFERENCES "public"."habits"("user_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."habit_completions"
    ADD CONSTRAINT "habit_completions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."habits"
    ADD CONSTRAINT "habits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nudges"
    ADD CONSTRAINT "nudges_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nudges"
    ADD CONSTRAINT "nudges_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nudges"
    ADD CONSTRAINT "nudges_habit_id_fkey" FOREIGN KEY ("habit_id") REFERENCES "public"."habits"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nudges"
    ADD CONSTRAINT "nudges_to_user_id_fkey" FOREIGN KEY ("to_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."saved_quotes"
    ADD CONSTRAINT "saved_quotes_quote_id_fkey" FOREIGN KEY ("quote_id") REFERENCES "public"."quotes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."saved_quotes"
    ADD CONSTRAINT "saved_quotes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can manage quotes" ON "public"."quotes" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."is_admin" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."is_admin" = true)))));



CREATE POLICY "Anyone can read active quotes" ON "public"."quotes" FOR SELECT USING (("active" = true));



CREATE POLICY "Authenticated users can create groups" ON "public"."groups" FOR INSERT WITH CHECK (("auth"."uid"() = "owner_id"));



CREATE POLICY "Group members can create nudges for shared habits" ON "public"."nudges" FOR INSERT WITH CHECK ((("from_user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."group_members" "gm"
  WHERE (("gm"."group_id" = "gm"."group_id") AND ("gm"."user_id" = "auth"."uid"())))) AND (EXISTS ( SELECT 1
   FROM "public"."group_members" "gm"
  WHERE (("gm"."group_id" = "gm"."group_id") AND ("gm"."user_id" = "nudges"."to_user_id")))) AND (EXISTS ( SELECT 1
   FROM "public"."group_shared_habits" "gsh"
  WHERE (("gsh"."group_id" = "gsh"."group_id") AND ("gsh"."user_id" = "nudges"."to_user_id") AND ("gsh"."habit_id" = "gsh"."habit_id") AND ("gsh"."shared" = true))))));



CREATE POLICY "Members can read their groups" ON "public"."groups" FOR SELECT USING (("id" IN ( SELECT "group_members"."group_id"
   FROM "public"."group_members"
  WHERE ("group_members"."user_id" = "auth"."uid"()))));



CREATE POLICY "Members can see fellow members" ON "public"."group_members" FOR SELECT USING ("public"."is_group_member"("group_id"));



CREATE POLICY "Members can see shared habits in their groups" ON "public"."group_shared_habits" FOR SELECT USING (("group_id" IN ( SELECT "group_members"."group_id"
   FROM "public"."group_members"
  WHERE ("group_members"."user_id" = "auth"."uid"()))));



CREATE POLICY "Owner can delete group" ON "public"."groups" FOR DELETE USING (("auth"."uid"() = "owner_id"));



CREATE POLICY "Owner can update group" ON "public"."groups" FOR UPDATE USING (("auth"."uid"() = "owner_id")) WITH CHECK (("auth"."uid"() = "owner_id"));



CREATE POLICY "Owner or self can remove membership" ON "public"."group_members" FOR DELETE USING ((("auth"."uid"() IN ( SELECT "groups"."owner_id"
   FROM "public"."groups"
  WHERE ("groups"."id" = "group_members"."group_id"))) OR ("auth"."uid"() = "user_id")));



CREATE POLICY "Recipient or sender can read nudges" ON "public"."nudges" FOR SELECT USING ((("auth"."uid"() = "to_user_id") OR ("auth"."uid"() = "from_user_id")));



CREATE POLICY "Users can delete own completions" ON "public"."habit_completions" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own habits" ON "public"."habits" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own tokens" ON "public"."device_tokens" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own completions for their habits" ON "public"."habit_completions" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."habits" "h"
  WHERE (("h"."id" = "habit_completions"."habit_id") AND ("h"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Users can insert own habits" ON "public"."habits" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can join groups (insert themselves)" ON "public"."group_members" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read own saved quotes" ON "public"."saved_quotes" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read own tokens" ON "public"."device_tokens" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can register tokens" ON "public"."device_tokens" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can save quotes" ON "public"."saved_quotes" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can share own habits" ON "public"."group_shared_habits" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can unsave quotes" ON "public"."saved_quotes" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can unshare own habits" ON "public"."group_shared_habits" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own completions for their habits" ON "public"."habit_completions" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."habits" "h"
  WHERE (("h"."id" = "habit_completions"."habit_id") AND ("h"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Users can update own habits" ON "public"."habits" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can update own sharing" ON "public"."group_shared_habits" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own tokens" ON "public"."device_tokens" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own completions or shared completions in groups" ON "public"."habit_completions" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."group_shared_habits" "gsh"
     JOIN "public"."group_members" "gm" ON (("gm"."group_id" = "gsh"."group_id")))
  WHERE (("gsh"."habit_id" = "habit_completions"."habit_id") AND ("gsh"."user_id" = "habit_completions"."user_id") AND ("gsh"."shared" = true) AND ("gm"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Users can view own habits or habits shared with their groups" ON "public"."habits" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."group_shared_habits" "gsh"
     JOIN "public"."group_members" "gm" ON (("gm"."group_id" = "gsh"."group_id")))
  WHERE (("gsh"."habit_id" = "habits"."id") AND ("gsh"."user_id" = "habits"."user_id") AND ("gsh"."shared" = true) AND ("gm"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Users can view own profile or group members" ON "public"."profiles" FOR SELECT USING ((("id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."group_members" "gm_me"
     JOIN "public"."group_members" "gm_other" ON (("gm_me"."group_id" = "gm_other"."group_id")))
  WHERE (("gm_me"."user_id" = "auth"."uid"()) AND ("gm_other"."user_id" = "profiles"."id"))))));



ALTER TABLE "public"."device_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."group_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."group_shared_habits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."habit_completions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."habits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."nudges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."quotes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."saved_quotes" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";





GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";































































































































































REVOKE ALL ON FUNCTION "public"."create_group_with_owner"("group_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_group_with_owner"("group_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_group_with_owner"("group_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_group_with_owner"("group_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_group_member"("p_group_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_group_member"("p_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_group_member"("p_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_group_member"("p_group_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."join_group_by_code"("invite_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."join_group_by_code"("invite_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."join_group_by_code"("invite_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_group_by_code"("invite_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_nudge_day_utc"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_nudge_day_utc"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_nudge_day_utc"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";


















GRANT ALL ON TABLE "public"."device_tokens" TO "anon";
GRANT ALL ON TABLE "public"."device_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."device_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."group_members" TO "anon";
GRANT ALL ON TABLE "public"."group_members" TO "authenticated";
GRANT ALL ON TABLE "public"."group_members" TO "service_role";



GRANT ALL ON TABLE "public"."group_shared_habits" TO "anon";
GRANT ALL ON TABLE "public"."group_shared_habits" TO "authenticated";
GRANT ALL ON TABLE "public"."group_shared_habits" TO "service_role";



GRANT ALL ON TABLE "public"."groups" TO "anon";
GRANT ALL ON TABLE "public"."groups" TO "authenticated";
GRANT ALL ON TABLE "public"."groups" TO "service_role";



GRANT ALL ON TABLE "public"."habit_completions" TO "anon";
GRANT ALL ON TABLE "public"."habit_completions" TO "authenticated";
GRANT ALL ON TABLE "public"."habit_completions" TO "service_role";



GRANT ALL ON TABLE "public"."habits" TO "anon";
GRANT ALL ON TABLE "public"."habits" TO "authenticated";
GRANT ALL ON TABLE "public"."habits" TO "service_role";



GRANT ALL ON TABLE "public"."nudges" TO "anon";
GRANT ALL ON TABLE "public"."nudges" TO "authenticated";
GRANT ALL ON TABLE "public"."nudges" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."quotes" TO "anon";
GRANT ALL ON TABLE "public"."quotes" TO "authenticated";
GRANT ALL ON TABLE "public"."quotes" TO "service_role";



GRANT ALL ON TABLE "public"."saved_quotes" TO "anon";
GRANT ALL ON TABLE "public"."saved_quotes" TO "authenticated";
GRANT ALL ON TABLE "public"."saved_quotes" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































