# Screen recipes

How the components build the app's main screens. The web designs on paperdrawer.app are the source for content and states; these recipes adapt them to a phone.

## Vault (tab 1)

1. **NavBar:**
   - iOS: large title "Vault" with the ScanAction trailing.
   - Android: app bar "Vault" plus the ScanAction FAB.
2. **CountdownTicket** for the single most urgent deadline, if one is due within 14 days.
3. **Chip** row of filters (All · Due · In claim · Covered · Expired), scrolling sideways, with `space-5` / `space-4` edge padding.
4. **Cards** in one column, sorted by days left: a ReceiptCard for bills, a DocumentCard for policies, PUC and agreements, `space-3` apart.
5. **LimitNotice** above the list when the user is at 25 of 25 items on Base.
6. **Empty state:** a dashed `line` tile reading "Your drawer is empty", with the body text "Scan your first bill. We'll read the dates." and a primary Button "Scan a bill".

## Add flow

1. **Scan** opens the BottomSheet: Scan with camera / Upload a photo or PDF / Type it in.
2. **Camera:**
   - Full-screen with a dark ground and a lime corner frame (the Scan icon's corners at 64pt).
   - The shutter is a 72pt lime circle; there's a "Done" text button.
   - Multi-page capture is allowed.
3. **Reading:** a paper receipt prints in from the top with a "READING YOUR BILL" `label`. No spinners. Keep it under 3 seconds or show progress.
4. **Check the details:** TextFields, each tagged "READ FROM BILL" in `lime`. Then Item type (Chip choice), Warranty, Return window and Reminder ListRows.
5. **Save:** a primary Button "Save to drawer". A stamp lands on the new card, followed by the Snackbar "Saved to your drawer · UNDO".

## Item detail

1. **NavBar:**
   - iOS: back "Vault".
   - Android: arrow back.
   - Share and overflow actions on both.
2. The card at full width (receipt or document) at the top.
3. **Meters** on dark for each window (Return, Warranty, Renewal, Service).
4. **Documents strip:** thumbnails of the original photos and PDFs on `surface-2`, 72pt, `radius-sm`.
5. **Actions:** primary Button "Start a claim", secondary "Export claim kit".

## Claims (tab 2)

1. **Header:** Paper Drawer brand bar with the Scan or add action. Show the open, settled and needs-action counts above the Claims title.
2. **Needs You:** when a claim needs attention, link to the oldest such claim with a lime ticket and the reason it needs attention.
3. **Filters:** underlined Open, Settled and All tabs with live counts. List claims that need attention first, then other open claims by oldest reply. List settled claims newest first.
4. **Claim rows on `surface-2`:** display the claim day beside a dashed rule, the claim type and item, title, current step, next action and a status stamp. Shared claims can also show DOCS ASKED.
5. **Claim detail:**
   - A ClaimLadder with the current step marked.
   - The drafted message in a `paper-2` document, with Copy and Share buttons (the user sends it themselves).
   - A log of what happened, with dates in mono.

## Settings (tab 3)

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
- **Tap:** opens Item detail.
- **Android:** notification icon = the mark in white, with an accent colour of `lime`.
- **iOS:** time-sensitive interruption level only for the final reminder before a return window closes.
