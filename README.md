# Garaad

Maths and English games for children aged 3 to 12. *Garaad* is Somali for "wisdom". (The app was called Tiri before.)

The mascot is Garaad, a wise owl whose eyes are the double "aa" of the name. Brand files and decisions are in the Kids Learning App project (`claude/garaad-brand.md`).

**Play:** https://garaad.app (the old address, https://amousamf.github.io/Tiri/, moves each phone's saved games here once, then forwards). About and Privacy pages: `about.html`, `privacy.html`.

- The first time it opens on a phone, three short welcome screens introduce the owl, what *garaad* means and the app.
- Add each child by name, age and owl (16 owls: four colours, each with a cap, glasses, a star or a bow); the games for their age group appear automatically.
- Each child picks a colour theme: Savanna sun (default), Ocean blue or Night sky. Grown-up screens use one calm style.
- Stars can be spent on hints: 2 stars remove some wrong answers, or show a first step for typed answers. Answers found after a hint are not counted as right first time.
- 10 games per age group (3–5, 6–8, 9–12), each with 10 levels that unlock in order.
- Questions are read aloud for younger children.
- **English:** a Maths / English switch on each child's games page, with 21 games in five steps: 1 *Listening ears*, 2 *Sound play*, 3 *Words and letters* (Opposites, Word Sort, Letter Hunt, Trace the Trail), 4 *Reading* (Caption Catch, Yes or No Island, Story Steps, Read and Answer) and 5 *Writing* (Missing Letter, Spell the Picture, Spelling Bee, Sentence Builder, Fix-It Doctor). Younger children see Steps 1–3 first; ages 6–12 see Reading and Writing first. Every word learned grows a flower in the child's Word Garden.
- Speaking games use the microphone. Recordings stay on the phone and are never uploaded; a grown-up can always confirm an answer.
- Installs to the phone's home screen and works offline after the first visit.
- Progress stays on the device. Parents can send results by email or WhatsApp from the Parent area (press and hold to open).

## Home page: School or Family

The first screen asks where the phone is used.

- **Family:** a free family account. The parent registers with their name, country and region (drop-down lists of every country and its official regions, in `countries-regions.json`), a typed location, their WhatsApp number (the dialling code follows the country), a 4-number PIN, and a tick box to join the parents' WhatsApp group. On another phone they log in with the WhatsApp number and PIN, and the children and their progress come down from the account. Every child, level played and session is saved to the family's account in Supabase (waiting on the phone when there is no internet). A family phone without an account starts fresh, like a new phone. The Google Sheet is kept only as an archive.
- **School:** enter the school code, then log in with a phone number (+252) and a 4-number PIN. New teachers register themselves.

## School mode

1. Choose **In-class exercise** (**Send homework** is shown but not active yet).
2. Pick a class: KG1, KG2, KG3, Standard 1 or Standard 2 (the admin can add more).
3. Pick the child, or **Add child** with name, age and expected performance (very smart, medium or lowest).
4. A new child does an 8-question **starting exercise** from the class's games. It sets the starting level and saves a baseline score.
5. The child plays that class's Maths and English games, with levels capped to suit the class.

Teachers see a **Needs help today** list (children with low first-try scores or many hints), and a **weekly report** for each child that can be shared with the parent as an image or a WhatsApp message. From the report, the teacher can run the **end-of-pilot check** (the same short check as the starting exercise).

Results are saved to the school database (Supabase). If the internet drops, they wait on the phone and are sent when it returns. A child keeps their place on any teacher's phone.

The **principal** logs in the same way (the admin sets the role) and can open every class to try the games; nothing they play is saved. The principal also sees **Pilot results**: starting check against the latest check, by class and subject, and time learning, with a CSV download that uses child codes instead of names.

