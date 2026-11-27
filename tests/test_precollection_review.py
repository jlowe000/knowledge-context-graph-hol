"""APEX review boundaries for drafts saved before a collection existed.

These authoring checks prevent the token-gated recovery dead end. Native APEX
compilation and browser preview/apply checks remain separate acceptance gates.
"""
from pathlib import Path
import re
import unittest


PAGE = Path(__file__).resolve().parents[1] / "apex/application/pages/p00012-review-context.apx"


def component(source, declaration):
    return source.split(declaration + " (\n", 1)[1].split("\n  )", 1)[0]


class PrecollectionReviewTests(unittest.TestCase):
    def setUp(self):
        self.page = PAGE.read_text(encoding="utf-8")

    def test_collection_recovery_controls_do_not_require_an_existing_preview(self):
        for declaration in ("pageItem P12_COLLECTION", "pageItem P12_TOPICS", "button preview"):
            block = component(self.page, declaration)
            self.assertNotIn("serverSideCondition", block, declaration)
        collection = component(self.page, "pageItem P12_COLLECTION")
        self.assertIn("displayNullValue: true", collection)
        self.assertIn("nullDisplayValue: Choose a ready collection", collection)
        self.assertIn("displayExtraValues: false", collection)
        self.assertIn("kcv_personal_journey.collections(:P12_CONTEXT_ID)", collection)
        topics = component(self.page, "pageItem P12_TOPICS")
        self.assertIn("CASE WHEN :P12_COLLECTION IS NULL", topics)
        self.assertIn("parentRequired: true", topics)
        self.assertIn("itemsToSubmit: P12_CONTEXT_ID", topics)

    def test_initialization_does_not_reset_a_failed_first_submission(self):
        initializer = component(self.page, "process initialize-preview")
        self.assertIn("IF NVL(:P12_INITIALIZED,'N')<>'Y' THEN", initializer)
        self.assertIn(":P12_INITIALIZED:='Y'", initializer)
        self.assertIn("kcv_personal_context_api.get_context(:P12_CONTEXT_ID)", initializer)
        self.assertIn("WHERE graph=:P12_COLLECTION", initializer)
        self.assertIn("IF ready_count<>1 THEN", initializer)
        self.assertIn(":P12_COLLECTION:=NULL; :P12_TOPICS:='[]'", initializer)
        self.assertNotIn("ACTIVE_GRAPH", initializer)
        self.assertNotIn("FETCH FIRST", initializer)
        self.assertIn("SQLCODE IN (-20244,-20247)", initializer)
        # Retrying a rejected selection must not run the default preview again.
        subsequent = initializer.split("ELSIF :P12_TOKEN IS NOT NULL THEN", 1)[1]
        self.assertIn("kcv_personal_journey.get_preview", subsequent)
        self.assertNotIn(":P12_COLLECTION:=", subsequent)
        self.assertNotIn(":P12_TOPICS:=", subsequent)
        marker = component(self.page, "pageItem P12_INITIALIZED")
        self.assertIn("valueProtected: true", marker)
        self.assertIn("checksumRequiredSessionLevel", marker)

    def test_first_refresh_uses_owned_draft_and_retains_rejected_selection(self):
        refresh = component(self.page, "process refresh-preview")
        self.assertIn("IF :P12_COLLECTION IS NULL THEN RAISE_APPLICATION_ERROR", refresh)
        first, existing = refresh.split("IF :P12_TOKEN IS NULL THEN", 1)[1].split(" ELSE\n", 1)
        self.assertIn("kcv_personal_context_api.get_context(:P12_CONTEXT_ID)", first)
        self.assertIn("j.get_object('draft')", first)
        self.assertIn("kcv_personal_journey.get_preview(:P12_CONTEXT_ID,:P12_TOKEN)", existing)
        self.assertIn("j.get_object('after')", existing)
        self.assertIn("p_collection=>:P12_COLLECTION,p_body=>body.to_clob()", refresh)
        self.assertIn("TO_NUMBER(:P12_VERSION)", refresh)
        failure = refresh.split("EXCEPTION WHEN OTHERS THEN", 1)[1]
        self.assertIn("SQLCODE IN (-20244,-20247)", failure)
        self.assertIn(":P12_TOKEN:=NULL", failure)
        self.assertNotIn(":P12_COLLECTION:=", failure)
        self.assertNotIn(":P12_TOPICS:=", failure)

    def test_only_a_reviewed_token_can_be_applied(self):
        for declaration in ("button apply", "region comparison"):
            self.assertIn("plsqlExpression: :P12_TOKEN IS NOT NULL", component(self.page, declaration))
        apply = component(self.page, "process apply-reviewed-context")
        self.assertIn("kcv_personal_journey.get_preview(:P12_CONTEXT_ID,:P12_TOKEN)", apply)
        self.assertIn("JSON_EQUAL(before_body,candidate)", apply)
        self.assertIn("NVL(j.get_string('new_collection'),CHR(1))<>NVL(:P12_COLLECTION,CHR(1))", apply)
        self.assertIn("matches<>1", apply)
        self.assertIn("kcv_personal_journey.apply_preview(:P12_CONTEXT_ID,:P12_TOKEN)", apply)
        for declaration in ("process initialize-preview", "process refresh-preview"):
            block = component(self.page, declaration)
            self.assertNotRegex(block, r"(?i)apply_preview|save_draft|start_conversation|DBMS_CLOUD_AI")


if __name__ == "__main__":
    unittest.main()
