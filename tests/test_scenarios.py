"""Test graph retrieval semantics independently from Oracle and model services."""
import copy
import unittest
from rdflib import Graph, URIRef
from kcv import pipeline as p


class ScenarioGraphTests(unittest.TestCase):
    def bindings(self, context):
        g=Graph().parse(p.ROOT/'generated/knowledge.ttl',format='turtle')
        revision=p.K['R-local-component']
        for label in context['topic_preferences']:
            g.add((revision,p.K.focusesOn,p.K['topic-'+p.slug(label)]))
        return list(g.query('''SELECT DISTINCT ?item ?ver ?topic ?passage WHERE {
          <https://example.org/kcv/R-local-component> <https://example.org/kcv/focusesOn> ?topic .
          ?item <https://example.org/kcv/coversTopic> ?topic ; <https://example.org/kcv/hasVersion> ?ver .
          ?ver <https://example.org/kcv/hasPassage> ?passage }'''))

    def test_topic_removal_changes_native_query_eligibility_and_preserves_base(self):
        original=p.read(p.ROOT/'data/contexts.json')['contexts'][0]
        before_hash=p.digest((p.ROOT/'generated/knowledge.ttl').read_bytes())
        before={str(r.item) for r in self.bindings(original)}
        changed=copy.deepcopy(original);del changed['topic_preferences']['Graph capabilities']
        after={str(r.item) for r in self.bindings(changed)}
        self.assertIn(str(p.K.S06),before)
        self.assertNotIn(str(p.K.S06),after)
        self.assertIn(str(p.K.S02),after)
        self.assertEqual(before_hash,p.digest((p.ROOT/'generated/knowledge.ttl').read_bytes()))

    def test_objective_only_refinement_does_not_claim_changed_retrieval(self):
        context=p.read(p.ROOT/'data/contexts.json')['contexts'][0]
        changed={**context,'objective':'Find existing project information','objective_clarity':'defined'}
        self.assertEqual(set(self.bindings(context)),set(self.bindings(changed)))

    def test_healthcare_paths_retain_disclaimer_and_overview_pages(self):
        context=p.read(p.ROOT/'data/contexts.json')['contexts'][2]
        rows=self.bindings(context);ids={str(r.passage).rsplit('/',1)[-1] for r in rows}
        passages=[r for r in p.read(p.ROOT/'work/passages.json') if r['id'] in ids]
        self.assertEqual({r['source_id'] for r in passages},{'S10'})
        self.assertEqual({r['pdf_page'] for r in passages},{3,10})

    def test_every_returned_relationship_is_grounded_in_loaded_content(self):
        context=p.read(p.ROOT/'data/contexts.json')['contexts'][0]
        sources={s['id']:s for s in p.sources()+p.catalog()};passages={r['id']:r for r in p.load_passages()}
        for row in self.bindings(context):
            source=sources[str(row.item).rsplit('/',1)[-1]]
            passage=passages[str(row.passage).rsplit('/',1)[-1]]
            self.assertEqual(source['version']['id'],passage['version_id'])
            self.assertIn(str(row.topic),[str(p.K['topic-'+p.slug(t)]) for t in source['topics']])


if __name__=='__main__':unittest.main()
