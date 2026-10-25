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

- **Family:** a free family account. The parent registers with their name, country and region (drop-down lists of every country and its official regions, in `countries-regions.json`), a typed location, their WhatsApp number (the dialling code follows the country), a 4-number PIN, and a tick box to join the parents' WhatsApp group. On another phone they log in with the WhatsApp number and PIN. Old family codes still work, and phones that already had children on them keep playing without registering.
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

## Database

The scripts in `database/` set up Supabase. Run them in order in the Supabase SQL Editor: `01-schema.sql`, then `02-progress-and-offline.sql`, then `03-design-features.sql` (owl avatars, themes, hints bought with stars, parent phone, assessments, needs-help list, weekly report and pilot results), then `04-family-registration.sql` (free family accounts, family login with WhatsApp and PIN, admin family tools and WhatsApp settings). The app holds only the publishable key; every read and write goes through database functions that check the login.
