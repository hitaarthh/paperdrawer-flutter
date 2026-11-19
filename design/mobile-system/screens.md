# Screen recipes

How the components build the app's main screens. The web designs on paperdrawer.app are the source for content and states; these recipes adapt them to a phone.

## Home

1. Show the current date, the number of deadlines due soon, and the number of open claims above “Coming up.”
2. Show the two closest upcoming deadlines as tickets. Use signal orange for the first and paper for the second. Today uses “TODAY.” Future counts exclude the current day. More deadlines link to Vault with Due soon selected.
3. Show open claims with the latest entry and the follow-up date, or “No follow-up set.” With no open claims, point to Vault. Keep settled ledgers available through Claim history.
4. Let the list scroll behind the dock. Use the measured bottom inset so the last row can move above it.

## Vault

1. Show the brand bar, “The vault,” search, and the underlined filters All · Due soon · In claim · Covered · Ended.
2. Sort document cards by the nearest date. Show the Base limit notice when the drawer is full.
3. For an empty Vault, use a welcome receipt with “Scan your first bill.” Policy, vehicle and agreement shortcuts open Add with the corresponding category selected.
4. After a local save, show the new card under “Just added.” Offer Undo and use the next future planned reminder when one exists.

## Add flow

1. The lime Add action opens “What are you adding?” Choose Bill & warranty, Insurance policy, Vehicle papers or Agreement, then Take a photo, Upload a file or Type it in. Manual entry starts with a blank form for the chosen category.
2. Show a lime frame and shutter in the camera. A captured preview can be retaken or confirmed with Done.
3. Show the original and progress while reading. Skip to review is available immediately. An unreadable original still opens review with editable fields.
4. “Check what we read” keeps the original available for retaking. Mark recognized facts and provide editable return and warranty dates. A component warranty is tracked separately. Keep the form scrollable and the Save to vault action visible.

## Item detail

1. Show the original, saved facts and coverage windows. Include a separate meter for component coverage when supplied.
2. “Open a claim” creates or opens a ledger from the item. Existing open claims offer “View claim ledger.”

## Claim ledger

1. Show an Open or Settled stamp, a follow-up row and “Add an entry” for open claims.
2. The paper log shows newest entries first. An entry shows the date, type, what happened and the reference number when supplied.
3. Below the log, show attached files, Share as PDF and Mark settled. Settling records the outcome and clears the active follow-up.
4. The entry sheet offers Call, Email, Visit, Note and Refund. Record what happened, choose a date and add a reference, photo or future follow-up time as needed.

## Settings

- **Grouped ListRows:**
  - Account: name, email, password.
  - Reminders: Email on/off, Remind me, WhatsApp (Pro).
  - Plan: Base, "Join the Pro waitlist".
  - Your data: Export everything, Delete account in `signal`.
  - About: Privacy, Terms, Version.
- **Footer** in `footnote` `text-muted`: "PaperDrawer gives guidance, not legal advice."

## Sign in and sign up

- **Layout:** one column. Mark at top left, then a `title-1` headline: "Never lose a claim to a missing bill."
- **Form:** TextFields for email and password, a primary Button, and a text Button "Forgot password?".
- **Platform sign-in:** offer Sign in with Apple on iOS if any third-party sign-in is ever added (App Store rule).

## Notifications (reminders)

- **Title:** the item and the fact ("Washing machine warranty ends in 22 days").
- **Body:** the action ("Book a service visit before 10 Dec").
- **Tap:** opens Item detail or the claim ledger for a follow-up.
- **Android:** notification icon = the mark in white, with an accent colour of `lime`.
- **iOS:** time-sensitive interruption level only for the final reminder before a return window closes.
