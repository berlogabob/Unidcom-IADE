import unittest
from normalize_news import clean, match_taxonomy, normalize_type, normalize_year, unique_slug, normalize_rows


class NormalizeTests(unittest.TestCase):
    def test_clean_taxonomy_and_year(self):
        self.assertEqual([clean(None), clean(' - '), clean(' Design ')], ['', '', 'Design'])
        self.assertEqual(match_taxonomy('design', {'Design'}), ('Design', ''))
        self.assertTrue(match_taxonomy('Other', {'Design'})[1])
        self.assertEqual(normalize_year(2026.0), ('2026', ''))
        self.assertEqual(normalize_year(' earlier '), ('Earlier', ''))
        self.assertTrue(normalize_year('26')[1])

    def test_types(self):
        allowed = {'[calls] presentation', '[Events] conference', '[calls] posters',
                   '[Events] seminar', '[Events] workshops', '[Events] exhibition'}
        for canonical in allowed:
            bare = canonical.split('] ', 1)[1]
            result, original, note = normalize_type(bare.upper(), allowed)
            self.assertEqual(result, canonical)
            self.assertEqual(original, bare.upper())
            self.assertTrue(note)
        for value in ['-', None, 'unknown']:
            self.assertEqual(normalize_type(value, allowed)[0], 'Unclassified')

    def test_slugs_collisions(self):
        used = set()
        self.assertEqual([unique_slug(t, used) for t in ['Olá!', 'Ola', 'Ola-2', 'Ola', '中文']],
                         ['ola', 'ola-2', 'ola-2-2', 'ola-3', 'news'])

    def test_dedup_and_review(self):
        tax = {'Type values': {'[calls] presentation'}, 'Scientific areas': {'Design'},
               'Member types': {'Integrated'}, 'Labs': {'BID.Lab'}}
        values = ['T' * 151, '2026', '-', 'Unknown', 'Integrated; Other', '-']
        rows, review = normalize_rows([('a.xlsx', 2, values, tax), ('b.xlsx', 3, values, tax)])
        self.assertEqual(len(rows), 1)
        self.assertEqual(len(review), 2)
        self.assertFalse(rows[0]['excerpt_ok'])
        for reason in ['Unclassified', 'missing lab', 'non-matching taxonomy', 'title > 150']:
            self.assertIn(reason, review[0]['reason'])
        self.assertIn('duplicate title+year', review[1]['reason'])
        self.assertNotEqual(review[0]['slug'], review[1]['slug'])


if __name__ == '__main__':
    unittest.main()
