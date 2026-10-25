# Tiri

Maths and English games for children aged 3 to 12. *Tiri* is Somali for "count".

**Play:** https://amousamf.github.io/tiri/

- Add each child by name and age; the games for their age group appear automatically.
- 10 games per age group (3–5, 6–8, 9–12), each with 10 levels that unlock in order.
- Questions are read aloud for younger children.
- **English:** a Maths / English switch on each child's games page, with 21 games in five steps: 1 *Listening ears*, 2 *Sound play*, 3 *Words and letters* (Opposites, Word Sort, Letter Hunt, Trace the Trail), 4 *Reading* (Caption Catch, Yes or No Island, Story Steps, Read and Answer) and 5 *Writing* (Missing Letter, Spell the Picture, Spelling Bee, Sentence Builder, Fix-It Doctor). Younger children see Steps 1–3 first; ages 6–12 see Reading and Writing first. Every word learned grows a flower in the child's Word Garden.
- Speaking games use the microphone. Recordings stay on the phone and are never uploaded; a grown-up can always confirm an answer.
- Installs to the phone's home screen and works offline after the first visit.
- Progress stays on the device. Parents can send results by email or WhatsApp from the Parent area (press and hold to open).

## Home page: School or Family

The first screen asks where the phone is used.

- **Family:** enter the family code from the admin once; then the family app works as before. Phones that already had children on them keep playing without a code.
- **School:** enter the school code, then log in with a phone number (+252) and a 4-number PIN. New teachers register themselves.

## School mode

1. Choose **In-class exercise** (**Send homework** is shown but not active yet).
2. Pick a class: KG1, KG2, KG3, Standard 1 or Standard 2 (the admin can add more).
3. Pick the child, or **Add child** with name, age and expected performance (very smart, medium or lowest).
4. A new child does an 8-question **starting exercise** from the class's games. It sets the starting level and saves a baseline score.
5. The child plays that class's Maths and English games, with levels capped to suit the class.

Results are saved to the school database (Supabase). If the internet drops, they wait on the phone and are sent when it returns. A child keeps their place on any teacher's phone.

The **principal** logs in the same way (the admin sets the role) and can open every class to try the games; nothing they play is saved.

The **admin** screen (link on the first page) creates school and family codes, adds classes, resets teacher PINs and sets the principal.

## Database

The scripts in `database/` set up Supabase. Run them in order in the Supabase SQL Editor: `01-schema.sql`, then `02-progress-and-offline.sql`. The app holds only the publishable key; every read and write goes through database functions that check the login.
