-- =====================================================================
-- Garaad database update 8: curriculum skills, school settings,
-- the teacher's class page and class competition
-- =====================================================================
-- Run once in Supabase: SQL Editor > New query > paste all > Run.
-- Run it after updates 1 to 7 (6 is the Arabic update). Safe to run again.
-- One transaction: if anything fails, nothing changes.
--
-- What it adds:
--   * The skill map: 55 maths and 41 English skills (M01–M55, E01–E41),
--     where each sits in Kenya CBE, England and Cambridge Primary, and
--     which game levels practise each skill.
--   * School settings: the school's curriculum (Garaad, Kenya CBE,
--     England or Cambridge), its currency for the money games, and which
--     curriculum class each of its classes is (e.g. KG2 = PP2). The
--     principal sets these under Manage school > Curriculum.
--   * Feature switches per school, set by the Garaad admin: new games,
--     the teacher's class page, and competition. All OFF until switched on,
--     so a school sees nothing new until then.
--   * A switch 'new_games' for families (Admin > New games).
--   * The teacher's class page: today at a glance, needs help, ready to
--     move up, the skills grid, this week against last week, and
--     "Set today's practice" (the topic the class practises today).
--   * Competition: class star goal, teams, weekly badges, and the
--     principal's class league. Effort counts, not only being right.
--
-- Nothing already saved is changed: results are read from the rounds and
-- sessions the app already saves.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------

create table if not exists public.skills (
  id        text primary key,                    -- M01 … M55, E01 … E41
  subject   text not null check (subject in ('maths','english')),
  strand    text not null,
  name      text not null,                       -- Garaad's own words
  builds_on text[] not null default '{}',
  sort      int not null default 0
);

create table if not exists public.curriculum_tags (
  skill_id    text not null references public.skills(id) on delete cascade,
  curriculum  text not null check (curriculum in ('kenya_cbe','england','cambridge')),
  class_label text not null,                     -- PP1, Grade 1, Year 1, Stage 1, Reception …
  ref         text not null,                     -- the curriculum's own code, e.g. 1.3c, 1Ni.04
  primary key (skill_id, curriculum, class_label, ref)
);

create table if not exists public.game_skills (
  game        text not null,                     -- game id in the app, e.g. addsub, bbonds
  skill_id    text not null references public.skills(id) on delete cascade,
  level_from  smallint not null default 1,
  level_to    smallint not null default 10,
  primary key (game, skill_id, level_from)
);

alter table public.schools add column if not exists curriculum text not null default 'garaad';
alter table public.schools add column if not exists currency   text;
alter table public.schools add column if not exists features   jsonb not null default '{}'::jsonb;
alter table public.schools drop constraint if exists schools_curriculum_check;
alter table public.schools add constraint schools_curriculum_check check (curriculum in ('garaad','kenya_cbe','england','cambridge'));
alter table public.schools drop constraint if exists schools_currency_check;
alter table public.schools add constraint schools_currency_check check (currency is null or currency in ('KES','USD','GBP','coins'));

alter table public.classes add column if not exists curriculum_class text;          -- e.g. PP2, Grade 1, Year 1, Stage 1
alter table public.classes add column if not exists options jsonb not null default '{}'::jsonb;   -- competition on/off, names on screen

create table if not exists public.class_practice (
  class_id  uuid not null references public.classes(id) on delete cascade,
  day       date not null,
  skills    text[] not null default '{}',
  games     text[] not null default '{}',
  set_by    uuid references public.teachers(id) on delete set null,
  set_at    timestamptz not null default now(),
  primary key (class_id, day)
);

create table if not exists public.class_teams (
  id        uuid primary key default gen_random_uuid(),
  class_id  uuid not null references public.classes(id) on delete cascade,
  name      text not null,
  colour    text not null,
  sort      smallint not null default 0
);
alter table public.children add column if not exists team_id uuid references public.class_teams(id) on delete set null;

create table if not exists public.class_goals (
  class_id      uuid not null references public.classes(id) on delete cascade,
  week_start    date not null,
  target_stars  int not null check (target_stars between 1 and 100000),
  primary key (class_id, week_start)
);

create index if not exists class_teams_class_idx on public.class_teams (class_id);
create index if not exists children_team_idx     on public.children (team_id);
create index if not exists rounds_child_played   on public.rounds (child_id, played_at);
create index if not exists sessions_child_started on public.sessions (child_id, started_at);

alter table public.skills          enable row level security;
alter table public.curriculum_tags enable row level security;
alter table public.game_skills     enable row level security;
alter table public.class_practice  enable row level security;
alter table public.class_teams     enable row level security;
alter table public.class_goals     enable row level security;
revoke all on public.skills, public.curriculum_tags, public.game_skills,
              public.class_practice, public.class_teams, public.class_goals from anon, authenticated;

-- The families switch (off until the admin turns it on)
insert into public.settings(key, value) values ('new_games', null) on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 2. The skill map (made from the Garaad Curriculum Skill Map sheet)
-- ---------------------------------------------------------------------

