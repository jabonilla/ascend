"""Settlement adapters.

**The only place in the codebase permitted to name a settlement partner.** A guardrail
test greps for brand tokens outside this directory and fails the build if it finds one
(CLAUDE.md rule 7).

Importing this package registers every adapter it ships with.
"""

from iwp.settlement.adapters import mock

__all__ = ["mock"]
