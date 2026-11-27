"""Source-derived exceptional-flow checks; native Oracle testing is separate.

The small parser accepts only the BEGIN/EXCEPTION and IF constructs used in the
actual run_action handler. Fault injection executes that tree, not a duplicate
Python implementation of the intended handler. This does not compile PL/SQL or
prove DBMS_LOCK behaviour; the disposable two-session native test does that.
"""
from itertools import combinations
from pathlib import Path
import re
import unittest


SOURCE = Path(__file__).resolve().parents[1] / 'sql/extensions/24_deployment_api.sql'


def handler_source(source):
    routine = source.split(' PROCEDURE run_action(', 1)[1].split('\n PROCEDURE configure_profile(', 1)[0]
    return routine.split('\n EXCEPTION WHEN OTHERS THEN\n  err:=SQLCODE;', 1)[1].rsplit('\n END;', 1)[0]


class Parser:
    def __init__(self, text):
        text = re.sub(r'--[^\n]*', '', text)
        self.tokens = re.findall(r"'(?:''|[^'])*'|[A-Za-z_][\w$.]*|:=|<>|\d+|\S", text)
        self.pos = 0

    def peek(self):
        return self.tokens[self.pos].upper() if self.pos < len(self.tokens) else ''

    def take(self, expected):
        actual = self.peek()
        if actual != expected:
            raise AssertionError(f'Expected {expected}, got {actual} at token {self.pos}')
        self.pos += 1

    def sequence(self, stops=()):
        result = []
        while self.peek() and self.peek() not in stops:
            if self.peek() == 'BEGIN':
                self.take('BEGIN')
                body = self.sequence(('EXCEPTION', 'END'))
                catch = None
                if self.peek() == 'EXCEPTION':
                    for word in ('EXCEPTION', 'WHEN', 'OTHERS', 'THEN'):
                        self.take(word)
                    catch = self.sequence(('END',))
                self.take('END'); self.take(';')
                result.append(('block', body, catch))
            elif self.peek() == 'IF':
                self.take('IF')
                branches = []
                while True:
                    start = self.pos
                    while self.peek() != 'THEN':
                        if not self.peek():
                            raise AssertionError('Unterminated condition')
                        self.pos += 1
                    condition = tuple(t.upper() for t in self.tokens[start:self.pos])
                    self.take('THEN')
                    branches.append((condition, self.sequence(('ELSIF', 'ELSE', 'END'))))
                    if self.peek() != 'ELSIF':
                        break
                    self.take('ELSIF')
                otherwise = []
                if self.peek() == 'ELSE':
                    self.take('ELSE'); otherwise = self.sequence(('END',))
                self.take('END'); self.take('IF'); self.take(';')
                result.append(('if', branches, otherwise))
            else:
                start = self.pos
                while self.peek() != ';':
                    if not self.peek():
                        raise AssertionError('Unterminated statement')
                    self.pos += 1
                result.append(('atom', tuple(t.upper() for t in self.tokens[start:self.pos])))
                self.take(';')
        return result


class CleanupFault(Exception):
    pass


class FinalFailure(Exception):
    pass


class Flow:
    def __init__(self, *, run=True, runtime=False, changed=False, model=False, locked=True,
                 admission=True, faults=()):
        self.values = {'RUN': run, 'RUNTIME_STARTED': runtime, 'MAINTENANCE_CHANGED': changed,
                       'P_OPERATION': model, 'LOCKED': locked, 'ADMISSION_LOCKED': admission,
                       'CLEANUP_TRANSACTION_SAFE': False}
        self.faults = set(faults)
        self.events = []

    def condition(self, tokens):
        text = ' '.join(tokens)
        known = {
            'RUN IS NOT NULL': self.values['RUN'],
            'RUN IS NOT NULL AND CLEANUP_TRANSACTION_SAFE': self.values['RUN'] and self.values['CLEANUP_TRANSACTION_SAFE'],
            'RUNTIME_STARTED': self.values['RUNTIME_STARTED'],
            'MAINTENANCE_CHANGED': self.values['MAINTENANCE_CHANGED'],
            "P_OPERATION = 'TEST_MODEL' AND RUNTIME_STARTED AND CLEANUP_TRANSACTION_SAFE": self.values['P_OPERATION'] and self.values['RUNTIME_STARTED'] and self.values['CLEANUP_TRANSACTION_SAFE'],
            'CLEANUP_TRANSACTION_SAFE': self.values['CLEANUP_TRANSACTION_SAFE'],
            'ADMISSION_LOCKED': self.values['ADMISSION_LOCKED'],
            'LOCKED': self.values['LOCKED'],
            'DBMS_LOB.ISTEMPORARY ( RESPONSE ) = 1': True,
        }
        if text not in known:
            raise AssertionError(f'Unreviewed cleanup condition: {text}')
        return known[text]

    def atom(self, tokens):
        text = ' '.join(tokens)
        if tokens == ('NULL',):
            return
        if tokens[:2] == ('CLEANUP_TRANSACTION_SAFE', ':='):
            if tokens[2] not in ('TRUE', 'FALSE'):
                raise AssertionError('Unexpected transaction-safety assignment')
            self.values['CLEANUP_TRANSACTION_SAFE'] = tokens[2] == 'TRUE'
            return
        if tokens == ('RAISE',):
            raise FinalFailure('original')
        if tokens[0] == 'RAISE_APPLICATION_ERROR':
            if tokens[2] != 'C_FAILED' or 'SETUP_FAILED:' not in text:
                raise AssertionError('Final error is not the bounded setup error')
            raise FinalFailure('sanitized')
        if tokens[0] in ('ROLLBACK', 'COMMIT', 'MAINTENANCE_ON', 'RESTORE_MAINTENANCE'):
            action = tokens[0].lower()
        elif tokens[0] == 'DBMS_LOB.FREETEMPORARY':
            action = 'free_lob'
        elif tokens[0] == 'UPDATE' and tokens[1] == 'KCV_DEPLOY_STATE':
            action = 'model_failed'
        elif tokens[0] == 'PROGRESS':
            if tokens != ('PROGRESS', '(', 'RUN', ',', "'FAILED'", ',', "'REVIEW_BEFORE_RETRY'", ',', 'ERR', ')'):
                raise AssertionError('Journal must retain the captured root failure')
            action = 'journal'
        elif tokens[:3] == ('LOCK_RESULT', ':=', 'DBMS_LOCK.RELEASE'):
            action = 'release_' + tokens[4].lower()
        else:
            raise AssertionError(f'Unreviewed cleanup statement: {text}')
        self.events.append(action)
        if action in self.faults or f'{action}:{self.events.count(action)}' in self.faults:
            raise CleanupFault(action)

    def execute(self, nodes):
        for node in nodes:
            if node[0] == 'atom':
                self.atom(node[1])
            elif node[0] == 'if':
                for condition, body in node[1]:
                    if self.condition(condition):
                        self.execute(body)
                        break
                else:
                    self.execute(node[2])
            elif node[0] == 'block':
                try:
                    self.execute(node[1])
                except CleanupFault:
                    if node[2] is None:
                        raise
                    self.execute(node[2])


class DeploymentCleanupTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8')
        cls.tree = Parser(handler_source(cls.source)).sequence()

    def assert_final(self, flow, expected='sanitized'):
        with self.assertRaises(FinalFailure) as caught:
            flow.execute(self.tree)
        self.assertEqual(str(caught.exception), expected)
        self.assertEqual(flow.events.count('release_admission'), int(flow.values['ADMISSION_LOCKED']))
        self.assertEqual(flow.events.count('release_handle'), int(flow.values['LOCKED']))

    def test_every_combination_of_cleanup_faults_still_attempts_both_releases(self):
        # Includes faults in rollback and either release itself, not just journal writes.
        sites = ('free_lob', 'rollback', 'maintenance_on', 'model_failed', 'commit',
                 'journal', 'release_admission', 'release_handle')
        for count in range(len(sites) + 1):
            for failures in combinations(sites, count):
                with self.subTest(failures=failures):
                    flow = Flow(runtime=True, model=True, faults=failures)
                    self.assert_final(flow)
                    if 'rollback' not in failures:
                        self.assertIn('journal', flow.events)
                    else:
                        self.assertNotIn('journal', flow.events)
                        self.assertNotIn('commit', flow.events)
                        self.assertNotIn('maintenance_on', flow.events)
                    self.assertNotIn('restore_maintenance', flow.events)

    def test_failed_restoration_rolls_back_before_other_cleanup(self):
        flow = Flow(changed=True, faults=('restore_maintenance',))
        self.assert_final(flow)
        index = flow.events.index('restore_maintenance')
        self.assertEqual(flow.events[index + 1], 'rollback')
        self.assertNotIn('maintenance_on', flow.events)
        self.assertNotIn('commit', flow.events)

    def test_failed_model_status_update_rolls_back_and_records_original_error(self):
        flow = Flow(runtime=True, model=True, faults=('model_failed',))
        self.assert_final(flow)
        index = flow.events.index('model_failed')
        self.assertEqual(flow.events[index + 1:index + 3], ['rollback', 'journal'])

    def test_failed_cleanup_rollback_prevents_later_commits_and_autonomous_journal(self):
        for model in (False, True):
            with self.subTest(model=model):
                failure = 'model_failed' if model else 'restore_maintenance'
                flow = Flow(changed=not model, runtime=model, model=model,
                            faults=(failure, 'rollback:2'))
                self.assert_final(flow)
                self.assertNotIn('commit', flow.events)
                self.assertNotIn('journal', flow.events)

    def test_prejournal_error_keeps_original_and_only_releases_held_locks(self):
        flow = Flow(run=False, admission=False, faults=('free_lob', 'rollback', 'release_handle'))
        self.assert_final(flow, expected='original')
        self.assertNotIn('journal', flow.events)
        self.assertNotIn('maintenance_on', flow.events)
        self.assertNotIn('restore_maintenance', flow.events)

    def test_old_unguarded_journal_failure_is_detected(self):
        old = Parser("""
          progress(run,'FAILED','REVIEW_BEFORE_RETRY',err);
          IF admission_locked THEN lock_result:=DBMS_LOCK.RELEASE(admission);END IF;
          IF locked THEN lock_result:=DBMS_LOCK.RELEASE(handle);END IF;
        """).sequence()
        flow = Flow(faults=('journal',))
        with self.assertRaises(CleanupFault):
            flow.execute(old)
        self.assertNotIn('release_admission', flow.events)
        self.assertNotIn('release_handle', flow.events)


if __name__ == '__main__':
    unittest.main()
