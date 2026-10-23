# BOKAN Proforma Maker — Standalone Copy

This file is a separate, local-use copy of the Proforma screen from BOKAN ERP V6.7. The original ERP source and Proforma markup/functions were preserved; only the external config reference was replaced with a safe inline preview configuration, and a small wrapper opens the existing Proforma tab while hiding unrelated ERP navigation.

## Use

1. Download `BOKAN_Proforma_Maker_Standalone.html` to your computer.
2. Open it with Microsoft Edge or Google Chrome.
3. Confirm you have an internet connection so the existing Tailwind/Supabase CDN scripts can load.
4. Create the Proforma as usual. The existing **+ Add Line Item** control supports multiple rows.
5. Click **Generate & Save Proforma**, review the output, then use the existing print control and choose **Save as PDF** in the print dialog.

## Important limitations

- This is for temporary local customer-facing use while the full ERP migration is unfinished.
- It runs in preview mode: it does not connect to Supabase, does not write to the live ERP database, and does not provide shared/cloud saved history.
- Any browser-local saved records may be tied to that browser profile/file origin. Save each final Proforma as a PDF and keep a separate business copy.
- Do not enter confidential information you are not comfortable storing in the local browser.
- Do not publish this file as a hosted production app. Hosted use remains blocked until authentication, database schema, RLS, and persistence are approved.
- The full ERP source was not changed by creating this standalone copy.
