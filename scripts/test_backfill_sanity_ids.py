import unittest
from backfill_sanity_ids import link_key, output_matches, people_matches


class BackfillTests(unittest.TestCase):
    def test_links(self):
        self.assertEqual(link_key('HTTPS://doi.org/10.1234/ABC'), link_key('10.1234/abc'))
        self.assertEqual(link_key('https://EXAMPLE.org/p/'), link_key('http://example.org/p'))
        self.assertEqual(link_key(None), '')

    def test_one_to_one_and_conflicting_evidence(self):
        docs = [{'_type': 'researchOutput', '_id': 's1', 'title': 'É A!', 'year': 2020,
                 'link': 'https://doi.org/10.1234/a'},
                {'_type': 'researchOutput', '_id': 's2', 'title': 'B', 'year': 2020}]
        row = {'id': 'p1', 'title': 'e a', 'reporting_year': 2020}
        self.assertEqual(output_matches([row], docs)[0][0]['sanity_id'], 's1')
        self.assertEqual(len(output_matches([row, {**row, 'id': 'p2'}], docs)[0]), 0)
        self.assertEqual(len(output_matches([row, {**row, 'id': 'p2', 'sanity_id': 's1'}], docs)[0]), 0)
        conflict = {**row, 'title': 'B', 'doi': '10.1234/a'}
        self.assertEqual(output_matches([conflict], docs)[1][0]['reason'], 'ambiguous')
        self.assertEqual(len(output_matches([{**row, 'reporting_year': None}], docs)[0]), 0)

    def test_people(self):
        row = {'person_id': 'p', 'sanity_id': 's', 'ambiguous': 'False', 'match_kind': 'email'}
        self.assertEqual(people_matches([row]), ([row], []))
        self.assertEqual(len(people_matches([row, {**row, 'person_id': 'p2'}])[0]), 0)
        self.assertEqual(len(people_matches([{**row, 'ambiguous': 'True'}])[0]), 0)
        self.assertEqual(len(people_matches([{**row, 'match_kind': 'name'}])[0]), 0)