insert into public.skills(id, subject, strand, name, builds_on, sort) values
  ('M01', 'maths', 'Sorting, matching, patterns', 'Sort and group things by colour, shape or kind', array[]::text[], 1),
  ('M02', 'maths', 'Sorting, matching, patterns', 'Match and pair things that are the same', array['M01']::text[], 2),
  ('M03', 'maths', 'Sorting, matching, patterns', 'Put things in order of size, biggest to smallest and back', array['M01']::text[], 3),
  ('M04', 'maths', 'Sorting, matching, patterns', 'Copy and continue a repeating pattern', array['M01']::text[], 4),
  ('M05', 'maths', 'Counting and numbers', 'Say the counting numbers in order (1–10, then 1–30)', array[]::text[], 5),
  ('M06', 'maths', 'Counting and numbers', 'Count objects up to 10, one number for each object', array['M05']::text[], 6),
  ('M07', 'maths', 'Counting and numbers', 'Count objects up to 20', array['M06']::text[], 7),
  ('M08', 'maths', 'Counting and numbers', 'See how many at a glance (dot patterns) without counting', array['M06']::text[], 8),
  ('M09', 'maths', 'Counting and numbers', 'Know the numerals and match them to amounts (to 10, then 20)', array['M06']::text[], 9),
  ('M10', 'maths', 'Counting and numbers', 'Number order: before, after, between, missing number (to 20)', array['M09']::text[], 10),
  ('M11', 'maths', 'Counting and numbers', 'Compare amounts: more, fewer, the same', array['M06']::text[], 11),
  ('M12', 'maths', 'Counting and numbers', 'Write the numerals (0–9, then to 20 and 50)', array['M09']::text[], 12),
  ('M13', 'maths', 'Counting and numbers', 'Count forwards to 50/100 and backwards from 30/50', array['M10']::text[], 13),
  ('M14', 'maths', 'Counting and numbers', 'Read and write number words (one, two… twenty)', array['M09']::text[], 14),
  ('M15', 'maths', 'Counting and numbers', 'Ordinal numbers: 1st to 10th', array['M10']::text[], 15),
  ('M16', 'maths', 'Counting and numbers', 'Zero means none', array['M06']::text[], 16),
  ('M17', 'maths', 'Counting and numbers', 'Odd and even numbers', array['M13']::text[], 17),
  ('M18', 'maths', 'Counting and numbers', 'Skip count in 2s, 5s and 10s', array['M13']::text[], 18),
  ('M19', 'maths', 'Counting and numbers', 'Tens and ones (place value to 99)', array['M13']::text[], 19),
  ('M20', 'maths', 'Counting and numbers', 'Compare and order two-digit numbers with <, > and =', array['M19']::text[], 20),
  ('M21', 'maths', 'Counting and numbers', 'Estimate how many, then check', array['M06']::text[], 21),
  ('M22', 'maths', 'Counting and numbers', 'Round to the nearest 10', array['M19']::text[], 22),
  ('M23', 'maths', 'Adding and subtracting', 'Put groups together and count them all (to 9/10, with pictures)', array['M06']::text[], 23),
  ('M24', 'maths', 'Adding and subtracting', 'Take some away and count what is left (to 9/10, with pictures)', array['M06']::text[], 24),
  ('M25', 'maths', 'Adding and subtracting', 'Number bonds to 5, 10 and 20', array['M23']::text[], 25),
  ('M26', 'maths', 'Adding and subtracting', 'Doubles (and halves of even numbers)', array['M23']::text[], 26),
  ('M27', 'maths', 'Adding and subtracting', 'Use + − and = signs to write number sentences', array['M23']::text[], 27),
  ('M28', 'maths', 'Adding and subtracting', 'Add and subtract within 20', array['M27']::text[], 28),
  ('M29', 'maths', 'Adding and subtracting', 'Add three one-digit numbers', array['M28']::text[], 29),
  ('M30', 'maths', 'Adding and subtracting', 'Two-digit ± one-digit, no carrying (to 50)', array['M19', 'M28']::text[], 30),
  ('M31', 'maths', 'Adding and subtracting', 'Two-digit ± two-digit to 100, with carrying/borrowing; add and subtract multiples of 10', array['M30']::text[], 31),
  ('M32', 'maths', 'Adding and subtracting', 'Find the missing number in a sum; + and − undo each other', array['M28']::text[], 32),
  ('M33', 'maths', 'Adding and subtracting', 'One-step story sums', array['M28']::text[], 33),
  ('M34', 'maths', 'Multiplying, dividing, fractions', 'Equal groups, repeated addition and arrays', array['M18']::text[], 34),
  ('M35', 'maths', 'Multiplying, dividing, fractions', 'Times tables: 1, 2, 3, 4, 5 and 10', array['M34']::text[], 35),
  ('M36', 'maths', 'Multiplying, dividing, fractions', 'Share equally and make equal groups (division)', array['M34']::text[], 36),
  ('M37', 'maths', 'Multiplying, dividing, fractions', 'Halves: of a shape and of a group', array['M26']::text[], 37),
  ('M38', 'maths', 'Multiplying, dividing, fractions', 'Quarters and three-quarters; ½ = 2/4', array['M37']::text[], 38),
  ('M39', 'maths', 'Measures, time, money', 'Long and short; compare lengths', array['M03']::text[], 39),
  ('M40', 'maths', 'Measures, time, money', 'Heavy and light; compare mass', array['M03']::text[], 40),
  ('M41', 'maths', 'Measures, time, money', 'Full and empty; which holds more (capacity)', array['M03']::text[], 41),
  ('M42', 'maths', 'Measures, time, money', 'Measure with units: hand spans and cups, then metres, kilograms, litres', array['M39', 'M40', 'M41']::text[], 42),
  ('M43', 'maths', 'Measures, time, money', 'Daily routine order; days of the week; months of the year', array[]::text[], 43),
  ('M44', 'maths', 'Measures, time, money', 'Tell the time: o''clock and half past, then to 5 minutes', array['M18']::text[], 44),
  ('M45', 'maths', 'Measures, time, money', 'Know the coins and notes of the local currency', array['M06']::text[], 45),
  ('M46', 'maths', 'Measures, time, money', 'Shop: add prices, buy items, give change', array['M45']::text[], 46),
  ('M47', 'maths', 'Measures, time, money', 'Cover a surface with small objects and count them (early area)', array['M06']::text[], 47),
  ('M48', 'maths', 'Shapes and space', 'Straight and curved lines', array[]::text[], 48),
  ('M49', 'maths', 'Shapes and space', 'Name flat shapes: circle, triangle, rectangle, square', array[]::text[], 49),
  ('M50', 'maths', 'Shapes and space', 'Shape properties: count sides and corners', array['M49']::text[], 50),
  ('M51', 'maths', 'Shapes and space', '3D shapes: cube, cuboid, sphere, cylinder, pyramid', array['M49']::text[], 51),
  ('M52', 'maths', 'Shapes and space', 'Position and direction: in, on, under, left, right, turns', array[]::text[], 52),
  ('M53', 'maths', 'Shapes and space', 'Line of symmetry', array['M50']::text[], 53),
  ('M54', 'maths', 'Data and chance', 'Sort and count into a table, tally, pictogram or block graph', array['M01', 'M11']::text[], 54),
  ('M55', 'maths', 'Data and chance', 'Regular pattern or random? Simple chance', array['M04']::text[], 55),
  ('E01', 'english', 'Listening and speaking', 'Listen and follow instructions (one step, then two steps)', array[]::text[], 56),
  ('E02', 'english', 'Listening and speaking', 'Everyday words by theme (family, home, school, body, food, animals, weather, transport, market)', array[]::text[], 57),
  ('E03', 'english', 'Listening and speaking', 'Greetings, goodbyes and polite words', array['E02']::text[], 58),
  ('E04', 'english', 'Listening and speaking', 'Rhyme and rhythm', array[]::text[], 59),
  ('E05', 'english', 'Listening and speaking', 'Hear sounds: first sound, and tell similar sounds apart (p/b, t/d, f/v)', array[]::text[], 60),
  ('E06', 'english', 'Listening and speaking', 'Put story events in order and retell the story', array['E01']::text[], 61),
  ('E07', 'english', 'Reading', 'Handle a book: left to right, top to bottom, turn pages', array[]::text[], 62),
  ('E08', 'english', 'Reading', 'Letter names; match capital and small letters', array[]::text[], 63),
  ('E09', 'english', 'Reading', 'Letter sounds a–z', array['E05', 'E08']::text[], 64),
  ('E10', 'english', 'Reading', 'Read and write simple syllables: ba be bi bo bu … ta to tu', array['E09']::text[], 65),
  ('E11', 'english', 'Reading', 'Blend sounds into short words (c-a-t → cat)', array['E09']::text[], 66),
  ('E12', 'english', 'Reading', 'Two letters, one sound: sh, ch, th, ng, ck, wh', array['E11']::text[], 67),
  ('E13', 'english', 'Reading', 'Consonant blends: bl, cl, fl, gl, sl, br, cr, sp, st, sk, nd, nk, nt', array['E11']::text[], 68),
  ('E14', 'english', 'Reading', 'Long vowels and vowel teams: ee, ea, ay, a-e, i-e, oa, er/ir/ur, ear', array['E12']::text[], 69),
  ('E15', 'english', 'Reading', 'Sight words (tricky words you can''t sound out)', array['E11']::text[], 70),
  ('E16', 'english', 'Reading', 'Read word endings: -s, -es, -ed, -ing', array['E11']::text[], 71),
  ('E17', 'english', 'Reading', 'Read a sentence or caption and match it to a picture', array['E11']::text[], 72),
  ('E18', 'english', 'Reading', 'Read aloud smoothly (fluency)', array['E17']::text[], 73),
  ('E19', 'english', 'Reading', 'Understand a story: who, what, predict, explain', array['E17']::text[], 74),
  ('E20', 'english', 'Writing and spelling', 'Pre-writing: hold a pencil, trace lines and patterns', array[]::text[], 75),
  ('E21', 'english', 'Writing and spelling', 'Form small and capital letters', array['E20']::text[], 76),
  ('E22', 'english', 'Writing and spelling', 'Spell short words (3–5 letters)', array['E11']::text[], 77),
  ('E23', 'english', 'Writing and spelling', 'Unscramble letters to make a word', array['E22']::text[], 78),
  ('E24', 'english', 'Writing and spelling', 'Capital letters, full stops and question marks', array['E25']::text[], 79),
  ('E25', 'english', 'Writing and spelling', 'Build a sentence in the right word order', array['E17']::text[], 80),
  ('E26', 'english', 'Writing and spelling', 'Write about a picture; fill gaps in sentences', array['E25']::text[], 81),
  ('E27', 'english', 'Writing and spelling', 'Commas in a list', array['E24']::text[], 82),
  ('E28', 'english', 'Grammar', 'Verb ''to be'': am, is, are; was, were', array['E25']::text[], 83),
  ('E29', 'english', 'Grammar', 'One and many: -s, -es and irregular plurals', array['E16']::text[], 84),
  ('E30', 'english', 'Grammar', 'Pronouns: I, you; me, us, him, her, them', array['E28']::text[], 85),
  ('E31', 'english', 'Grammar', 'Now: present simple and present continuous (-ing)', array['E28']::text[], 86),
  ('E32', 'english', 'Grammar', 'Before: past tense (-ed, irregular, past continuous)', array['E31']::text[], 87),
  ('E33', 'english', 'Grammar', 'Naming words: common and proper nouns; capitals for names', array['E02']::text[], 88),
  ('E34', 'english', 'Grammar', 'Position words: in, on, under, behind, between, in front of', array['E02']::text[], 89),
  ('E35', 'english', 'Grammar', 'This, that, these, those', array['E29']::text[], 90),
  ('E36', 'english', 'Grammar', 'Describing words and opposites', array['E02']::text[], 91),
  ('E37', 'english', 'Grammar', 'Joining words: and, or, but, because', array['E25']::text[], 92),
  ('E38', 'english', 'Grammar', 'a, an, the', array['E25']::text[], 93),
  ('E39', 'english', 'Grammar', 'Boy and girl word pairs (e.g. cock/hen, king/queen)', array['E02']::text[], 94),
  ('E40', 'english', 'Grammar', 'Telling, asking and command sentences', array['E24']::text[], 95),
  ('E41', 'english', 'Grammar', 'Alphabetical order', array['E08']::text[], 96)
on conflict (id) do update set subject = excluded.subject, strand = excluded.strand, name = excluded.name,
  builds_on = excluded.builds_on, sort = excluded.sort;

