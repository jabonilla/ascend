"""P5 — the sender-facing application layer.

Server surfaces only. The native screens (P5.2) are deliberately not built: the build
guide says to build them against ``docs/design-system.md``, which was not supplied to
this build (see ``docs/COMPANION-DOCS.md``). Screens built against an invented visual
language would have to be thrown away, and the API they will call is here and tested.
"""

from iwp.app.auth import (
    AssuranceLevel,
    AuthError,
    StepUpRequired,
    authorize_approval,
    required_assurance_for,
)
from iwp.app.disclosures import (
    CancellationWindow,
    Disclosure,
    Receipt,
    cancellation_window,
    disclosure_for,
    issue_receipt,
    receipt_for_transaction,
    record_disclosure,
    render_disclosure,
)

__all__ = [
    "AssuranceLevel",
    "AuthError",
    "CancellationWindow",
    "Disclosure",
    "Receipt",
    "StepUpRequired",
    "authorize_approval",
    "cancellation_window",
    "disclosure_for",
    "issue_receipt",
    "receipt_for_transaction",
    "record_disclosure",
    "render_disclosure",
    "required_assurance_for",
]
