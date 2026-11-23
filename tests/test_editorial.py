"""Editorial publication cannot silently detach from its actual source edition."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from kcv import pipeline as p
from kcv.editorial import validate_summary_basis


class EditorialTests(unittest.TestCase):
    def test_all_published_paraphrases_have_matching_local_basis(self):
        result = validate_summary_basis()
        self.assertGreater(result['summary_count'], 700)
        self.assertTrue(result['basis_hashes_verified'])

    def test_different_page_or_hash_cannot_reuse_the_original_basis(self):
        record = next(x for x in p.read(p.ROOT/'data/public-content-summaries.json')['summaries'] if x['pdf_page'])
        source = next(x for x in p.catalog() if x['id'] == record['source_id'])
        raw = [x for x in p.read(p.ROOT/'work/catalog-passages.json') if x['id'] in record['basis_passage_ids']]
        with tempfile.TemporaryDirectory() as temp, patch('kcv.editorial.p.catalog',return_value=[source]):
            root = Path(temp)
            p.write(root/'work/catalog-passages.json',raw)
            p.write(root/'data/public-content-summaries.json',{'summaries':[record]})
            validate_summary_basis(root)
            changed = {**record,'pdf_page':record['pdf_page'] + 1}
            p.write(root/'data/public-content-summaries.json',{'summaries':[changed]})
            with self.assertRaisesRegex(ValueError,'locators differ'):
                validate_summary_basis(root)
            changed = {**record,'basis_text_sha256':['0'*64 for _ in record['basis_text_sha256']]}
            p.write(root/'data/public-content-summaries.json',{'summaries':[changed]})
            with self.assertRaisesRegex(ValueError,'basis does not match'):
                validate_summary_basis(root)


if __name__ == '__main__': unittest.main()