delete from public.curriculum_tags;
insert into public.curriculum_tags(skill_id, curriculum, class_label, ref) values
  ('M01', 'kenya_cbe', 'PP1', '1.1'),
  ('M01', 'kenya_cbe', 'PP2', '1.1'),
  ('M01', 'kenya_cbe', 'Grade 1', '1.1a'),
  ('M01', 'england', 'Reception', 'Reception (Development Matters, non-statutory)'),
  ('M01', 'cambridge', 'Stage 1', '1Ss.02'),
  ('M01', 'cambridge', 'Stage 1', 'TWM.06'),
  ('M01', 'cambridge', 'Stage 2', 'TWM.06'),
  ('M02', 'kenya_cbe', 'PP1', '1.2'),
  ('M02', 'kenya_cbe', 'PP2', '1.2'),
  ('M02', 'kenya_cbe', 'Grade 1', '1.1b'),
  ('M02', 'england', 'Reception', 'Reception (Development Matters)'),
  ('M02', 'cambridge', 'Stage 1', 'TWM.06'),
  ('M02', 'cambridge', 'Stage 2', 'TWM.06'),
  ('M03', 'kenya_cbe', 'PP1', '1.3'),
  ('M03', 'kenya_cbe', 'PP2', '1.3'),
  ('M03', 'kenya_cbe', 'Grade 1', '1.1c'),
  ('M03', 'england', 'Year 1', 'Y1 Measurement (compare lengths/heights)'),
  ('M03', 'cambridge', 'Stage 1', '1Gg.02'),
  ('M04', 'kenya_cbe', 'PP1', '1.4'),
  ('M04', 'kenya_cbe', 'PP2', '1.4'),
  ('M04', 'kenya_cbe', 'Grade 1', '1.1d'),
  ('M04', 'kenya_cbe', 'Grade 1', '3.2b'),
  ('M04', 'kenya_cbe', 'Grade 2', '3.2'),
  ('M04', 'england', 'Reception', 'Reception (Development Matters)'),
  ('M04', 'england', 'Year 2', 'Y2 Position (patterns and sequences)'),
  ('M04', 'cambridge', 'Stage 1', '1Nc.06'),
  ('M05', 'kenya_cbe', 'PP1', '2.1 (1–10)'),
  ('M05', 'kenya_cbe', 'PP2', '2.1 (1–30)'),
  ('M05', 'england', 'Reception', 'EYFS ELG Numerical patterns (count beyond 20)'),
  ('M05', 'cambridge', 'Stage 1', '1Ni.01'),
  ('M06', 'kenya_cbe', 'PP1', '2.3 (1–9)'),
  ('M06', 'england', 'Reception', 'EYFS ELG Number'),
  ('M06', 'cambridge', 'Stage 1', '1Nc.01'),
  ('M07', 'kenya_cbe', 'PP2', '2.3 (1–20)'),
  ('M07', 'england', 'Reception', 'EYFS ELG Numerical patterns'),
  ('M07', 'england', 'Year 1', 'Y1'),
  ('M07', 'cambridge', 'Stage 1', '1Nc.01'),
  ('M08', 'england', 'Reception', 'EYFS ELG Number (subitise to 5)'),
  ('M08', 'cambridge', 'Stage 1', '1Nc.02'),
  ('M08', 'cambridge', 'Stage 2', '2Nc.02'),
  ('M09', 'kenya_cbe', 'PP1', '2.2, 2.3c (1–9)'),
  ('M09', 'kenya_cbe', 'PP2', '2.2, 2.3, 2.5 (1–20)'),
  ('M09', 'england', 'Reception', 'EYFS ELG Number'),
  ('M09', 'england', 'Year 1', 'Y1'),
  ('M09', 'cambridge', 'Stage 1', '1Ni.01'),
  ('M10', 'kenya_cbe', 'PP1', '2.4 (1–9)'),
  ('M10', 'kenya_cbe', 'PP2', '2.4 (1–20)'),
  ('M10', 'kenya_cbe', 'Grade 1', '1.2f'),
  ('M10', 'england', 'Year 1', 'Y1 (1 more, 1 less)'),
  ('M10', 'cambridge', 'Stage 1', '1Np.03'),
  ('M11', 'kenya_cbe', 'PP2', '2.5 Number value'),
  ('M11', 'england', 'Reception', 'EYFS ELG Numerical patterns (compare to 10)'),
  ('M11', 'cambridge', 'Stage 1', '1Np.03'),
  ('M12', 'kenya_cbe', 'PP1', '2.5 (1–9)'),
  ('M12', 'kenya_cbe', 'PP2', '2.6 (1–20)'),
  ('M12', 'kenya_cbe', 'Grade 1', '1.2d (1–50)'),
  ('M12', 'england', 'Year 1', 'Y1 (form digits 0–9; read and write to 100)'),
  ('M12', 'cambridge', 'Stage 1', '1Ni.01'),
  ('M13', 'kenya_cbe', 'Grade 1', '1.2a–b (to 50, back from 30)'),
  ('M13', 'kenya_cbe', 'Grade 2', '1.2 (to 100, back from 50)'),
  ('M13', 'england', 'Year 1', 'Y1 (to and across 100, forwards and backwards)'),
  ('M13', 'cambridge', 'Stage 1', '1Nc.04'),
  ('M13', 'cambridge', 'Stage 2', '2Nc.04'),
  ('M14', 'kenya_cbe', 'Grade 1', '1.2e (1–10)'),
  ('M14', 'kenya_cbe', 'Grade 2', '1.2 (1–20)'),
  ('M14', 'england', 'Year 1', 'Y1 (1–20 in words)'),
  ('M14', 'england', 'Year 2', 'Y2 (to 100 in words)'),
  ('M14', 'cambridge', 'Stage 1', '1Ni.01'),
  ('M14', 'cambridge', 'Stage 2', '2Ni.01'),
  ('M15', 'kenya_cbe', 'Grade 2', 'English Theme 8 (cardinal and ordinal numbers)'),
  ('M15', 'cambridge', 'Stage 1', '1Np.04'),
  ('M15', 'cambridge', 'Stage 2', '2Np.04'),
  ('M16', 'england', 'Year 1', 'Y1 (add and subtract including 0)'),
  ('M16', 'cambridge', 'Stage 1', '1Np.01'),
  ('M17', 'england', 'Reception', 'EYFS ELG Numerical patterns (evens and odds)'),
  ('M17', 'cambridge', 'Stage 1', '1Nc.05'),
  ('M17', 'cambridge', 'Stage 2', '2Nc.05'),
  ('M18', 'kenya_cbe', 'Grade 2', '1.5 (groups of 3, 4, 5, 10)'),
  ('M18', 'england', 'Year 1', 'Y1 (2s, 5s, 10s)'),
  ('M18', 'england', 'Year 2', 'Y2 (2s, 3s, 5s, 10s)'),
  ('M18', 'cambridge', 'Stage 1', '1Nc.04'),
  ('M18', 'cambridge', 'Stage 2', '2Nc.04'),
  ('M19', 'kenya_cbe', 'Grade 2', '1.2 (ones and tens)'),
  ('M19', 'england', 'Year 2', 'Y2 Number and place value'),
  ('M19', 'cambridge', 'Stage 1', '1Np.02'),
  ('M19', 'cambridge', 'Stage 2', '2Np.01'),
  ('M19', 'cambridge', 'Stage 2', '2Np.02'),
  ('M20', 'england', 'Year 2', 'Y2'),
  ('M20', 'cambridge', 'Stage 2', '2Np.03'),
  ('M21', 'england', 'Year 2', 'Y2 (estimate on a number line)'),
  ('M21', 'cambridge', 'Stage 1', '1Nc.03'),
  ('M21', 'cambridge', 'Stage 2', '2Nc.03'),
  ('M22', 'cambridge', 'Stage 2', '2Np.05'),
  ('M23', 'kenya_cbe', 'PP2', '2.7 (sum to 9)'),
  ('M23', 'kenya_cbe', 'Grade 1', '1.3a'),
  ('M23', 'england', 'Reception', 'EYFS ELG Number'),
  ('M23', 'england', 'Year 1', 'Y1'),
  ('M23', 'cambridge', 'Stage 1', '1Ni.02'),
  ('M24', 'kenya_cbe', 'PP2', '2.8 (from 9)'),
  ('M24', 'kenya_cbe', 'Grade 1', '1.4a'),
  ('M24', 'england', 'Year 1', 'Y1'),
  ('M24', 'cambridge', 'Stage 1', '1Ni.03'),
  ('M25', 'england', 'Reception', 'EYFS ELG Number (bonds to 5, some to 10)'),
  ('M25', 'england', 'Year 1', 'Y1 (bonds within 20)'),
  ('M25', 'cambridge', 'Stage 1', '1Ni.04'),
  ('M25', 'cambridge', 'Stage 2', '2Ni.03'),
  ('M26', 'england', 'Reception', 'EYFS ELG Number (double facts)'),
  ('M26', 'cambridge', 'Stage 1', '1Ni.06'),
  ('M27', 'kenya_cbe', 'Grade 1', '1.3b'),
  ('M27', 'kenya_cbe', 'Grade 1', '1.4b'),
  ('M27', 'england', 'Year 1', 'Y1'),
  ('M27', 'cambridge', 'Stage 1', '1Ni.02'),
  ('M27', 'cambridge', 'Stage 1', '1Ni.03'),
  ('M28', 'kenya_cbe', 'Grade 1', '1.3c'),
  ('M28', 'kenya_cbe', 'Grade 1', '1.4c'),
  ('M28', 'england', 'Year 1', 'Y1'),
  ('M28', 'cambridge', 'Stage 1', '1Ni.05'),
  ('M29', 'kenya_cbe', 'Grade 1', '1.3d'),
  ('M29', 'england', 'Year 2', 'Y2'),
  ('M30', 'kenya_cbe', 'Grade 1', '1.3e'),
  ('M30', 'kenya_cbe', 'Grade 1', '1.4d'),
  ('M30', 'england', 'Year 2', 'Y2 (a two-digit number and ones)'),
  ('M30', 'cambridge', 'Stage 2', '2Ni.04'),
  ('M31', 'kenya_cbe', 'Grade 2', '1.3'),
  ('M31', 'kenya_cbe', 'Grade 2', '1.4'),
  ('M31', 'england', 'Year 2', 'Y2'),
  ('M31', 'cambridge', 'Stage 2', '2Ni.04'),
  ('M32', 'kenya_cbe', 'Grade 1', '1.3f'),
  ('M32', 'kenya_cbe', 'Grade 1', '1.4f'),
  ('M32', 'kenya_cbe', 'Grade 2', '1.3–1.4 (missing numbers in patterns)'),
  ('M32', 'england', 'Year 2', 'Y2 (inverse relationship)'),
  ('M32', 'cambridge', 'Stage 2', '2Ni.02'),
  ('M33', 'england', 'Year 1', 'Y1'),
  ('M33', 'england', 'Year 2', 'Y2 (one-step problems)'),
  ('M33', 'cambridge', 'Stage 1', 'TWM'),
  ('M33', 'cambridge', 'Stage 2', 'TWM'),
  ('M34', 'kenya_cbe', 'Grade 2', '1.5'),
  ('M34', 'england', 'Year 1', 'Y1 (with objects)'),
  ('M34', 'england', 'Year 2', 'Y2'),
  ('M34', 'cambridge', 'Stage 2', '2Ni.05'),
  ('M35', 'kenya_cbe', 'Grade 2', '1.5 (×1–5 and ×10)'),
  ('M35', 'england', 'Year 2', 'Y2 (2, 5, 10)'),
  ('M35', 'cambridge', 'Stage 2', '2Ni.07'),
  ('M36', 'kenya_cbe', 'Grade 2', '1.6 (share to 20 by 2; group to 25 by 3; ÷4, ÷5)'),
  ('M36', 'england', 'Year 2', 'Y2'),
  ('M36', 'cambridge', 'Stage 2', '2Ni.06'),
  ('M37', 'kenya_cbe', 'Grade 2', '1.7 (½)'),
  ('M37', 'england', 'Year 1', 'Y1'),
  ('M37', 'cambridge', 'Stage 1', '1Nf.01–04'),
  ('M38', 'kenya_cbe', 'Grade 2', '1.7 (¼)'),
  ('M38', 'england', 'Year 1', 'Y1 (¼)'),
  ('M38', 'england', 'Year 2', 'Y2 (⅓, ¼, 2/4, ¾)'),
  ('M38', 'cambridge', 'Stage 2', '2Nf.01–06'),
  ('M39', 'kenya_cbe', 'PP1', '3.1'),
  ('M39', 'kenya_cbe', 'PP2', '3.1'),
  ('M39', 'kenya_cbe', 'Grade 1', '2.1'),
  ('M39', 'england', 'Year 1', 'Y1'),
  ('M39', 'cambridge', 'Stage 1', '1Gg.02'),
  ('M40', 'kenya_cbe', 'PP1', '3.2'),
  ('M40', 'kenya_cbe', 'PP2', '3.2'),
  ('M40', 'kenya_cbe', 'Grade 1', '2.2'),
  ('M40', 'england', 'Year 1', 'Y1'),
  ('M40', 'cambridge', 'Stage 1', '1Gg.04'),
  ('M41', 'kenya_cbe', 'PP1', '3.3'),
  ('M41', 'kenya_cbe', 'PP2', '3.3'),
  ('M41', 'kenya_cbe', 'Grade 1', '2.3'),
  ('M41', 'england', 'Year 1', 'Y1'),
  ('M41', 'cambridge', 'Stage 1', '1Gg.05'),
  ('M42', 'kenya_cbe', 'Grade 1', '2.1c, 2.2c, 2.3c (arbitrary units)'),
  ('M42', 'kenya_cbe', 'Grade 2', '2.1–2.3 (m, kg, litres)'),
  ('M42', 'england', 'Year 1', 'Y1 (begin to measure)'),
  ('M42', 'england', 'Year 2', 'Y2 (m/cm, kg/g, l/ml)'),
  ('M42', 'cambridge', 'Stage 2', '2Gg.03'),
  ('M42', 'cambridge', 'Stage 2', '2Gg.06'),
  ('M42', 'cambridge', 'Stage 2', '2Gg.07'),
  ('M42', 'cambridge', 'Stage 2', '2Gg.12'),
  ('M43', 'kenya_cbe', 'PP1', '3.4'),
  ('M43', 'kenya_cbe', 'PP2', '3.4'),
  ('M43', 'kenya_cbe', 'Grade 1', '2.4'),
  ('M43', 'kenya_cbe', 'Grade 2', '2.4 (calendar)'),
  ('M43', 'england', 'Year 1', 'Y1 (before/after; days, weeks, months)'),
  ('M43', 'cambridge', 'Stage 1', '1Gt.01'),
  ('M43', 'cambridge', 'Stage 1', '1Gt.02'),
  ('M43', 'cambridge', 'Stage 2', '2Gt.01'),
  ('M43', 'cambridge', 'Stage 2', '2Gt.03'),
  ('M44', 'kenya_cbe', 'Grade 2', '2.4 (by the hour)'),
  ('M44', 'england', 'Year 1', 'Y1 (hour, half hour)'),
  ('M44', 'england', 'Year 2', 'Y2 (5 minutes)'),
  ('M44', 'cambridge', 'Stage 1', '1Gt.03'),
  ('M44', 'cambridge', 'Stage 2', '2Gt.02'),
  ('M45', 'kenya_cbe', 'PP1', '3.5 (Ksh 1)'),
  ('M45', 'kenya_cbe', 'PP2', '3.5'),
  ('M45', 'kenya_cbe', 'Grade 1', '2.5 (notes to sh.50)'),
  ('M45', 'kenya_cbe', 'Grade 2', '2.5 (to sh.100)'),
  ('M45', 'england', 'Year 1', 'Y1 (coins and notes)'),
  ('M45', 'england', 'Year 2', 'Y2 (£ and p)'),
  ('M45', 'cambridge', 'Stage 1', '1Nm.01'),
  ('M45', 'cambridge', 'Stage 2', '2Nm.01'),
  ('M46', 'kenya_cbe', 'Grade 1', '2.5d (2 items, no balance)'),
  ('M46', 'kenya_cbe', 'Grade 2', '2.5 (3 items, sum to sh.100)'),
  ('M46', 'england', 'Year 2', 'Y2 (combine amounts, change)'),
  ('M46', 'cambridge', 'Stage 2', '2Nm.02'),
  ('M47', 'kenya_cbe', 'PP1', '3.6'),
  ('M47', 'kenya_cbe', 'PP2', '3.6'),
  ('M48', 'kenya_cbe', 'PP1', '4.1'),
  ('M48', 'kenya_cbe', 'PP2', '4.1'),
  ('M48', 'kenya_cbe', 'Grade 1', '3.1'),
  ('M48', 'kenya_cbe', 'Grade 2', '3.1'),
  ('M48', 'cambridge', 'Stage 1', '1Gg.01'),
  ('M49', 'kenya_cbe', 'PP1', '4.2'),
  ('M49', 'kenya_cbe', 'PP2', '4.2'),
  ('M49', 'kenya_cbe', 'Grade 1', '3.2a'),
  ('M49', 'kenya_cbe', 'Grade 2', '3.2'),
  ('M49', 'england', 'Year 1', 'Y1'),
  ('M49', 'cambridge', 'Stage 1', '1Gg.01'),
  ('M50', 'england', 'Year 2', 'Y2 (sides; line symmetry)'),
  ('M50', 'cambridge', 'Stage 1', '1Gg.01'),
  ('M50', 'cambridge', 'Stage 2', '2Gg.01'),
  ('M51', 'england', 'Year 1', 'Y1'),
  ('M51', 'england', 'Year 2', 'Y2 (faces, edges, vertices)'),
  ('M51', 'cambridge', 'Stage 1', '1Gg.03'),
  ('M51', 'cambridge', 'Stage 1', '1Gg.06'),
  ('M51', 'cambridge', 'Stage 2', '2Gg.05'),
  ('M51', 'cambridge', 'Stage 2', '2Gg.08'),
  ('M52', 'england', 'Year 1', 'Y1 (incl. half and quarter turns)'),
  ('M52', 'england', 'Year 2', 'Y2'),
  ('M52', 'cambridge', 'Stage 1', '1Gp.01'),
  ('M52', 'cambridge', 'Stage 2', '2Gp.01'),
  ('M52', 'cambridge', 'Stage 2', '2Gg.11'),
  ('M53', 'england', 'Year 2', 'Y2 (vertical line)'),
  ('M53', 'cambridge', 'Stage 2', '2Gg.09'),
  ('M53', 'cambridge', 'Stage 2', '2Gp.02'),
  ('M54', 'england', 'Year 2', 'Y2 Statistics'),
  ('M54', 'cambridge', 'Stage 1', '1Ss.01–03'),
  ('M54', 'cambridge', 'Stage 2', '2Ss.01–03'),
  ('M55', 'cambridge', 'Stage 2', '2Sp.01'),
  ('M55', 'cambridge', 'Stage 2', '2Sp.02'),
  ('E01', 'kenya_cbe', 'PP1', 'Unit 3 1.1'),
  ('E01', 'kenya_cbe', 'Grade 1', 'Theme 3 (one-step)'),
  ('E01', 'kenya_cbe', 'Grade 2', 'Theme 1 (two-step)'),
  ('E01', 'england', 'Year 1', 'Spoken language Y1–6'),
  ('E01', 'england', 'Year 2', 'Spoken language Y1–6'),
  ('E01', 'cambridge', 'Stage 1', '1SLs.01'),
  ('E02', 'england', 'Year 1', 'Spoken language Y1–6'),
  ('E02', 'england', 'Year 2', 'Spoken language Y1–6'),
  ('E02', 'england', 'Reception', 'EYFS ELG Speaking'),
  ('E02', 'cambridge', 'Stage 1', '1Wv.01'),
  ('E02', 'cambridge', 'Stage 1', '1SLm.03'),
  ('E03', 'kenya_cbe', 'PP1', 'Unit 1'),
  ('E03', 'kenya_cbe', 'PP2', 'Unit 1 and 4.0 1.1'),
  ('E03', 'kenya_cbe', 'Grade 1', 'Theme 1'),
  ('E03', 'england', 'Year 1', 'Spoken language Y1–6'),
  ('E03', 'england', 'Year 2', 'Spoken language Y1–6'),
  ('E03', 'cambridge', 'Stage 1', '1SLm.01'),
  ('E04', 'kenya_cbe', 'PP2', '2.2 (chant rhymes)'),
  ('E04', 'kenya_cbe', 'Grade 2', 'Theme 6 (recite rhymes)'),
  ('E04', 'england', 'Year 1', 'Y1 (recite rhymes and poems)'),
  ('E04', 'cambridge', 'Stage 1', '1Rv.05'),
  ('E04', 'cambridge', 'Stage 1', '1Ri.14'),
  ('E04', 'cambridge', 'Stage 1', '1Ww.03'),
  ('E05', 'kenya_cbe', 'PP2', '5.0 1.1 (sound pairs)'),
  ('E05', 'kenya_cbe', 'Grade 1', 'Theme 11 (minimal pairs)'),
  ('E05', 'england', 'Reception', 'EYFS / Y1 phonics'),
  ('E05', 'england', 'Year 1', 'EYFS / Y1 phonics'),
  ('E05', 'cambridge', 'Stage 1', '1Rw.01'),
  ('E06', 'kenya_cbe', 'PP2', '8.0 (news telling)'),
  ('E06', 'kenya_cbe', 'Grade 2', 'comprehension (retell)'),
  ('E06', 'england', 'Year 1', 'Y1 (retell familiar stories)'),
  ('E06', 'cambridge', 'Stage 1', '1Rs.01'),
  ('E06', 'cambridge', 'Stage 1', '1Ri.06'),
  ('E06', 'cambridge', 'Stage 2', '2Ri.07'),
  ('E07', 'kenya_cbe', 'PP1', '2.1'),
  ('E07', 'kenya_cbe', 'PP2', '2.1'),
  ('E07', 'cambridge', 'Stage 1', '1Rs.03'),
  ('E08', 'kenya_cbe', 'PP2', '2.3'),
  ('E08', 'kenya_cbe', 'Grade 1', 'Theme 2'),
  ('E08', 'england', 'Year 1', 'Y1 (name letters in order)'),
  ('E08', 'cambridge', 'Stage 1', '1Rw.01'),
  ('E08', 'cambridge', 'Stage 1', '1Rv.04'),
  ('E09', 'kenya_cbe', 'PP1', '2.2 (a–e, f–j, k–t)'),
  ('E09', 'kenya_cbe', 'PP2', '(A–Z)'),
  ('E09', 'kenya_cbe', 'Grade 1', 'Themes 1–9 (in groups: a m t e · s l i p · f n h o · b r u g · c d w)'),
  ('E09', 'england', 'Reception', 'EYFS ELG Word reading (a sound for each letter)'),
  ('E09', 'england', 'Year 1', 'Y1'),
  ('E09', 'cambridge', 'Stage 1', '1Rw.01'),
  ('E10', 'kenya_cbe', 'PP2', '2.2–2.3 and 3.2–3.3 (ba–bu, da–du, fa–fu, … ta–tu)'),
  ('E11', 'kenya_cbe', 'PP2', '7.0 2.3 (cat, peg, pot)'),
  ('E11', 'kenya_cbe', 'Grade 1', 'Themes 1–5 (2–4 letter words)'),
  ('E11', 'england', 'Reception', 'EYFS ELG Word reading'),
  ('E11', 'england', 'Year 1', 'Y1'),
  ('E11', 'cambridge', 'Stage 1', '1Rw.03'),
  ('E11', 'cambridge', 'Stage 1', '1Rw.05'),
  ('E12', 'kenya_cbe', 'Grade 1', 'Theme 11 (sh, ch, th)'),
  ('E12', 'kenya_cbe', 'Grade 2', 'Themes 1, 4, 6 (ck, ng, wh)'),
  ('E12', 'england', 'Reception', 'EYFS ELG Word reading (10+ digraphs)'),
  ('E12', 'england', 'Year 1', 'Y1'),
  ('E12', 'cambridge', 'Stage 1', '1Rw.02'),
  ('E12', 'cambridge', 'Stage 1', '1Ww.02'),
  ('E13', 'kenya_cbe', 'Grade 2', 'Themes 1–9'),
  ('E13', 'england', 'Year 1', 'Y1 (adjacent consonants)'),
  ('E13', 'cambridge', 'Stage 1', '1Rw.03'),
  ('E14', 'kenya_cbe', 'Grade 1', 'Themes 10, 12'),
  ('E14', 'kenya_cbe', 'Grade 2', 'Themes 2–9'),
  ('E14', 'england', 'Year 1', 'Y1 (alternative sounds)'),
  ('E14', 'england', 'Year 2', 'Y2'),
  ('E14', 'cambridge', 'Stage 2', '2Rw.01'),
  ('E14', 'cambridge', 'Stage 2', '2Rw.02'),
  ('E14', 'cambridge', 'Stage 2', '2Ww.01'),
  ('E15', 'kenya_cbe', 'Grade 1', 'Themes 5, 7 (non-decodable words, word wall)'),
  ('E15', 'england', 'Year 1', 'Y1'),
  ('E15', 'england', 'Year 2', 'Y2 (common exception words)'),
  ('E15', 'cambridge', 'Stage 1', '1Rw.07'),
  ('E15', 'cambridge', 'Stage 2', '2Rw.07'),
  ('E16', 'kenya_cbe', 'Grade 1', 'Themes 4, 6, 7 (through grammar)'),
  ('E16', 'england', 'Year 1', 'Y1'),
  ('E16', 'cambridge', 'Stage 1', '1Rw.04'),
  ('E16', 'cambridge', 'Stage 2', '2Rw.03'),
  ('E17', 'kenya_cbe', 'Grade 1', 'Theme 6 (decodable sentences)'),
  ('E17', 'england', 'Year 1', 'Y1'),
  ('E17', 'cambridge', 'Stage 1', '1Rv.01'),
  ('E17', 'cambridge', 'Stage 1', '1Ri.08'),
  ('E18', 'kenya_cbe', 'Grade 1', 'Themes 8–12 (~30 words per minute)'),
  ('E18', 'kenya_cbe', 'Grade 2', '(~65 words per minute)'),
  ('E18', 'england', 'Year 2', 'Y2 (read fluently)'),
  ('E18', 'cambridge', 'Stage 1', '1Ra.03'),
  ('E18', 'cambridge', 'Stage 2', '2Rw.04'),
  ('E18', 'cambridge', 'Stage 1', '1SLp.01'),
  ('E19', 'kenya_cbe', 'Grade 1', 'Themes 11–12'),
  ('E19', 'kenya_cbe', 'Grade 2', 'comprehension in every theme'),
  ('E19', 'england', 'Year 1', 'Y1'),
  ('E19', 'england', 'Year 2', 'Y2 comprehension'),
  ('E19', 'cambridge', 'Stage 1', '1Ri.10–13'),
  ('E19', 'cambridge', 'Stage 2', '2Ri.11–13'),
  ('E20', 'kenya_cbe', 'PP1', '3.1–3.2'),
  ('E20', 'kenya_cbe', 'PP2', '3.1, 5.0 3.1'),
  ('E20', 'england', 'Year 1', 'Y1 Handwriting'),
  ('E20', 'cambridge', 'Stage 1', '1Wp.01'),
  ('E21', 'kenya_cbe', 'PP2', '4.0 3.2'),
  ('E21', 'kenya_cbe', 'Grade 1', 'Themes 3–7'),
  ('E21', 'england', 'Year 1', 'Y1 Handwriting'),
  ('E21', 'cambridge', 'Stage 1', '1Wp.02'),
  ('E22', 'kenya_cbe', 'Grade 1', 'Themes 6–8'),
  ('E22', 'kenya_cbe', 'Grade 2', 'Themes 5–8'),
  ('E22', 'england', 'Year 1', 'Y1 Spelling'),
  ('E22', 'cambridge', 'Stage 1', '1Ww.05'),
  ('E22', 'cambridge', 'Stage 1', '1Ww.06'),
  ('E23', 'kenya_cbe', 'Grade 1', 'Theme 8'),
  ('E24', 'kenya_cbe', 'Grade 1', 'Themes 9–10'),
  ('E24', 'england', 'Year 1', 'Y1'),
  ('E24', 'england', 'Year 2', 'Y2'),
  ('E24', 'cambridge', 'Stage 1', '1Wg.01'),
  ('E24', 'cambridge', 'Stage 1', '1Wg.03'),
  ('E24', 'cambridge', 'Stage 2', '2Wg.01'),
  ('E25', 'kenya_cbe', 'Grade 1', 'Theme 11 (guided writing)'),
  ('E25', 'england', 'Year 1', 'Y1 (compose a sentence)'),
  ('E25', 'cambridge', 'Stage 1', '1Wg.04'),
  ('E26', 'kenya_cbe', 'Grade 1', 'Theme 11 (4–6 letter words in gaps)'),
  ('E26', 'england', 'Year 1', 'Y1'),
  ('E26', 'england', 'Year 2', 'Y2 composition'),
  ('E26', 'cambridge', 'Stage 1', '1Wc.05'),
  ('E26', 'cambridge', 'Stage 2', '2Wc.03'),
  ('E27', 'kenya_cbe', 'Grade 2', 'Theme 9'),
  ('E27', 'england', 'Year 2', 'Y2'),
  ('E27', 'cambridge', 'Stage 2', '2Wg.02'),
  ('E28', 'kenya_cbe', 'Grade 1', 'Theme 1'),
  ('E28', 'kenya_cbe', 'Grade 2', 'Themes 1–2'),
  ('E28', 'england', 'Year 1', 'Y1–Y2 (Standard English)'),
  ('E28', 'england', 'Year 2', 'Y1–Y2 (Standard English)'),
  ('E28', 'cambridge', 'Stage 1', '1Rg.05'),
  ('E29', 'kenya_cbe', 'Grade 1', 'Theme 4 (-s/-es)'),
  ('E29', 'kenya_cbe', 'Grade 2', 'Theme 5 (irregular)'),
  ('E29', 'england', 'Year 1', 'Y1 (-s/-es)'),
  ('E29', 'cambridge', 'Stage 1', '1Ww.04'),
  ('E29', 'cambridge', 'Stage 2', '2Ww.04'),
  ('E30', 'kenya_cbe', 'Grade 1', 'Theme 3'),
  ('E30', 'kenya_cbe', 'Grade 2', 'Theme 3'),
  ('E30', 'cambridge', 'Stage 2', '2Rg.06'),
  ('E30', 'cambridge', 'Stage 2', '2Wg.09'),
  ('E31', 'kenya_cbe', 'Grade 1', 'Themes 5–6'),
  ('E31', 'england', 'Year 2', 'Y2 (progressive form)'),
  ('E31', 'cambridge', 'Stage 2', '2Wg.07'),
  ('E32', 'kenya_cbe', 'Grade 1', 'Theme 7'),
  ('E32', 'kenya_cbe', 'Grade 2', 'Themes 4, 6'),
  ('E32', 'england', 'Year 1', 'Y1 (-ed)'),
  ('E32', 'england', 'Year 2', 'Y2'),
  ('E32', 'cambridge', 'Stage 1', '1Rw.04'),
  ('E32', 'cambridge', 'Stage 2', '2Ww.05'),
  ('E32', 'cambridge', 'Stage 2', '2Wg.07'),
  ('E33', 'kenya_cbe', 'Grade 1', 'Theme 9'),
  ('E33', 'england', 'Year 1', 'Y1 (capitals for names, places, days)'),
  ('E33', 'cambridge', 'Stage 1', '1Rg.06'),
  ('E33', 'cambridge', 'Stage 1', '1Wg.03'),
  ('E34', 'kenya_cbe', 'Grade 1', 'Theme 10'),
  ('E35', 'kenya_cbe', 'Grade 1', 'Theme 8'),
  ('E35', 'kenya_cbe', 'Grade 2', 'Theme 8'),
  ('E36', 'kenya_cbe', 'Grade 1', 'Theme 11 (adjectives)'),
  ('E36', 'kenya_cbe', 'Grade 2', 'Theme 9 (opposites)'),
  ('E36', 'england', 'Year 2', 'Y2 (expanded noun phrases)'),
  ('E36', 'cambridge', 'Stage 2', '2Rv.04'),
  ('E36', 'cambridge', 'Stage 2', '2Wv.02'),
  ('E36', 'cambridge', 'Stage 2', '2Wg.10'),
  ('E37', 'kenya_cbe', 'Grade 2', 'Theme 7 (or)'),
  ('E37', 'england', 'Year 1', 'Y1 (and)'),
  ('E37', 'england', 'Year 2', 'Y2 (or, and, but; when, if, because)'),
  ('E37', 'cambridge', 'Stage 1', '1Rg.04'),
  ('E37', 'cambridge', 'Stage 1', '1Wg.05'),
  ('E37', 'cambridge', 'Stage 2', '2Wg.05'),
  ('E37', 'cambridge', 'Stage 2', '2Wg.06'),
  ('E38', 'cambridge', 'Stage 1', '1Rg.07'),
  ('E38', 'cambridge', 'Stage 1', '1Wg.06'),
  ('E39', 'kenya_cbe', 'Grade 2', 'Theme 9 (gender word sets)'),
  ('E40', 'england', 'Year 2', 'Y2 (statement, question, exclamation, command)'),
  ('E40', 'cambridge', 'Stage 2', '2Rg.04'),
  ('E40', 'cambridge', 'Stage 2', '2Wg.04'),
  ('E41', 'england', 'Year 1', 'Y1 (letters in order)'),
  ('E41', 'cambridge', 'Stage 1', '1Rv.04'),
  ('E41', 'cambridge', 'Stage 2', '2Rv.03');

