"""Channel adapters.

**The only place in the codebase permitted to name a BSP.** A guardrail test greps for
brand tokens outside this directory (CLAUDE.md rule 7). PRD §12: expect to change
providers.
"""

from iwp.channels.adapters import mock_bsp

__all__ = ["mock_bsp"]
