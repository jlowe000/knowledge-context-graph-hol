import json
from pathlib import Path
import tempfile
import unittest

from kcv.pipeline import digest
from kcv.worksheet import worksheet_units, write_dataset_parts


class WorksheetPartsTests(unittest.TestCase):
    def test_parts_preserve_complete_units_and_utf8_byte_limit(self):
        units=[f"DECLARE\n  value VARCHAR2(1000):='{('graph-'+str(i)+'-\u03a9')*35}';\nBEGIN\n  NULL;\nEND;\n/\n" for i in range(12)]
        units.append('SELECT 1 FROM dual\n/\n')
        script='-- Original loader\nSET DEFINE OFF\nSET SERVEROUTPUT ON\n'+''.join(units)
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary)
            result=write_dataset_parts(script,folder,max_bytes=1900,notice='-- Fixture dataset.')
            self.assertGreater(result['part_count'],1)
            actual=[]
            for row in result['files']:
                body=(folder/row['path']).read_bytes()
                self.assertLessEqual(len(body),1900)
                self.assertEqual(digest(body),row['sha256'])
                text=body.decode('utf-8')
                self.assertTrue(text.startswith('SET DEFINE OFF\nSET SERVEROUTPUT ON\n'))
                self.assertIn('rerun from 001.sql',text)
                part_units=worksheet_units(text)
                self.assertEqual(len(part_units),row['unit_count'])
                actual.extend(part_units)
            self.assertEqual(actual,units)
            self.assertEqual(result['source_sql_sha256'],digest(script))
            self.assertEqual(result['sql_units_sha256'],digest(''.join(units)))
            self.assertEqual(json.loads((folder/'manifest.json').read_text())['files'],result['files'])

    def test_rejects_oversized_or_incomplete_unit(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(ValueError,'complete SQL unit'):
                write_dataset_parts("BEGIN\n  NULL; --"+'x'*2500+'\nEND;\n/\n',Path(temporary),max_bytes=1200)
            with self.assertRaisesRegex(ValueError,'Incomplete SQL unit'):
                write_dataset_parts('BEGIN\n NULL;\nEND;\n',Path(temporary))

    def test_regeneration_removes_only_retired_numbered_parts(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary); (folder/'keep.txt').write_text('Unrelated file')
            script=('BEGIN\n NULL; --'+'x'*300+'\nEND;\n/\n')*10
            first=write_dataset_parts(script,folder,max_bytes=1500)
            self.assertGreater(first['part_count'],1)
            second=write_dataset_parts('BEGIN\n NULL;\nEND;\n/\n',folder,max_bytes=1500)
            self.assertEqual(second['part_count'],1)
            self.assertEqual(sorted(p.name for p in folder.glob('*.sql')),['001.sql'])
            self.assertEqual((folder/'keep.txt').read_text(),'Unrelated file')


if __name__=='__main__': unittest.main()