delete from public.game_skills;
insert into public.game_skills(game, skill_id, level_from, level_to) values
  ('count', 'M06', 1, 10),
  ('findnum', 'M09', 1, 7),
  ('findnum', 'M08', 8, 10),
  ('order', 'M10', 1, 10),
  ('more', 'M11', 1, 10),
  ('sizes', 'M03', 1, 10),
  ('sizes', 'M39', 1, 10),
  ('odd', 'M01', 1, 10),
  ('odd', 'M02', 1, 10),
  ('colours', 'M01', 1, 10),
  ('pattern', 'M04', 1, 10),
  ('shapes', 'M49', 1, 6),
  ('shapes', 'M50', 7, 10),
  ('addpics', 'M23', 1, 10),
  ('takeaway', 'M24', 1, 10),
  ('addsub', 'M27', 1, 10),
  ('addsub', 'M28', 1, 6),
  ('addsub', 'M30', 7, 7),
  ('addsub', 'M31', 8, 10),
  ('missing', 'M32', 1, 10),
  ('missing', 'M25', 1, 10),
  ('place', 'M19', 1, 7),
  ('compare', 'M20', 1, 10),
  ('skip', 'M18', 1, 10),
  ('story', 'M33', 1, 7),
  ('clock', 'M44', 1, 10),
  ('money', 'M45', 1, 10),
  ('money', 'M46', 1, 10),
  ('doubles', 'M26', 1, 10),
  ('doubles', 'M37', 1, 10),
  ('groups', 'M34', 1, 10),
  ('times', 'M35', 1, 8),
  ('divide', 'M36', 1, 10),
  ('fractions', 'M38', 1, 5),
  ('etap', 'E02', 1, 10),
  ('esafari', 'E02', 1, 10),
  ('esimon', 'E01', 1, 10),
  ('eparrot', 'E02', 1, 10),
  ('ename', 'E02', 1, 10),
  ('erhyme', 'E04', 1, 10),
  ('eclap', 'E04', 1, 10),
  ('efish', 'E05', 1, 10),
  ('eopp', 'E36', 1, 10),
  ('esort', 'E02', 1, 10),
  ('eletter', 'E08', 1, 10),
  ('etrace', 'E20', 1, 10),
  ('etrace', 'E21', 1, 10),
  ('ecaption', 'E17', 1, 10),
  ('eyesno', 'E17', 1, 10),
  ('eyesno', 'E19', 1, 10),
  ('estory', 'E06', 1, 10),
  ('eread', 'E19', 1, 10),
  ('emissing', 'E22', 1, 10),
  ('espell', 'E22', 1, 10),
  ('ebee', 'E22', 1, 10),
  ('ebee', 'E23', 1, 10),
  ('esentence', 'E25', 1, 10),
  ('efix', 'E24', 1, 10),
  ('bbonds', 'M25', 1, 10),
  ('bnumber', 'M07', 1, 4),
  ('bnumber', 'M09', 1, 4),
  ('bnumber', 'M19', 5, 10),
  ('tnumbers', 'M10', 1, 3),
  ('tnumbers', 'M13', 4, 6),
  ('tnumbers', 'M20', 5, 6),
  ('tnumbers', 'M18', 7, 10),
  ('tdays', 'M43', 1, 10),
  ('smeasure', 'M40', 1, 2),
  ('smeasure', 'M41', 3, 6),
  ('smeasure', 'M39', 7, 8),
  ('smeasure', 'M40', 9, 10),
  ('smeasure', 'M41', 9, 10),
  ('mmarket', 'M45', 1, 4),
  ('mmarket', 'M46', 5, 10),
  ('sgrammar', 'E29', 1, 3),
  ('sgrammar', 'E28', 4, 5),
  ('sgrammar', 'E35', 6, 7),
  ('sgrammar', 'E30', 8, 8),
  ('sgrammar', 'E38', 9, 9),
  ('sgrammar', 'E29', 10, 10),
  ('sgrammar', 'E28', 10, 10),
  ('sgrammar', 'E35', 10, 10),
  ('sgrammar', 'E30', 10, 10),
  ('sgrammar', 'E38', 10, 10);

