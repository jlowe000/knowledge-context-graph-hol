"""Read-only verifier generation contracts; native execution is a separate check."""
from collections import Counter
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

from scripts import build_database_installers as db


def previous_verification_block(root, items, receipts=True, effective_owner=False):
    """Prior rendering, retained solely as the receipt/order regression oracle."""
    statements = [db.retirement_guard(root)] if receipts else []
    for item in items:
        successors = db.successor_chain(item, items)
        target = successors[-1] if successors else item
        if successors and receipts:
            statements.append(db.receipt_check(target))
        statements.append((db.effective_owner_verification(root, target) if effective_owner
                           else db.read(root / target['verification'])).strip())
        if receipts:
            statements.append(db.receipt_check(item))
    return ('DECLARE\n' + db.VERIFY_DECLARATIONS + '\nBEGIN\n' + '\n'.join(statements)
            + "\n DBMS_OUTPUT.PUT_LINE('KCV schema verification passed');\nEND;\n")


def previous_installed_gate(root, required, all_items, effective_owner=False):
    """Prior runtime selection and receipt sequence, before physical memoization."""
    def check(item):
        return (db.effective_owner_verification(root, item) if effective_owner
                else db.read(root / item['verification'])).strip()
    statements = []
    for item in required:
        successors = db.successor_chain(item, all_items)
        if not successors:
            statements.extend([check(item), db.receipt_check(item)])
            continue
        lines = [' DECLARE l_replaced BOOLEAN:=FALSE;BEGIN']
        for successor in reversed(successors):
            digest = db.sha(successor['payload_sha256'] + ':' + successor['verification_sha256'])
            lines.extend([
                ' IF NOT l_replaced THEN',
                f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={db.literal(successor['id'])} AND payload_sha256={db.literal(digest)} AND phase='COMPLETE';",
                ' IF l_n=1 THEN', check(successor),
                ' l_replaced:=TRUE;END IF;END IF;'])
        lines.extend([' IF NOT l_replaced THEN', check(item),
                      ' END IF;', db.receipt_check(item), ' END;'])
        statements.append('\n'.join(lines))
    return ('DECLARE\n' + db.VERIFY_DECLARATIONS + '\nBEGIN\n' + '\n'.join(statements)
            + "\n DBMS_OUTPUT.PUT_LINE('KCV installed baseline contract verified');\nEND;\n")


def receipt_operations(sql):
    """All registry SELECTs and require calls, preserving exact text and order."""
    return re.findall(r" SELECT COUNT\(\*\) INTO l_n FROM kcv_schema_migrations[^;]*;"
                      r"(?:\n require\([^\n]*\);)?", sql)


class VerificationDedupTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'db').mkdir()
        self.items = []
        for mid, supersedes in (
            ('old-a', []), ('old-b', []), ('unrelated', []),
            ('middle-a', ['old-a']), ('middle-b', ['old-b']),
            ('latest-ready', ['middle-a', 'middle-b']),
        ):
            verify = f" DBMS_OUTPUT.PUT_LINE('PHYSICAL:{mid}');\n require(l_n>=0,'check:{mid}');\n"
            path = f'db/{mid}.verify.sql'
            (self.root / path).write_text(verify, encoding='utf-8')
            item = {'id': mid, 'version': '2.1.0', 'verification': path,
                    'payload_sha256': db.sha('payload:' + mid),
                    'verification_sha256': db.sha(verify), 'depends_on': []}
            if supersedes:
                item['supersedes'] = supersedes
            self.items.append(item)
        (self.root / 'db/manifest.json').write_text(json.dumps({'migrations': self.items}), encoding='utf-8')

    def test_full_block_preserves_every_receipt_and_checks_final_shape_once(self):
        old = previous_verification_block(self.root, self.items)
        new = db.verification_block(self.root, self.items)
        self.assertEqual(receipt_operations(new), receipt_operations(old))
        self.assertEqual(old.count("'PHYSICAL:latest-ready'"), 5)
        self.assertEqual(new.count("'PHYSICAL:latest-ready'"), 1)
        self.assertEqual(new.count("'PHYSICAL:unrelated'"), 1)
        self.assertNotIn("'PHYSICAL:old-a'", new)
        for item in self.items:
            self.assertEqual(new.count(db.receipt_check(item)), old.count(db.receipt_check(item)))

    def test_full_block_without_receipts_still_deduplicates_only_physical_checks(self):
        new = db.verification_block(self.root, self.items, receipts=False)
        self.assertEqual(new.count("'PHYSICAL:latest-ready'"), 1)
        self.assertEqual(new.count("'PHYSICAL:unrelated'"), 1)
        self.assertEqual(receipt_operations(new), [])

    def test_gate_keeps_runtime_latest_complete_selection_and_all_receipts(self):
        required = self.items[:3] + self.items[3:5]
        old = previous_installed_gate(self.root, required, self.items)
        new = db.installed_contract_gate(self.root, required, self.items)
        self.assertEqual(receipt_operations(new), receipt_operations(old))
        self.assertEqual(new.count("'PHYSICAL:latest-ready'"), 1)
        self.assertEqual(old.count("'PHYSICAL:latest-ready'"), 4)
        main = new.split('\nBEGIN\n', 1)[1]
        self.assertEqual(main.count('DECLARE l_replaced BOOLEAN:=FALSE'), 4)
        self.assertEqual(main.count("AND phase='COMPLETE'"), old.split('\nBEGIN\n', 1)[1].count("AND phase='COMPLETE'"))
        latest_query = "WHERE migration_id='latest-ready' AND payload_sha256="
        middle_query = "WHERE migration_id='middle-a' AND payload_sha256="
        self.assertLess(main.index(latest_query), main.index(middle_query))
        self.assertIn("IF l_n=1 THEN\n kcv_check_physical_1;\n l_replaced:=TRUE", main)
        for item in required:
            self.assertEqual(main.count(db.receipt_check(item)), old.count(db.receipt_check(item)))

    def test_memo_is_set_after_success_only_and_scoped_to_anonymous_block(self):
        failed = self.items[-1]
        source = "RAISE_APPLICATION_ERROR(-20999,'injected physical failure');\n"
        (self.root / failed['verification']).write_text(source, encoding='utf-8')
        first = db.installed_contract_gate(self.root, self.items[:2], self.items)
        second = db.installed_contract_gate(self.root, self.items[:2], self.items)
        self.assertEqual(first, second)
        self.assertIn('l_kcv_physical_checks kcv_physical_checks_t;', first)
        procedure = first.split('PROCEDURE kcv_check_physical_1 IS BEGIN', 1)[1].split('\n END;', 1)[0]
        self.assertLess(procedure.index(source.strip()), procedure.index("l_kcv_physical_checks('latest-ready'):=TRUE"))
        self.assertNotIn('EXCEPTION', procedure)
        self.assertNotIn('CREATE OR REPLACE PACKAGE', first)
        self.assertNotIn('RESULT_CACHE', first)
        self.assertNotIn('PRAGMA AUTONOMOUS_TRANSACTION', first)

    def test_gate_fallback_and_unrelated_shapes_are_not_omitted_at_generation_time(self):
        new = db.installed_contract_gate(self.root, self.items[:3], self.items)
        for mid in ('old-a', 'old-b', 'middle-a', 'middle-b', 'latest-ready', 'unrelated'):
            self.assertEqual(new.count(f"'PHYSICAL:{mid}'"), 1, mid)
        main = new.split('\nBEGIN\n', 1)[1]
        for item in self.items[:2]:
            receipt = db.receipt_check(item)
            end = main.index(receipt)
            self.assertIn('IF NOT l_replaced THEN\n kcv_check_physical_', main[:end])

    def test_effective_owner_mode_is_applied_to_every_unique_physical_target(self):
        original = db.effective_owner_verification
        with patch.object(db, 'effective_owner_verification', wraps=original) as render:
            db.verification_block(self.root, self.items, effective_owner=True)
            self.assertEqual([call.args[1]['id'] for call in render.call_args_list],
                             ['latest-ready', 'unrelated'])
        with patch.object(db, 'effective_owner_verification', wraps=original) as render:
            db.installed_contract_gate(self.root, self.items[:3], self.items, effective_owner=True)
            self.assertEqual(Counter(call.args[1]['id'] for call in render.call_args_list),
                             Counter(['latest-ready', 'middle-a', 'old-a', 'middle-b', 'old-b', 'unrelated']))

    def test_generation_is_read_only_and_receipt_guards_are_not_memoized(self):
        with patch.object(db, 'write_checked', side_effect=AssertionError('Generation wrote a file')):
            new = db.installed_contract_gate(self.root, self.items[:2], self.items)
            db.verification_block(self.root, self.items)
        declaration, main = new.split('\nBEGIN\n', 1)
        self.assertEqual(receipt_operations(declaration), [])
        self.assertNotIn('l_kcv_physical_checks', main)
        self.assertIn(db.receipt_check(self.items[0]), main)
        self.assertIn(db.receipt_check(self.items[1]), main)


if __name__ == '__main__':
    unittest.main()
