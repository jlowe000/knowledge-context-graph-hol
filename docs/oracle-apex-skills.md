# Oracle APEX skills for dev

This repository includes Oracle's APEXlang guidance for **APEX 26.1** under `.agents/skills/`. It supports maintainers who author and package the application. It does not replace the learner installation instructions or establish that a generated package has passed a database or browser test.

The files are pinned to Oracle Skills commit [`a1b574010841e9141dfeaa210d97c0f2cad5bf8d`](https://github.com/oracle/skills/commit/a1b574010841e9141dfeaa210d97c0f2cad5bf8d), dated 18 November 2026. The upstream directory has changed: use the versioned skills below, rather than the former `apex/apexlang/` location.

## Included guidance

| Skill | Use in this project |
| --- | --- |
| [Version router](../.agents/skills/apexlang-router/SKILL.md) | Select the inventory matching the target APEX major/minor version. |
| [26.1 inventory](../.agents/skills/apexlang-26-1-inventory/SKILL.md) | Look up component names, properties, containment and application file layout. Read the relevant component reference before authoring it. |
| [26.1 examples](../.agents/skills/apexlang-26-1-example-applications/SKILL.md) | Compare complete upstream application trees, including deployment metadata. These are reference applications, not this project's runtime data. |
| [Compile](../.agents/skills/apexlang-compile/SKILL.md) | Understand the native SQLcl validation route and its explicit success marker. |
| [Deploy](../.agents/skills/apexlang-deploy/SKILL.md) | Understand native import and supporting-object installation. Use the project's reviewed target and identity checks for actual deployment. |

The tested platform is APEX 26.1.6. It selects the **26.1** inventory; the upstream inventory and examples identify metadata version `26.1.0+3102`. Patch/build differences do not select another release's skill. Do not fall back to the upstream router's 26.2 default: this repository has an explicit target, and intentionally does not vendor the 26.2 skills. Check the actual target before adopting a later release.

All five directories are retained completely, including referenced component documents, examples and shell helpers. The upstream files are unmodified; local operating guidance belongs in this document and the repository's agent instructions.

## Packaging checks this adds

The [inventory's minimum application layout](../.agents/skills/apexlang-26-1-inventory/SKILL.md#minimal-application-layout-template) includes `application.apx`, `.apex/apexlang.json`, **`deployments/default.json`**, pages and shared components. All three included example applications retain that deployment file. The [smallest example](../.agents/skills/apexlang-26-1-example-applications/assets/example-0/deployments/default.json) contains a runtime debugging setting, without a database endpoint or schema credential.

Consequently, a portable package should preserve the supported deployment structure while removing private target metadata. Do not discard the entire `deployments` directory merely because an engine export can contain environment-specific settings. Do not copy an example's debugging setting into this application without deliberately selecting the intended runtime setting.

The package's own import test must prove that its retained, portable metadata works. These upstream files do **not** document `ORA-06531` as a specific consequence of omitting `default.json`; they are layout evidence, not a diagnosis or acceptance result for that error.

For supporting objects, consult the [supportingObject reference](../.agents/skills/apexlang-26-1-inventory/assets/app/supporting-object/supporting-object.md), [installScript](../.agents/skills/apexlang-26-1-inventory/assets/app/supporting-object/install-script-4970/install-script-4970.md) and [upgradeScript](../.agents/skills/apexlang-26-1-inventory/assets/app/supporting-object/upgrade-script-4975/upgrade-script-4975.md). They distinguish the supporting-object declaration from its install and upgrade script files. The inventory documents `advanced.includeInAppExport = autoInstall`; enable that only within the selected, reviewed installation route. A reference to the `content` property does not replace validation of the engine's split `contentFile` output and every referenced SQL file.

Validate the **complete** packaged application, including supporting declarations and static assets, then test the actual import route. A small identity probe or an offline syntax pass cannot establish that all application scripts execute under the intended identity. Keep the existing fresh/upgrade guards, source hashes, engine provenance, privacy review and browser acceptance described in [APEXlang development](apexlang-development.md).

## Use of the supplied helpers

The compile helper invokes SQLcl without a database login and checks for an explicit validation-success message. A process exit code alone is insufficient. Target-connected validation remains necessary where the local SQLcl metadata differs from the deployed APEX engine.

The deploy helper requires `SQLCL_CONNECTION_STRING`, enables automatic supporting-object installation and imports the application. It is retained as upstream reference, not an instruction to execute it automatically. Use the project's privately configured saved connection and approved, explicitly targeted import workflow; do not put passwords or private wallet details into tracked files or command arguments. Installing these skills does not authorize a database mutation.

## Attribution and updates

Oracle material retains its **UPL 1.0** licence; Jason Lowe's original project work remains MIT. See the [Oracle Skills notice](../third-party/oracle-skills/NOTICE.md), [retained licence](../third-party/oracle-skills/LICENSE.txt) and [file provenance](../third-party/oracle-skills/provenance.json).

For an update, choose and review a specific upstream commit, preserve the applicable licence, install the selected complete skill directories through the skill-installer helper into the repository-local destination, then verify every installed file against that commit and regenerate the provenance record. Review changed syntax and helper behavior before using the new guidance. Do not silently follow `main`, install a different APEX release, alter global agent settings or overwrite the project's deployment workflow.
