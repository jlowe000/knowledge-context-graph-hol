import base64
import json
import unittest

from kcv.ingestion import chunks, extract


class IngestionTests(unittest.TestCase):
    def source(self, url='https://www.oracle.com/example'):
        return {'id': 'R0001', 'url': url, 'version': {'id': 'R0001-v1', 'sha256': 'a' * 64}}

    def test_html_keeps_content_not_navigation_or_script(self):
        body = b'<html><nav>Private navigation</nav><main><h1 id="topic">Graph retrieval</h1><p>Graph traversal connects explicit relationships between source records and concepts.</p><script>secret()</script></main></html>'
        rows, status = extract(body, 'text/html', self.source())
        self.assertEqual(status, 'extracted')
        self.assertNotIn('Private navigation', str(rows)); self.assertNotIn('secret', str(rows))
        self.assertIsNone(rows[0]['pdf_page'])
        self.assertEqual(rows[0]['locator_kind'], 'html_section')
        self.assertTrue(rows[0]['locator_url'].endswith('#topic'))

    def test_video_page_is_not_a_transcript(self):
        rows, status = extract(b'<html><p>Watch this video</p></html>', 'text/html', self.source('https://www.youtube.com/watch?v=123'))
        self.assertFalse(rows); self.assertEqual(status, 'video_transcript_not_available')

    def test_blob_is_decoded_as_source_code(self):
        text = b'<html><p>Example application login form in a public code file.</p></html>'
        payload = json.dumps({'encoding': 'base64', 'content': base64.b64encode(text).decode()}).encode()
        rows, status = extract(payload, 'application/json', self.source('https://api.github.com/repos/oracle/example/git/blobs/abc'))
        self.assertEqual(status, 'extracted'); self.assertIn('<html>', rows[0]['text'])
        self.assertEqual(rows[0]['locator_kind'], 'repository_file')

    def test_chunk_ids_and_hashes_follow_actual_text_and_edition(self):
        source = self.source(); segments = [{'text': 'abcde' * 500, 'pdf_page': None, 'segment_index': 1,
            'locator_kind': 'html_section', 'locator_label': 'Overview', 'locator_url': source['url']}]
        first = chunks(source, segments); second = chunks(source, segments)
        self.assertEqual(first, second); self.assertTrue(all(len(p['text']) <= 1000 for p in first))
        self.assertTrue(all(p['pdf_page'] is None for p in first))
        self.assertTrue(all(p['id'].startswith('R0001-v1-s0001') for p in first))

    def test_contents_endpoint_decodes_base64_file(self):
        payload = json.dumps({'encoding': 'base64', 'type': 'file', 'content': base64.b64encode(b'# Oracle example\nThis readme describes retrieval with a graph.').decode()}).encode()
        rows, status = extract(payload, 'application/json', self.source('https://api.github.com/repos/oracle/example/contents/README.md'))
        self.assertEqual(status, 'extracted'); self.assertIn('retrieval with a graph', rows[0]['text'])
        self.assertNotIn('base64', rows[0]['text'])

    def test_github_wrapper_is_not_source_content_and_embedded_lines_are_decoded(self):
        url = self.source('https://github.com/oracle/example/blob/main/config.txt')
        wrapper = '<main><h2>File metadata and controls</h2><p>35 lines (29 loc) 1.8 KB Raw</p></main>'
        payload = '<script type="application/json">' + json.dumps({'rawLines': [
            '# Public configuration example', 'enabled=true', 'mode=read-only']}) + '</script>'
        rows, status = extract((wrapper + payload).encode(), 'text/html', url)
        self.assertEqual(status, 'extracted')
        self.assertEqual(rows[0]['locator_kind'], 'repository_file')
        self.assertIn('mode=read-only', rows[0]['text'])
        rows, status = extract(wrapper.encode(), 'text/html', url)
        self.assertEqual((rows, status), ([], 'metadata_page_only'))
        rows, status = extract((wrapper + '<p>Sorry about that, but we can\u2019t show files that are this big right now.</p>').encode(), 'text/html', url)
        self.assertEqual((rows, status), ([], 'metadata_page_only'))


if __name__ == '__main__': unittest.main()