-- ---------------------------------------------------------------------
-- 3. Helpers
-- ---------------------------------------------------------------------

-- Today and this week in school time (Mogadishu and Nairobi are both UTC+3).
create or replace function public._today() returns date
language sql stable as $$ select (now() at time zone 'Africa/Mogadishu')::date; $$;
create or replace function public._at(d date) returns timestamptz
language sql stable as $$ select d::timestamp at time zone 'Africa/Mogadishu'; $$;
create or replace function public._week_start(d date default null) returns date
language sql stable as $$ select date_trunc('week', coalesce(d, public._today())::timestamp)::date; $$;   -- Monday

-- A class of the caller's school (teacher or principal).
create or replace function public._school_class(t public.tokens, p_class_id uuid) returns public.classes
language plpgsql security definer set search_path = public, extensions as $$
declare c public.classes;
begin
  if t.role not in ('teacher','principal') then raise exception 'not_allowed'; end if;
  select * into c from public.classes where id = p_class_id and school_id = t.school_id;
  if not found then raise exception 'not_in_school'; end if;
  return c;
end $$;

-- First name only, for anything children see.
create or replace function public._first(n text) returns text
language sql immutable as $$ select split_part(trim(coalesce(n,'')), ' ', 1); $$;

-- ---------------------------------------------------------------------
-- 4. School settings: curriculum, currency, classes, feature switches
-- ---------------------------------------------------------------------

