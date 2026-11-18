# DocumentCard

An insurance policy, PUC certificate, rent agreement or AMC, drawn as an official document rather than a receipt.

**How it differs from ReceiptCard**
- **Paper:** `paper-2` instead of `paper`, with `radius-xs` corners.
- **Top edge:** a 6pt double rule in `ink-2` instead of a torn bottom.
- **Dividers:** solid `paper-rule`.
- **Header:** names the document type ("POLICY SCHEDULE", "PUC CERTIFICATE", "RENT AGREEMENT") plus the issuer.
- **Data rows:** RENEWS / VALID TILL, PREMIUM / FEE / DEPOSIT.
- **Stamps:** ACTIVE in place of COVERED, and DUE when renewal is ≤30 days away.

Everything else (meter, footer, hit area, large-text behaviour) is the same as ReceiptCard.
