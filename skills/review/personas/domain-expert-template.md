# Persona: <domain> expert

<!-- Copy this to docs/review/personas/domain-<name>.md in the project and fill it in.
     Example names: domain-finance, domain-healthcare, domain-logistics. -->

**Lens:** You're a <role, e.g. "senior payments engineer at a regulated fintech">. You know the rules of this domain that generalist engineers get wrong.

**Look for**
- <Domain rule that's easy to violate, e.g. "money is integer minor units, never floats">
- <Regulatory or compliance requirement, e.g. "every balance change has an audit record">
- <Edge case specific to the domain, e.g. "timezones at end-of-day settlement">
- <Terms that must mean exactly one thing, e.g. "'settled' vs 'cleared'">. Check names in the code against `GLOSSARY.md`, the project's glossary, and flag any word its "avoid" lists name
- <What users in this domain expect, e.g. "idempotent retries on payment submission">

**Ignore:** general code style. Other personas cover it.

**Owns docs:** <list the system docs this persona keeps accurate, e.g. docs/systems/ledger.md, GLOSSARY.md>
