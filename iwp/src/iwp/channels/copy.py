"""Message copy.

Guatemalan Spanish first, written natively rather than translated (PRD §12). English is
the second locale, not the source one — which is why the Spanish strings here are not
mechanical renderings of the English.

Two rules from PRD Feature 4 are enforced in tests rather than trusted:

* a WhatsApp body is at most 3 lines before its buttons;
* approval buttons are exactly ``[Aprobar]`` ``[Ahorita no]``, always in that order.

Messages to a *recipient* open with the sender's name, never the product name (PRD
Feature 0 and Feature 4). That is not branding modesty: a message from an unknown
company asking about money reads as a scam, and one from Marco does not.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Final

__all__ = [
    "APPROVAL_BUTTONS",
    "SMS_KEYWORDS",
    "TEMPLATES",
    "Template",
    "render",
]

#: PRD Feature 4: "Approval buttons are exactly [Aprobar] [Ahorita no], always in that
#: order." "Ahorita no" rather than "Rechazar" because a decline is not a punishment.
APPROVAL_BUTTONS: Final[tuple[str, str]] = ("Aprobar", "Ahorita no")

#: PRD Feature 4: keywords, case-insensitive, Spanish only.
SMS_KEYWORDS: Final[tuple[str, ...]] = ("SI", "NO", "URGENTE", "AYUDA", "RESUMEN")


@dataclass(frozen=True, slots=True)
class Template:
    key: str
    locale: str
    body: str
    buttons: tuple[str, ...] = ()
    #: Whether this must be pre-approved with the BSP before launch. True for anything
    #: that can be sent outside a session window.
    requires_bsp_approval: bool = True


def _t(
    key: str,
    body_es: str,
    body_en: str,
    *,
    buttons: tuple[str, ...] = (),
    requires_bsp_approval: bool = True,
) -> tuple[Template, Template]:
    return (
        Template(key, "es-GT", body_es, buttons, requires_bsp_approval),
        Template(key, "en-US", body_en, buttons, requires_bsp_approval),
    )


_ALL: Final[tuple[Template, ...]] = (
    # -- pairing (PRD Feature 0) -------------------------------------------------------
    # Opens with the sender's name. Never the product name.
    *_t(
        "pairing.invitation",
        "{sender_name} quiere enviarte dinero de forma segura.\nResponde SI para aceptar.",
        "{sender_name} wants to send you money securely.\nReply YES to accept.",
        buttons=("Aceptar", "Ahorita no"),
    ),
    *_t(
        "pairing.accepted_recipient",
        "Listo. Ya estás conectado con {sender_name}.\n"
        "Cuando necesites algo, escribe el monto y te ayudo.",
        "Done. You are connected with {sender_name}.\n"
        "When you need something, send the amount and I will help.",
    ),
    *_t(
        "pairing.accepted_sender",
        "{recipient_name} aceptó. Ya pueden empezar.",
        "{recipient_name} accepted. You can start now.",
    ),
    *_t(
        "pairing.declined_sender",
        "{recipient_name} no aceptó por ahora. Puedes volver a invitarla más adelante.",
        "{recipient_name} did not accept for now. You can invite them again later.",
    ),
    # -- requests (PRD Feature 1) ------------------------------------------------------
    # Two shapes for one question, because PRD Feature 4 asks for two different
    # things: on WhatsApp "all actionable messages use inline buttons — users are
    # never asked to type a response", and on SMS there are no buttons, so the options
    # go in the body. The 3-line budget is a WhatsApp rule, which is exactly why the
    # SMS variant can carry a list and the WhatsApp one cannot.
    *_t(
        "request.ask_emergency_amount",
        "¿De cuánto es la emergencia? Escribe el monto.",
        "How much is the emergency? Send the amount.",
        requires_bsp_approval=False,
    ),
    *_t(
        "request.ask_category_buttons",
        "¿Para qué es?",
        "What is it for?",
        requires_bsp_approval=False,
    ),
    *_t(
        "request.ask_category",
        "¿Para qué es? Responde con el número:\n{category_list}",
        "What is it for? Reply with the number:\n{category_list}",
        requires_bsp_approval=False,
    ),
    *_t(
        "request.submitted",
        "Pedido enviado a {sender_name}: {amount} para {category}.\nTe aviso apenas responda.",
        "Request sent to {sender_name}: {amount} for {category}.\n"
        "I will tell you as soon as they reply.",
        requires_bsp_approval=False,
    ),
    *_t(
        "request.auto_approved",
        "{amount} para {category} va en camino. Estaba dentro de lo acordado.",
        "{amount} for {category} is on its way. It was within your agreement.",
    ),
    *_t(
        "request.needs_approval_sender",
        '{recipient_name} pide {amount} para {category}.\n{note}\n"{description}"',
        '{recipient_name} is asking for {amount} for {category}.\n{note}\n"{description}"',
        buttons=APPROVAL_BUTTONS,
    ),
    *_t(
        "request.emergency_sender",
        '{recipient_name_upper}: {amount} urgente.\n"{description}"',
        '{recipient_name_upper}: {amount} urgent.\n"{description}"',
        buttons=APPROVAL_BUTTONS,
    ),
    *_t(
        "request.approved_recipient",
        "{sender_name} aprobó {amount} para {category}. Ya va en camino.",
        "{sender_name} approved {amount} for {category}. It is on its way.",
    ),
    *_t(
        "request.declined_recipient",
        "{sender_name} no pudo esta vez y te va a escribir.\nMotivo: {reason}",
        "{sender_name} could not this time and will message you.\nReason: {reason}",
    ),
    *_t(
        "request.already_resolved",
        "Ese pedido ya está {status}. No hay nada pendiente por ahora.",
        "That request is already {status}. Nothing is pending right now.",
        requires_bsp_approval=False,
    ),
    *_t(
        "request.none_pending",
        "No hay ningún pedido esperando respuesta.",
        "There is no request waiting for a reply.",
        requires_bsp_approval=False,
    ),
    # -- settlement --------------------------------------------------------------------
    *_t(
        "settlement.settled",
        "Llegaron {amount}. Referencia {reference}.",
        "{amount} arrived. Reference {reference}.",
    ),
    *_t(
        "settlement.failed",
        "El envío de {amount} no se pudo completar y el dinero regresó.\n"
        "Referencia {reference}. No se perdió nada.",
        "The transfer of {amount} could not be completed and the money came back.\n"
        "Reference {reference}. Nothing was lost.",
    ),
    *_t(
        "settlement.partial",
        "De {amount} llegaron {settled}. Estamos siguiendo el resto.\nReferencia {reference}.",
        "Of {amount}, {settled} arrived. We are tracking the rest.\nReference {reference}.",
    ),
    # -- keywords and help (PRD Feature 4) ---------------------------------------------
    # Three lines, like everything else. A help message that overflows the screen is
    # the least helpful place to break the rule (PRD Feature 4).
    *_t(
        "help.keywords",
        "SI o NO para responder un pedido.\n"
        "URGENTE si es una emergencia.\n"
        "RESUMEN para ver lo último.",
        "YES or NO to answer a request.\nURGENT if it is an emergency.\nSUMMARY to see the latest.",
        requires_bsp_approval=False,
    ),
    *_t(
        "help.unrecognized",
        "No entendí eso.\nEscribe SI, NO, URGENTE o RESUMEN.\nAYUDA para ver todo.",
        "I did not understand that.\nWrite YES, NO, URGENT or SUMMARY.\nHELP to see everything.",
        requires_bsp_approval=False,
    ),
    *_t(
        "summary.recent",
        "{summary_lines}",
        "{summary_lines}",
        requires_bsp_approval=False,
    ),
    *_t(
        "emergency.rate_limit_warning",
        "Van {count} pedidos urgentes en poco tiempo. Vale la pena hablarlo entre ustedes.",
        "That is {count} urgent requests in a short time. It is worth talking it over.",
        requires_bsp_approval=False,
    ),
)

TEMPLATES: Final[dict[tuple[str, str], Template]] = {(t.key, t.locale): t for t in _ALL}


def render(key: str, locale: str, **variables: object) -> tuple[str, tuple[str, ...]]:
    """Render a template to a body and its buttons.

    Falls back to Spanish rather than English when a locale is missing: the recipient
    persona defaults to Spanish (PRD Feature 0), and an unexpected English message is
    worse than an expected Spanish one.
    """
    template = TEMPLATES.get((key, locale)) or TEMPLATES.get((key, "es-GT"))
    if template is None:
        raise KeyError(f"no template for {key!r}")
    try:
        body = template.body.format(**variables)
    except KeyError as exc:
        raise KeyError(f"template {key!r} needs variable {exc.args[0]!r}") from None
    return body, template.buttons