-- Teachers and the principal read their school's settings after login.
create or replace function public.school_options(p_token text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role not in ('teacher','principal') then raise exception 'not_allowed'; end if;
  return (select json_build_object(
    'curriculum', s.curriculum, 'currency', s.currency, 'features', s.features, 'date', public._today(),
    'classes', coalesce((select json_agg(json_build_object('id', c.id, 'name', c.name,
                 'curriculum_class', c.curriculum_class, 'options', c.options) order by c.sort_order)
               from public.classes c where c.school_id = s.id and c.active), '[]'::json),
    -- today's practice set for each class (the child's "Today's practice" uses it)
    'practice', coalesce((select json_object_agg(p.class_id, json_build_object('games', p.games,
                 'skills', (select json_agg(json_build_object('id', sk.id, 'name', sk.name)) from public.skills sk where sk.id = any(p.skills))))
               from public.class_practice p join public.classes c on c.id = p.class_id
              where c.school_id = s.id and p.day = public._today()), '{}'::json))
    from public.schools s where s.id = t.school_id);
end $$;

-- The principal sets the curriculum, the currency and which curriculum class each class is.
-- p_class_map: {"<class id>": "Grade 1", ...}; an empty text clears a class.
create or replace function public.school_set_options(p_token text, p_curriculum text, p_currency text default null,
  p_class_map jsonb default '{}'::jsonb) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._need_principal(p_token); k text; v text;
begin
  if p_curriculum not in ('garaad','kenya_cbe','england','cambridge') then return json_build_object('ok', false, 'error', 'bad_curriculum'); end if;
  if p_currency is not null and p_currency <> '' and p_currency not in ('KES','USD','GBP','coins') then return json_build_object('ok', false, 'error', 'bad_currency'); end if;
  update public.schools set curriculum = p_curriculum, currency = nullif(p_currency, '') where id = t.school_id;
  for k, v in select key, value from jsonb_each_text(coalesce(p_class_map, '{}'::jsonb)) loop
    update public.classes set curriculum_class = nullif(left(trim(v), 30), '')
     where id = k::uuid and school_id = t.school_id;
  end loop;
  return json_build_object('ok', true);
end $$;

-- The Garaad admin: every school's settings, and the feature switches.
create or replace function public.admin_school_options(p_token text) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform public._need_admin(p_token);
  return coalesce((select json_agg(json_build_object('id', s.id, 'name', s.name, 'curriculum', s.curriculum,
            'currency', s.currency, 'features', s.features) order by s.name) from public.schools s), '[]'::json);
end $$;

-- p_features: {"new_games": true, "class_tools": true, "competition": true}; other keys are ignored.
create or replace function public.admin_set_school_features(p_token text, p_school_id uuid, p_features jsonb) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare f jsonb := '{}'::jsonb; k text;
begin
  perform public._need_admin(p_token);
  foreach k in array array['new_games','class_tools','competition'] loop
    if coalesce(p_features ->> k, '') in ('true','on','1') then f := f || jsonb_build_object(k, true); end if;
  end loop;
  update public.schools set features = f where id = p_school_id;
  if not found then return json_build_object('ok', false, 'error', 'not_found'); end if;
  return json_build_object('ok', true, 'features', f);
end $$;

-- Families: the new games switch (and the earlier settings, unchanged).
create or replace function public.public_settings() returns json
language sql stable security definer set search_path = public, extensions as $$
  select json_build_object(
    'parents_group_link', (select value from public.settings where key = 'parents_group_link'),
    'admin_whatsapp',     (select value from public.settings where key = 'admin_whatsapp'),
    'arabic_schools',     (select value from public.settings where key = 'arabic_schools'),
    'new_games',          (select value from public.settings where key = 'new_games'));
