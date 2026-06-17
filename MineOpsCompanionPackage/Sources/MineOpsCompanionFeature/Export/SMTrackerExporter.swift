import Foundation

struct SMTrackerBackupEntry: Codable, Hashable {
    var unlocked: Bool
    var rank: Int
    var level: Int
    var promoted: Int
    var fragments: Int
    var chronoExcluded: Bool
    var tierlistExcluded: Bool

    static let defaults = SMTrackerBackupEntry(
        unlocked: false,
        rank: 0,
        level: 1,
        promoted: 0,
        fragments: 0,
        chronoExcluded: false,
        tierlistExcluded: false
    )
}

enum SMTrackerExporter {
    /// Canonical key universe required by the external SM tracker backup format.
    /// Do not add/remove keys here unless the external format changes.
    static let canonicalManagerKeys: [String] = [
        "asterion", "belle-snowdrop", "cervina", "chance-goldshell", "count-lucius", "drethos", "eivor", "ember", "eternity", "harumi", "king-orekk", "lei-na", "lord-beiroth", "lorelei", "luna-and-stella", "om-nix", "poseidon", "professor-impossible", "remedy-rose", "samantha-reiss", "selena-amanita", "sir-axiom", "sir-lorenzo", "urca", "ut-ux", "vulcan", "yasuke", "zenthor", "abeo-meremikwu", "adamantus", "afi", "amora", "archibald", "aric-swiftstrike", "astra-and-curt", "bam-bam", "beiro", "chef-bearnard", "cliff-walker", "dave-riptide", "dr-lilly", "dr-nova", "dr-steiner", "erica-quill", "everett-bloomfield", "ezio-auditore", "floating-agatha", "freesia", "glimmer", "green-idler", "h4v0c", "hatori", "iggy-ignite", "jackal", "jade-kim", "krampus", "lauany", "lavender-wick", "lavernia-pascal", "lila-starborne", "luxario", "mad-eye-drake", "marrena", "maya-gelata", "melody-rivers", "mr-edmund", "naoe", "octavia-de-vere", "ore-sama-daichi", "pebble", "phineas-cogsmith", "professor-maple", "queen-aurora", "r-bit", "rabbid-blingsley", "ray-rift", "rayman", "sam-fisher", "santa-2020", "santa-claus", "sporewick", "thalia", "ula-galvani", "violet-evergreen", "whisker-twirl", "wolfgang-clawson", "wyatt-earn", "zephyria", "zoe-365", "1dl3", "al-titude", "blingsley", "chris-capella", "damian-jones", "jeff", "mr-turner", "ranger-sue", "sigurd", "sir-henry", "sojo", "zi-galvani", "chester", "goodman-jr", "gordon", "lee-vatori", "mark", "mr-goodman", "mrs-goodman"
    ]

    static func makeExportData(
        from recognized: [RecognizedSM],
        directory: [SMDirectoryEntry]? = nil
    ) throws -> Data {
        // Keep optional arg for compatibility with existing call-sites/tests.
        _ = directory

        var payload: [String: SMTrackerBackupEntry] = [:]
        payload.reserveCapacity(canonicalManagerKeys.count)

        for key in canonicalManagerKeys {
            payload[key] = .defaults
        }

        for manager in recognized {
            let key = trackerKey(forRecognized: manager)
            guard payload[key] != nil else {
                // Strict format: ignore unknown keys so output remains exact.
                continue
            }

            var item = payload[key] ?? .defaults
            item.unlocked = true
            item.rank = max(manager.stars ?? 0, 0)
            item.level = max(manager.stats.level?.current ?? manager.level ?? 1, 1)
            item.promoted = max(manager.stats.promotion?.current ?? 0, 0)
            item.fragments = max(manager.fragments ?? 0, 0)
            item.chronoExcluded = manager.chronoExcluded
            item.tierlistExcluded = manager.tierlistExcluded

            payload[key] = item
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func trackerKey(forDirectoryID id: String) -> String {
        id.replacingOccurrences(of: "_", with: "-")
    }

    static func trackerKey(forRecognized manager: RecognizedSM) -> String {
        if let id = manager.directoryMatch?.id, !id.isEmpty {
            return trackerKey(forDirectoryID: id)
        }

        let fallback = SMDirectoryEntry.slug(manager.resolvedName)
        return fallback.replacingOccurrences(of: "_", with: "-")
    }
}