The **admin** screen (link on the first page) creates school codes, adds classes, resets teacher and family PINs, sets the principal and shows pilot results for one school or all schools. It lists every registered family (filter by country and region), can block a fake registration, copies the numbers of parents who want the WhatsApp group, and saves the group invite link and the admin's WhatsApp number used by every "Contact admin" link.

## Curriculum, new games and the teacher's class page (update 8)

Switched on per school by the Garaad admin (Admin › each school › New features), all off until then. Families get the new games with Admin › New games for families. To try everything on one phone first, open `garaad.app/?try=new` (`?try=off` stops it).

- **Skill map:** 55 maths and 41 English skills (M01–M55, E01–E41), each tagged to Kenya CBE (PP1–Grade 2), England (Reception–Year 2) and Cambridge Primary (Stages 1–2), and linked to the game levels that practise it. Source: the *Garaad Curriculum Skill Map* sheet.
- **Curriculum (principal):** Manage school › Curriculum sets the school's curriculum, which curriculum class each class is (e.g. KG2 = PP1), and the money games' currency (KSh, $, £ or plain coins). The curriculum changes level caps and games per class (e.g. no carrying yet in Cambridge Stage 2; times tables in Kenya Grade 2).
- **New games (play styles):** one question ladder per skill shown in a play style. *Build It* (Make 10: number bonds to 5, 10, 20, 100; Numbers: tens and ones), *Sort It* (Heavy and Full: heavy/light, full/empty, long/short; Grammar: one/many, is/are, was/were, this/these, that/those, he/she/they, a/an), *Treasure Map* (Numbers: order, count back, count in 2s, 5s, 10s; Days: my day, days, months) and *Owl's Market* (coins, prices, change). All use tap answers, so the level 1 example, hints, the answer after two tries and Review work as in every game.
- **My class today (teacher):** who played, minutes, stars, needs help, ready to move up, a skills grid for the last 7 days with re-teach and small-group advice, this week against last week, and a class report in the curriculum's own levels and codes (Kenyan CBE: Exceeding / Meeting / Approaching / Below expectation).
- **Set today's practice (teacher):** pick up to 3 topics taught today, in the curriculum's words and codes. Each child's *Today's class practice* then plays those games at the child's own level.
- **Competition:** a class star goal (the owl tree), teams of mixed levels, weekly badges that go to different children (most improved, longest streak, most practice, star collector), a classroom screen for a projector (first names only, names can be hidden), a shareable class-tree image, and the principal's class league. Teachers can switch it off per class.

- **Class tablet (update 9):** on the tablet the children will use, a teacher opens the class › Class tablet › *Make this the … tablet*. The tablet then shows only that class: each child taps their own owl and plays, with no PIN. It can only play the children of that class (no adding or changing children, no reports). A teacher logs in on the tablet to leave tablet mode, and can sign out every tablet of a class at once (e.g. a lost tablet). The starting exercise stays on the teacher's phone.
- **Only this practice (update 9):** when setting today's practice the teacher can tick *Only this practice*; children then see just that practice, not the other games, on the class tablet and on the teacher's phone.

The starting exercise and the pilot results are unchanged: they use the class's original games, so pilot scores stay comparable.

## Database

The scripts in `database/` set up Supabase. Run them in order in the Supabase SQL Editor: `01-schema.sql`, then `02-progress-and-offline.sql`, then `03-design-features.sql` (owl avatars, themes, hints bought with stars, parent phone, assessments, needs-help list, weekly report and pilot results), then `04-family-registration.sql` (free family accounts, family login with WhatsApp and PIN, admin family tools and WhatsApp settings), then `05-family-data.sql` (family children and results saved to the account), then the Arabic update 6 (kept in the project docs while Arabic is tested at garaad.app/test/), then `07-school-admin.sql` (the principal is the school admin), then `08-curriculum-and-class.sql` (skill map, school curriculum and settings, feature switches, the teacher's class page and competition), then `09-class-tablet.sql` (class tablets and locking today's practice). The app holds only the publishable key; every read and write goes through database functions that check the login.
