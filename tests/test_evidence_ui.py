"""Exercise the actual browser link and evidence-locator helpers without a DOM."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('node'), 'Node is needed to execute the browser helpers')
class EvidenceUiTests(unittest.TestCase):
    def evaluate(self, expression):
        source = (ROOT / 'apex/explorer.js').read_text(encoding='utf-8')
        helpers = source[source.index(' function publicUrl('):source.index(' function packetOf(')]
        run = subprocess.run(['node', '-e', helpers + '\nconsole.log(JSON.stringify(' + expression + '));'],
                             text=True, capture_output=True, check=True)
        return json.loads(run.stdout)

    def revision_summary(self, before, after):
        return self.evaluate('revisionChangeSummary(' + json.dumps(before) + ',' + json.dumps(after) + ')')

    @staticmethod
    def revision(revision, topics, sources):
        return {'state': {'scenario_session': 'SESSION1', 'context_revision': revision,
                          'context': {'topic_preferences': dict.fromkeys(topics, 1)}},
                'packet': {'graph_paths': [{'content_item': source} for source in sources]}}

    def test_removed_focus_is_visible_when_the_same_source_has_fewer_paths(self):
        before = self.revision('R1', ['Healthcare journey', 'Connected operations'], ['S10'] * 4)
        after = self.revision('R2', ['Healthcare journey'], ['S10'] * 2)
        self.assertEqual('Learning focus revised: removed Connected operations. The returned sources are unchanged; '
                         'inspect Evidence for their recorded connections.', self.revision_summary(before, after))

    def test_objective_only_revision_and_changed_sources_are_distinct(self):
        before = self.revision('R1', ['Healthcare journey'], ['S10'])
        after = self.revision('R2', ['Healthcare journey'], ['S10'])
        before['state']['context']['objective'] = 'Explore'
        after['state']['context']['objective'] = 'Understand the patient journey'
        self.assertEqual('Objective/context revised. The returned sources are unchanged; inspect Evidence for their '
                         'recorded connections.', self.revision_summary(before, after))
        after['packet']['graph_paths'] = [{'content_item': 'S02'}, {'content_item': 'S03'}]
        self.assertEqual('Objective/context revised. Returned sources changed: removed S10; added S02, S03. '
                         'Inspect Evidence for their recorded connections.', self.revision_summary(before, after))

    def test_added_focus_and_source_changes_are_both_reported(self):
        before = self.revision('R1', ['Healthcare journey'], ['S10'])
        after = self.revision('R2', ['Semantic retrieval'], ['S02'])
        self.assertEqual('Learning focus revised: removed Healthcare journey; added Semantic retrieval. '
                         'Returned sources changed: removed S10; added S02. Inspect Evidence for their recorded '
                         'connections.', self.revision_summary(before, after))

    def test_missing_or_malformed_evidence_does_not_claim_unchanged_sources(self):
        for packet in (None, {}, {'graph_paths': None}, {'graph_paths': [None]},
                       {'graph_paths': [{'topic': 'Healthcare journey'}]}):
            for side in ('before', 'after'):
                with self.subTest(packet=packet, side=side):
                    before = self.revision('R1', ['Healthcare journey'], ['S10'])
                    after = self.revision('R2', ['Healthcare journey'], ['S10'])
                    (before if side == 'before' else after)['packet'] = packet
                    self.assertEqual('Objective/context revised. A source comparison is unavailable; inspect Evidence '
                                     'for the current recorded connections.', self.revision_summary(before, after))
        before = self.revision('R1', ['Healthcare journey'], [])
        after = self.revision('R2', ['Healthcare journey'], [])
        del before['packet']
        del after['packet']
        self.assertEqual('Objective/context revised. A source comparison is unavailable; inspect Evidence '
                         'for the current recorded connections.', self.revision_summary(before, after))

    def test_empty_evidence_and_absent_previous_revision_remain_conservative(self):
        before = self.revision('R1', ['Healthcare journey'], [])
        after = self.revision('R2', ['Healthcare journey'], [])
        self.assertEqual('Objective/context revised. No sources were returned in either revision; inspect Evidence '
                         'for the recorded retrieval.', self.revision_summary(before, after))
        self.assertEqual('', self.revision_summary(None, after))
        self.assertEqual('', self.revision_summary(after, after))
        before['state']['scenario_session'] = 'OTHER_SESSION'
        self.assertEqual('', self.revision_summary(before, after))

    def test_missing_topics_do_not_invent_removed_interests(self):
        before = self.revision('R1', ['Healthcare journey'], ['S10'])
        after = self.revision('R2', ['Healthcare journey'], ['S10'])
        del after['state']['context']['topic_preferences']
        self.assertEqual('Objective/context revised. The returned sources are unchanged; inspect Evidence for their '
                         'recorded connections.', self.revision_summary(before, after))

    def test_public_publishers_and_repository_owners(self):
        accepted = ['https://docs.oracle.com/en/database/guide.html',
                    'https://livelabs.oracle.com/ords/r/dbpm/livelabs/view-workshop?wid=4477',
                    'https://static.rainfocus.com/oracle/oaiw26/sess/1/document.pdf#page=2',
                    'https://github.com/oracle-livelabs/spatial-graph',
                    'https://raw.githubusercontent.com/helidon-io/helidon/main/README.md',
                    'https://api.github.com/repos/oracle/example',
                    'https://www.youtube.com/watch?v=publicReference']
        result = self.evaluate(json.dumps(accepted) + '.map(publicUrl)')
        self.assertEqual(accepted, result)

    def test_unapproved_or_credential_links_are_not_clickable(self):
        blocked = ['javascript:alert(1)', 'http://docs.oracle.com/a',
                   'https://docs.oracle.com.evil.test/a', 'https://localhost/a',
                   'https://docs.oracle.com:444/a', 'https://name:secret@docs.oracle.com/a',
                   'https://my.oracle.com/a', 'https://sso.oracle.com/a',
                   'https://github.com/unreviewed-owner/repo',
                   'https://api.github.com/users/oracle',
                   'https://static.rainfocus.com/other/event.pdf',
                   'https://docs.oracle.com/a?redirect=https%3A%2F%2Fx.sharepoint.com',
                   'https://docs.oracle.com/a?token=secret']
        self.assertEqual([None] * len(blocked), self.evaluate(json.dumps(blocked) + '.map(publicUrl)'))

    def test_non_pdf_locator_never_invents_pdf_page(self):
        values = [{'pdf_page': 10}, {'pdf_page': None, 'locator_label': 'HTML section: Overview'},
                  {'pdf_page': None, 'locator_label': 'Repository README'}, {'pdf_page': None}]
        self.assertEqual(['PDF page 10', 'HTML section: Overview', 'Repository README', 'Source passage'],
                         self.evaluate(json.dumps(values) + '.map(locatorLabel)'))

    def test_summary_basis_links_preserve_each_real_location(self):
        base = 'https://static.rainfocus.com/oracle/oaiw26/sess/1/document.pdf'
        passage = {'basis_locators': [
            {'pdf_page': 5, 'locator_url': base + '#page=5'},
            {'pdf_page': 17, 'locator_label': 'PDF page 17', 'locator_url': base + '#page=17'},
            {'pdf_page': 17, 'locator_label': 'PDF page 17', 'locator_url': base + '#page=17'},
            {'locator_label': 'Unapproved target', 'locator_url': 'javascript:alert(1)'}, None]}
        self.assertEqual([{'url': base + '#page=5', 'label': 'PDF page 5'},
                          {'url': base + '#page=17', 'label': 'PDF page 17'}],
                         self.evaluate('sourceBasisLinks(' + json.dumps(passage) + ')'))
        self.assertEqual([], self.evaluate('sourceBasisLinks({})'))


if __name__ == '__main__':
    unittest.main()