$$;

create or replace function public.admin_set_setting(p_token text, p_key text, p_value text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare v text := nullif(trim(coalesce(p_value,'')), '');
begin
  perform public._need_admin(p_token);
  if p_key not in ('parents_group_link', 'admin_whatsapp', 'arabic_schools', 'new_games') then return json_build_object('ok', false, 'error', 'bad_setting'); end if;
  if p_key = 'parents_group_link' and v is not null and v !~ '^https://(chat\.whatsapp\.com|whatsapp\.com/channel)/' then
    return json_build_object('ok', false, 'error', 'bad_group_link');
  end if;
  if p_key = 'admin_whatsapp' and v is not null then
    v := regexp_replace(v, '[^0-9]', '', 'g');
    if length(v) < 8 or length(v) > 15 then return json_build_object('ok', false, 'error', 'bad_whatsapp'); end if;
  end if;
  if p_key in ('arabic_schools', 'new_games') and v is not null and v <> 'on' then
    return json_build_object('ok', false, 'error', 'bad_setting');
  end if;
  insert into public.settings(key, value, updated_at) values (p_key, v, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- 5. Set today's practice
-- ---------------------------------------------------------------------

-- The topics a teacher can set for a class: every skill a game practises, with the
-- class's own curriculum codes. "in_class" marks the skills of the class's curriculum class.
create or replace function public.class_topics(p_token text, p_class_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id); s public.schools;
begin
  select * into s from public.schools where id = c.school_id;
  return json_build_object(
    'curriculum', s.curriculum, 'curriculum_class', c.curriculum_class,
    'today', (select json_build_object('skills', p.skills, 'games', p.games, 'set_at', p.set_at)
                from public.class_practice p where p.class_id = c.id and p.day = public._today()),
    'skills', coalesce((select json_agg(x order by (x->>'sort')::int) from (
      select json_build_object('id', sk.id, 'subject', sk.subject, 'strand', sk.strand, 'name', sk.name, 'sort', sk.sort,
        'refs', coalesce((select json_agg(distinct ct.ref) from public.curriculum_tags ct
                           where ct.skill_id = sk.id and ct.curriculum = s.curriculum
                             and (c.curriculum_class is null or ct.class_label = c.curriculum_class)), '[]'::json),
        'in_class', case when s.curriculum = 'garaad' or c.curriculum_class is null then null
                         else exists (select 1 from public.curriculum_tags ct where ct.skill_id = sk.id
                                       and ct.curriculum = s.curriculum and ct.class_label = c.curriculum_class) end,
        'games', (select json_agg(json_build_object('game', gs.game, 'from', gs.level_from, 'to', gs.level_to) order by gs.game, gs.level_from)
                    from public.game_skills gs where gs.skill_id = sk.id)) as x
      from public.skills sk
      where exists (select 1 from public.game_skills gs where gs.skill_id = sk.id)) q), '[]'::json));
end $$;

-- p_skills empty: clears today's practice. p_games: the game ids the app picked for the topics.
create or replace function public.class_set_practice(p_token text, p_class_id uuid, p_skills text[], p_games text[]) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id);
begin
  if coalesce(array_length(p_skills, 1), 0) = 0 then
    delete from public.class_practice where class_id = c.id and day = public._today();
    return json_build_object('ok', true, 'cleared', true);
  end if;
  insert into public.class_practice(class_id, day, skills, games, set_by)
  values (c.id, public._today(), p_skills[1:6], coalesce(p_games[1:12], '{}'), t.teacher_id)
  on conflict (class_id, day) do update set skills = excluded.skills, games = excluded.games, set_by = excluded.set_by, set_at = now();
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- 6. The teacher's class page
-- ---------------------------------------------------------------------

-- Today: who played, minutes, stars, needs help, ready to move up.
create or replace function public.class_today(p_token text, p_class_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id);
  v_from timestamptz := public._at(public._today());
begin
  return (
    with kids as (select ch.* from public.children ch where ch.class_id = c.id),
    r as (select rr.* from public.rounds rr join kids k on k.id = rr.child_id where rr.played_at >= v_from and rr.game <> 'placement'),
    m as (select se.child_id, sum(coalesce(se.minutes, 0)) as minutes from public.sessions se join kids k on k.id = se.child_id
           where se.started_at >= v_from group by se.child_id),
    per as (
      select k.id, k.name, k.avatar, k.team_id,
             coalesce(sum(r.questions), 0) as q, coalesce(sum(r.right_first_time), 0) as rf,
             coalesce(sum(r.stars), 0) as stars, coalesce(sum(r.hints_used), 0) as hints, count(r.id) as rounds,
             coalesce(max(m.minutes), 0) as minutes, max(r.played_at) as last
        from kids k left join r on r.child_id = k.id left join m on m.child_id = k.id
       group by k.id, k.name, k.avatar, k.team_id),
    best as (   -- each child's strongest skill today (for "ready to move up")
      select distinct on (r.child_id) r.child_id, sk.id as skill_id, sk.name as skill_name
        from r join public.game_skills gs on gs.game = r.game and r.level between gs.level_from and gs.level_to
               join public.skills sk on sk.id = gs.skill_id
       group by r.child_id, sk.id, sk.name
      having sum(r.questions) >= 5
       order by r.child_id, sum(r.right_first_time)::numeric / nullif(sum(r.questions), 0) desc, sum(r.questions) desc)
    select json_build_object(
      'date', public._today(),
      'practice', (select json_build_object('skills', p.skills, 'games', p.games) from public.class_practice p
                    where p.class_id = c.id and p.day = public._today()),
      'played', (select count(*) from per where rounds > 0),
      'children', (select count(*) from per),
      'minutes', (select coalesce(sum(minutes), 0) from per),
      'stars', (select coalesce(sum(stars), 0) from per),
      'questions', (select coalesce(sum(q), 0) from per),
      'right_pct', (select round(100.0 * sum(rf) / nullif(sum(q), 0)) from per),
      'kids', coalesce((select json_agg(json_build_object('id', id, 'name', name, 'avatar', avatar, 'questions', q,
                  'right_pct', round(100.0 * rf / nullif(q, 0)), 'stars', stars, 'hints', hints, 'rounds', rounds,
                  'minutes', minutes, 'last', last) order by rounds = 0, name) from per), '[]'::json),
      'needs_help', public.class_needs_help(p_token, c.id),
      'ready', coalesce((select json_agg(json_build_object('id', per.id, 'name', per.name, 'avatar', per.avatar,
                  'right_pct', round(100.0 * per.rf / nullif(per.q, 0)), 'skill', b.skill_name) order by per.rf::numeric / per.q desc)
                from per left join best b on b.child_id = per.id
               where per.q >= 10 and per.rf::numeric / per.q >= 0.85), '[]'::json)));
end $$;

-- The skills grid: each child against each skill practised in the last p_days days,
-- and each child's week against the week before.
create or replace function public.class_skills(p_token text, p_class_id uuid, p_days int default 7) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id);
  v_days int := greatest(1, least(coalesce(p_days, 7), 60));
  v_from timestamptz := public._at(public._today() - (v_days - 1));
  v_prev timestamptz := public._at(public._today() - (2 * v_days - 1));
begin
  return (
    with kids as (select ch.id, ch.name, ch.avatar from public.children ch where ch.class_id = c.id),
    r as (select rr.* from public.rounds rr join kids k on k.id = rr.child_id where rr.played_at >= v_prev and rr.game <> 'placement'),
    cells as (
      select r.child_id, gs.skill_id, sum(r.questions) as q, sum(r.right_first_time) as rf, max(r.played_at) as last
        from r join public.game_skills gs on gs.game = r.game and r.level between gs.level_from and gs.level_to
       where r.played_at >= v_from
       group by r.child_id, gs.skill_id),
    wk as (
      select k.id,
             coalesce(sum(r.questions) filter (where r.played_at >= v_from), 0) as q,
             coalesce(sum(r.right_first_time) filter (where r.played_at >= v_from), 0) as rf,
             coalesce(sum(r.stars) filter (where r.played_at >= v_from), 0) as stars,
             coalesce(sum(r.questions) filter (where r.played_at < v_from), 0) as pq,
             coalesce(sum(r.right_first_time) filter (where r.played_at < v_from), 0) as prf
        from kids k left join r on r.child_id = k.id group by k.id),
    mins as (
      select k.id,
             coalesce(sum(se.minutes) filter (where se.started_at >= v_from), 0) as m,
             coalesce(sum(se.minutes) filter (where se.started_at >= v_prev and se.started_at < v_from), 0) as pm
        from kids k left join public.sessions se on se.child_id = k.id and se.started_at >= v_prev group by k.id)
    select json_build_object(
      'days', v_days,
      'skills', coalesce((select json_agg(json_build_object('id', sk.id, 'name', sk.name, 'strand', sk.strand, 'subject', sk.subject) order by sk.sort)
                  from public.skills sk where sk.id in (select skill_id from cells)), '[]'::json),
      'cells', coalesce((select json_agg(json_build_object('child', child_id, 'skill', skill_id, 'q', q, 'rf', rf)) from cells), '[]'::json),
      'kids', coalesce((select json_agg(json_build_object('id', k.id, 'name', k.name, 'avatar', k.avatar,
                  'q', w.q, 'rf', w.rf, 'stars', w.stars, 'pq', w.pq, 'prf', w.prf, 'minutes', mi.m, 'prev_minutes', mi.pm) order by k.name)
                from kids k join wk w on w.id = k.id join mins mi on mi.id = k.id), '[]'::json)));
end $$;

-- ---------------------------------------------------------------------
-- 7. Competition: class goal, teams, badges, the school league
-- ---------------------------------------------------------------------

-- p_options: {"competition": false} switches the class's competition off;
-- {"names_on_screen": false} hides children's names on the classroom screen.
create or replace function public.class_set_options(p_token text, p_class_id uuid, p_options jsonb) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id); o jsonb := c.options; k text;
begin
  foreach k in array array['competition','names_on_screen'] loop
    if p_options ? k then o := o || jsonb_build_object(k, coalesce((p_options ->> k)::boolean, true)); end if;
  end loop;
  update public.classes set options = o where id = c.id;
  return json_build_object('ok', true, 'options', o);
