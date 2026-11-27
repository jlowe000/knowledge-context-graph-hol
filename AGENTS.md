# Repository guidance

## Oracle APEX skills

Use the repository-local Oracle skills for APEXlang authoring, validation and packaging:

- [Version router](.agents/skills/apexlang-router/SKILL.md)
- [APEX 26.1 component inventory](.agents/skills/apexlang-26-1-inventory/SKILL.md)
- [APEX 26.1 examples](.agents/skills/apexlang-26-1-example-applications/SKILL.md)
- [Compilation](.agents/skills/apexlang-compile/SKILL.md)
- [Deployment](.agents/skills/apexlang-deploy/SKILL.md)

The current target is APEX 26.1; confirm the source's `.apex/apexlang.json` and the target engine before changing that assumption. Do not apply the upstream router's unknown-version 26.2 fallback to this known 26.1 application. Read only the component references needed for the change.

These are unchanged third-party files pinned to an upstream commit. Keep local integration guidance here and in [the skills guide](docs/oracle-apex-skills.md); retain the licence, attribution and provenance under `third-party/oracle-skills/` when updating them.

## Project deployment workflow

Keep APEXlang as the maintained application source. Generate database changes from the existing immutable migration contract and retain the separate clean-install and upgrade paths.

The upstream deployment helper is a reference, not this project's default deployment command. Use the documented SQLcl launcher and private saved connections for development. Do not write populated connection strings, wallet details, passwords or private keys into source, scripts, exports or logs.

For APEX-led acceptance, test the actual application ZIP through App Builder and execute its guarded Supporting Objects flow. Native directory or ZIP validation alone does not prove browser installation, model connectivity or learner readiness. Preserve the minimal reviewed deployment metadata needed by the native importer; exclude credentials and target-specific connection settings.

Select the intended schema, workspace and application ID explicitly before deployment. Follow the current task's preservation scope and test existing data before and after an upgrade. A destructive fresh install is not recovery for an interrupted installation. Follow the release packaging process rather than merging developer tools or skills into the learner distribution indiscriminately.
