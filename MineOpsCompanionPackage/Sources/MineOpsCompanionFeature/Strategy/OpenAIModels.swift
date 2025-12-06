import Foundation

// MARK: - Strategy Prompt

struct ManagerRosterEntry: Codable, Hashable {
    let name: String
    let department: String
}

struct StrategyPrompt: Codable, Hashable {
    let mineContext: MineContext
    let managerRoster: [ManagerRosterEntry]
    let goal: String

    var text: String {
        let rosterText: String
        if managerRoster.isEmpty {
            rosterText = "None"
        } else {
            rosterText = managerRoster
                .map { "\($0.name) (\($0.department))" }
                .joined(separator: ", ")
        }
        
        // Check for unknown managers
        let unknownManagers = managerRoster.filter { $0.department == "Unknown" }
        let unknownWarning = unknownManagers.isEmpty ? "" : """
        
        WARNING: The following managers have unknown departments: \(unknownManagers.map(\.name).joined(separator: ", "))
        If you recognize these managers, assign them to the correct position. Otherwise, exclude them from the strategy.
        """
        
        return """
        You are MineOps AI, an expert Idle Miner Tycoon strategist.
        Design a concise manager rotation plan with timing guidance.

        CRITICAL DEPARTMENT RULES:
        • MINESHAFT managers = ONLY in mine shafts (never elevator/warehouse)
        • ELEVATOR managers = ONLY in elevator (never shafts/warehouse)
        • WAREHOUSE managers = ONLY in warehouse (never elevator/shafts)
        • Do NOT recommend managers for wrong positions
        • ONLY use managers from the "Available Managers" list below
        \(unknownWarning)

        Include:
        - Manager assignments by correct position (respect department restrictions above)
        - Timed rotation steps (use 0:00 format, bullet points)
        - Swap rationale and optional AFK setup
        - Use **bold** and • bullets for clarity
        - Create a memorable combo name (e.g. "Speed Demon Loop", "Warehouse Blitz")

        Return JSON:
        {
          "comboName": "creative strategy name",
          "recommendedManagers": ["manager names used"],
          "strategySummary": "1-2 sentence summary",
          "estimatedMultiplier": number,
          "detailedPlan": "markdown tactical plan (keep under 800 chars)"
        }

        INPUT:
        Mine: \(mineContext.promptDescription)
        Available Managers: \(rosterText)
        Goal: \(goal)
        """
    }

    var cacheKey: String {
        let managerKeys = managerRoster.map { $0.name }.joined(separator: ",")
        return "\(mineContext.cacheKey)|\(managerKeys)|\(goal.lowercased())"
    }
}

// MARK: - Responses API Helpers

struct ResponsesEnvelope: Decodable {
    struct Output: Decodable {
        struct Content: Decodable {
            let type: String?
            let text: String?
        }

        let content: [Content]
    }

    let output: [Output]?
    let outputText: [String]?

    var firstText: String? {
        if let text = output?
            .compactMap({ output -> String? in
                output.content
                    .compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first(where: { !$0.isEmpty })
            })
            .first {
            return text
        }

        if let fallback = outputText?
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return fallback
        }

        return nil
    }
}

enum ResponsesPayloadBuilder {
    static func strategy(model: String, prompt: String) -> [String: Any] {
        let payload: [String: Any] = [
            "model": model,
            "input": prompt,
            "text": structuredTextFormat(
                name: "strategy_schema",
                schema: strategySchema
            ),
            "max_output_tokens": 1200
        ]

        print("🧾 Final payload:", payload)
        return payload
    }

    static func managerDetection(model: String, prompt: String, base64Image: String) -> [String: Any] {
        let payload: [String: Any] = [
            "model": model,
            "input": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "input_image", "image_data": base64Image]
                    ]
                ]
            ],
            "text": structuredTextFormat(
                name: "manager_schema",
                schema: managerSchema
            ),
            "max_output_tokens": 200
        ]

        print("🧾 Final payload (detection):", payload)
        return payload
    }

    private static func structuredTextFormat(name: String, schema: [String: Any]) -> [String: Any] {
        [
            "format": [
                "type": "json_schema",
                "name": name,
                "strict": true,
                "schema": schema
            ]
        ]
    }

    private static var strategySchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "comboName": [
                    "type": "string",
                    "description": "Display name for the recommended manager combo"
                ],
                "recommendedManagers": [
                    "type": "array",
                    "items": [
                        "type": "string",
                        "description": "Manager name"
                    ],
                    "minItems": 1,
                    "description": "List of managers to assign"
                ],
                "strategySummary": [
                    "type": "string",
                    "description": "How to apply the combo for this mine setup"
                ],
                "estimatedMultiplier": [
                    "type": "number",
                    "description": "Expected production multiplier from the combo"
                ],
                "detailedPlan": [
                    "type": "string",
                    "description": "Markdown-formatted tactical walkthrough"
                ]
            ],
            "required": [
                "comboName",
                "recommendedManagers",
                "strategySummary",
                "estimatedMultiplier",
                "detailedPlan"
            ],
            "additionalProperties": false
        ]
    }

    private static var managerSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "manager": [
                    "type": "string",
                    "description": "Detected Idle Miner Tycoon manager name"
                ]
            ],
            "required": ["manager"],
            "additionalProperties": false
        ]
    }
}

struct OpenAIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}