end $$;

-- Splits the class into p_count teams (2–4), mixing children of each expected level.
create or replace function public.class_make_teams(p_token text, p_class_id uuid, p_count int) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id);
  n int := greatest(2, least(coalesce(p_count, 2), 4));
  names text[] := array['Lions','Eagles','Camels','Gazelles'];
  colours text[] := array['#E8862A','#3657E0','#B7860A','#22955A'];
  ids uuid[] := '{}'; v uuid; i int; rec record; pos int := 0;
begin
  update public.children set team_id = null where class_id = c.id;
  delete from public.class_teams where class_id = c.id;
  for i in 1..n loop
    insert into public.class_teams(class_id, name, colour, sort) values (c.id, names[i], colours[i], i) returning id into v;
    ids := ids || v;
  end loop;
  for rec in select id from public.children where class_id = c.id
              order by case expected_group when 'very_smart' then 1 when 'medium' then 2 when 'lowest' then 3 else 4 end, random() loop
    update public.children set team_id = ids[(pos % n) + 1] where id = rec.id;
    pos := pos + 1;
  end loop;
  return json_build_object('ok', true);
end $$;

create or replace function public.class_set_team(p_token text, p_child_id uuid, p_team_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); ch public.children;
begin
  if t.role not in ('teacher','principal') then raise exception 'not_allowed'; end if;
  select * into ch from public.children where id = p_child_id and school_id = t.school_id;
  if not found then raise exception 'not_in_school'; end if;
  if p_team_id is not null and not exists (select 1 from public.class_teams where id = p_team_id and class_id = ch.class_id) then
    return json_build_object('ok', false, 'error', 'bad_team');
  end if;
  update public.children set team_id = p_team_id where id = ch.id;
  return json_build_object('ok', true);
end $$;

create or replace function public.class_set_goal(p_token text, p_class_id uuid, p_target int) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id);
begin
  if p_target is null or p_target < 1 or p_target > 100000 then return json_build_object('ok', false, 'error', 'bad_goal'); end if;
  insert into public.class_goals(class_id, week_start, target_stars) values (c.id, public._week_start(), p_target)
  on conflict (class_id, week_start) do update set target_stars = excluded.target_stars;
  return json_build_object('ok', true);
end $$;

-- This week (from Monday): the class goal, the teams, and the week's badges.
-- Badges go to different children: most improved, longest streak, most practice, star collector.
create or replace function public.class_competition(p_token text, p_class_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id);
  v_ws date := public._week_start(); v_from timestamptz; v_prev timestamptz;
  v_badges jsonb := '[]'::jsonb; used uuid[] := '{}'; b record; v_goal int; v_kids int;
begin
  v_from := public._at(v_ws); v_prev := public._at(v_ws - 7);
  select count(*) into v_kids from public.children where class_id = c.id;
  select target_stars into v_goal from public.class_goals where class_id = c.id and week_start = v_ws;
  v_goal := coalesce(v_goal, greatest(20, v_kids * 15));   -- default: 15 stars a child

  create temporary table if not exists _cw (id uuid, name text, avatar text, team_id uuid, q int, rf int, stars int,
    three int, pq int, prf int, streak int) on commit drop;
  truncate _cw;
  insert into _cw
  select ch.id, public._first(ch.name), ch.avatar, ch.team_id,
         coalesce(sum(r.questions) filter (where r.played_at >= v_from), 0),
         coalesce(sum(r.right_first_time) filter (where r.played_at >= v_from), 0),
         coalesce(sum(r.stars) filter (where r.played_at >= v_from), 0),
         count(r.id) filter (where r.played_at >= v_from and r.stars = 3),
         coalesce(sum(r.questions) filter (where r.played_at < v_from), 0),
         coalesce(sum(r.right_first_time) filter (where r.played_at < v_from), 0),
         0
    from public.children ch
    left join public.rounds r on r.child_id = ch.id and r.played_at >= v_prev and r.game <> 'placement'
   where ch.class_id = c.id
   group by ch.id, ch.name, ch.avatar, ch.team_id;

  -- days in a row with play, ending today or yesterday
  update _cw w set streak = s.n from (
    select d.child_id, count(*) as n from (
      select child_id, day, day - (row_number() over (partition by child_id order by day))::int as grp
        from (select distinct r.child_id, (r.played_at at time zone 'Africa/Mogadishu')::date as day
                from public.rounds r join public.children ch on ch.id = r.child_id
               where ch.class_id = c.id and r.played_at >= public._at(public._today() - 60)) x) d
     group by d.child_id, d.grp
    having max(d.day) >= public._today() - 1) s
   where s.child_id = w.id;

  for b in select * from (values (1, 'improved', 'Most improved'), (2, 'streak', 'Longest streak'),
                                 (3, 'practice', 'Most practice'), (4, 'stars', 'Star collector')) v(o, kind, label) order by o loop
    declare w record;
    begin
      select x.id, x.name, x.avatar, x.score into w from (
        select id, name, avatar, case b.kind
                 when 'improved' then case when q >= 10 and pq >= 10 and rf::numeric / q > prf::numeric / pq
                                           then round(100.0 * rf / q - 100.0 * prf / pq) end
                 when 'streak'   then case when streak >= 2 then streak end
                 when 'practice' then case when q >= 10 then q end
                 when 'stars'    then case when three >= 1 then three end end as score
          from _cw where not (id = any(used))) x
       where x.score is not null order by x.score desc, x.name limit 1;
      if w.id is not null then
        used := used || w.id;
        v_badges := v_badges || jsonb_build_object('kind', b.kind, 'label', b.label, 'child_id', w.id, 'name', w.name,
                                                   'avatar', w.avatar, 'score', w.score);
      end if;
    end;
  end loop;

  return json_build_object(
    'week_start', v_ws, 'options', c.options,
    'goal', v_goal, 'goal_set', exists (select 1 from public.class_goals where class_id = c.id and week_start = v_ws),
    'class_stars', (select coalesce(sum(stars), 0) from _cw),
    'played', (select count(*) from _cw where q > 0),
    'teams', coalesce((select json_agg(json_build_object('id', tm.id, 'name', tm.name, 'colour', tm.colour,
                  'stars', (select coalesce(sum(stars), 0) from _cw where team_id = tm.id),
                  'members', (select coalesce(json_agg(json_build_object('id', id, 'name', name, 'avatar', avatar) order by name), '[]'::json)
                                from _cw where team_id = tm.id)) order by tm.sort)
                from public.class_teams tm where tm.class_id = c.id), '[]'::json),
    'no_team', (select coalesce(json_agg(json_build_object('id', id, 'name', name) order by name), '[]'::json) from _cw where team_id is null),
    'badges', v_badges);
end $$;

-- The principal's class league: each class's stars, practice and players this week.
create or replace function public.school_league(p_token text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v_from timestamptz := public._at(public._week_start());
begin
  if t.role not in ('teacher','principal') then raise exception 'not_allowed'; end if;
  return json_build_object('week_start', public._week_start(), 'classes', coalesce((select json_agg(x order by (x->>'stars')::int desc, x->>'name') from (
    select json_build_object('id', c.id, 'name', c.name,
      'children', (select count(*) from public.children ch where ch.class_id = c.id),
      'played', (select count(distinct r.child_id) from public.rounds r join public.children ch on ch.id = r.child_id
                  where ch.class_id = c.id and r.played_at >= v_from and r.game <> 'placement'),
      'stars', (select coalesce(sum(r.stars), 0) from public.rounds r join public.children ch on ch.id = r.child_id
                 where ch.class_id = c.id and r.played_at >= v_from and r.game <> 'placement'),
      'questions', (select coalesce(sum(r.questions), 0) from public.rounds r join public.children ch on ch.id = r.child_id
                     where ch.class_id = c.id and r.played_at >= v_from and r.game <> 'placement'),
      'minutes', (select coalesce(sum(se.minutes), 0) from public.sessions se join public.children ch on ch.id = se.child_id
                   where ch.class_id = c.id and se.started_at >= v_from)) as x
    from public.classes c where c.school_id = t.school_id and c.active
      and coalesce((c.options ->> 'competition')::boolean, true)) q), '[]'::json));
end $$;

-- ---------------------------------------------------------------------
-- 8. Who may call what: the app calls these with the public key
-- ---------------------------------------------------------------------

revoke execute on function
  public._today(), public._at(date), public._week_start(date),
  public._school_class(public.tokens, uuid), public._first(text)
from public, anon, authenticated;

revoke execute on function
  public.school_options(text),
  public.school_set_options(text, text, text, jsonb),
  public.admin_school_options(text),
  public.admin_set_school_features(text, uuid, jsonb),
  public.public_settings(),
  public.admin_set_setting(text, text, text),
  public.class_topics(text, uuid),
  public.class_set_practice(text, uuid, text[], text[]),
  public.class_today(text, uuid),
  public.class_skills(text, uuid, int),
  public.class_set_options(text, uuid, jsonb),
  public.class_make_teams(text, uuid, int),
  public.class_set_team(text, uuid, uuid),
  public.class_set_goal(text, uuid, int),
  public.class_competition(text, uuid),
  public.school_league(text)
from public;

grant execute on function
  public.school_options(text),
  public.school_set_options(text, text, text, jsonb),
  public.admin_school_options(text),
  public.admin_set_school_features(text, uuid, jsonb),
  public.public_settings(),
  public.admin_set_setting(text, text, text),
  public.class_topics(text, uuid),
  public.class_set_practice(text, uuid, text[], text[]),
  public.class_today(text, uuid),
  public.class_skills(text, uuid, int),
  public.class_set_options(text, uuid, jsonb),
  public.class_make_teams(text, uuid, int),
  public.class_set_team(text, uuid, uuid),
  public.class_set_goal(text, uuid, int),
  public.class_competition(text, uuid),
  public.school_league(text)
to anon, authenticated;

commit;

-- Done. Quick check (optional), in a new query:
--   select count(*) from public.skills;            -- 96
--   select count(*) from public.game_skills;       -- 84
--   select name, curriculum, features from public.schools;
