"""Legacy runner keeps an explicit ADMIN target while release uses Worksheet binds."""
import contextlib
import io
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch

from kcv import cli, database
from kcv.pipeline import ROOT


class BootstrapBindingTests(unittest.TestCase):
    def test_driver_passes_target_as_bind_without_sql_interpolation(self):
        connection = MagicMock()
        cursor = connection.cursor.return_value.__enter__.return_value
        cursor.description = None
        cursor.fetchall.return_value = []
        connector = MagicMock()
        connector.return_value.__enter__.return_value = connection
        with patch('kcv.database.connect', connector):
            database.apply(ROOT / 'sql/admin/02_grants.sql', True,
                           {'KCV_SCHEMA': 'KCV_BIND_TARGET'})
        statement, bindings = cursor.execute.call_args_list[0].args
        self.assertIn(':KCV_SCHEMA', statement)
        self.assertNotIn('KCV_BIND_TARGET', statement)
        self.assertEqual(bindings, {'KCV_SCHEMA': 'KCV_BIND_TARGET'})
        connector.assert_called_once_with(True)
        connection.commit.assert_called_once()

    def test_cli_refuses_implicit_or_invalid_grants_target_before_connecting(self):
        for suffix in ([], ['--schema', 'ADMIN'], ['--schema', 'KCV_X;DROP_USER']):
            with self.subTest(suffix=suffix), \
                 patch('sys.argv', ['kcv', 'apply-sql', '--admin', '--file',
                                    str(ROOT / 'sql/admin/02_grants.sql'), *suffix]), \
                 patch('kcv.database.apply') as apply, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    cli.main()
                apply.assert_not_called()

    def test_cli_requires_admin_and_passes_explicit_owner(self):
        arguments = ['kcv', 'apply-sql', '--file', str(ROOT / 'sql/admin/02_grants.sql'),
                     '--schema', 'KCV_BIND_TARGET']
        with patch('sys.argv', arguments), patch('kcv.database.apply') as apply, \
                contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                cli.main()
            apply.assert_not_called()
        with patch('sys.argv', [*arguments, '--admin']), \
                patch('kcv.database.apply', return_value=[]) as apply, \
                contextlib.redirect_stdout(io.StringIO()):
            cli.main()
            apply.assert_called_once_with(ROOT / 'sql/admin/02_grants.sql', True,
                                          {'KCV_SCHEMA': 'KCV_BIND_TARGET'})

    def test_schema_option_cannot_silently_redirect_legacy_provision(self):
        with patch('sys.argv', ['kcv', 'provision', '--schema', 'KCV_BIND_TARGET']), \
                patch('kcv.database.provision') as provision, \
                contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                cli.main()
            provision.assert_not_called()


if __name__ == '__main__':
    unittest.main()
