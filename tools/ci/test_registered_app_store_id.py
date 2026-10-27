"""Keep the nonsecret registered draft ID consistent without authorizing delivery."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class RegisteredAppStoreIDTests(unittest.TestCase):
    def test_project_and_delivery_share_registered_default_and_owner_override(self):
        project = (ROOT / 'ios/project.yml').read_text()
        workflow = (ROOT / '.github/workflows/apple-delivery.yml').read_text()
        default = re.search(r'^        TIMBRE_APP_STORE_ID: "([0-9]+)"$', project, re.M).group(1)
        self.assertEqual(default, '6827721551')
        self.assertIn("TIMBRE_APP_STORE_ID: ${{ vars.TIMBRE_APP_STORE_ID || '" + default + "' }}", workflow)
        self.assertIn('TimbreAppStoreID: $(TIMBRE_APP_STORE_ID)', project)
        self.assertIn('TIMBRE_APP_STORE_ID="${TIMBRE_APP_STORE_ID:-}"', workflow)

    def test_default_does_not_enable_automatic_submission_or_invent_ratings(self):
        workflow = (ROOT / '.github/workflows/apple-delivery.yml').read_text()
        self.assertIn('if: ${{ inputs.confirm_delivery }}', workflow)
        self.assertIn('environment: apple-delivery', workflow)
        rating = (ROOT / 'ios/Timbre/Services/StoreRating.swift').read_text()
        self.assertIn('!TestSupport.isAutomated', rating)
        self.assertIn('https://itunes.apple.com/lookup', rating)
        self.assertIn('let stars = result.averageUserRating', rating)
        self.assertIn('let count = result.userRatingCount', rating)
        self.assertIn('fetched.count >= Self.minimumRatings', rating)


    def test_rating_lookup_and_cache_bind_to_configured_app_identity(self):
        rating = (ROOT / 'ios/Timbre/Services/StoreRating.swift').read_text()
        self.assertIn('Self.validatedLookup(data, appID: id, bundleID: Bundle.main.bundleIdentifier', rating)
        self.assertIn('result.trackId == number, result.bundleId == bundleID', rating)
        self.assertIn('lookup.resultCount == 1, lookup.results.count == 1', rating)
        self.assertIn('validCachedLine(line, appID: AppLinks.appStoreID, bundleID: Bundle.main.bundleIdentifier)', rating)
        self.assertIn('line.stars.isFinite && (0...5).contains(line.stars) && line.count >= 0', rating)
        self.assertIn('cached.flatMap { Self.matchesCurrentApp($0) ? $0 : nil }', rating)
        self.assertIn('defaults.removeObject(forKey: Self.cacheKey)', rating)

    def test_current_storefront_is_observable_and_resolved_before_cache_or_network(self):
        rating = (ROOT / 'ios/Timbre/Services/StoreRating.swift').read_text()
        self.assertIn('@Published private var currentStorefront: String?', rating)
        self.assertIn('Self.matchingStorefront(fetched, currentStorefront: currentStorefront)', rating)
        resolve = rating.index('currentStorefront = resolvedStorefront')
        self.assertLess(rating.index('guard !TestSupport.isAutomated, !fetching'), resolve)
        self.assertLess(resolve, rating.index('if let last = defaults.object'))
        self.assertLess(resolve, rating.index('Self.session.data(for: request)'))
        self.assertLess(rating.index('fetching = true'), rating.index('await Storefront.current'))
        self.assertLess(rating.index('defer { fetching = false }'), rating.index('await Storefront.current'))
        self.assertEqual(rating.count('fetching = true'), 1)


if __name__ == '__main__':
    unittest.main()
