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
        // Build roster text with department labels
        let rosterText: String
        if managerRoster.isEmpty {
            rosterText = "None"
        } else {
            rosterText = managerRoster
                .map { "\($0.name) (\($0.department))" }
                .joined(separator: ", ")
        }
        
        // Check for unknown managers and build warning
        let unknownManagers = managerRoster.filter { $0.department == "Unknown" }
        let unknownWarning = unknownManagers.isEmpty ? "" : """
        
        WARNING: The following managers have unknown departments: \(unknownManagers.map(\.name).joined(separator: ", "))
        If you genuinely recognize them, assign correctly. Otherwise, EXCLUDE them from the plan.
        """
        
        // Max shaft for positioning guidance
        let maxShaft = mineContext.maxShaft
        
        return """
        You are MineOps AI, an expert Idle Miner Tycoon strategist.

        Design a **burst rotation** for this mine using ONLY the managers listed below.

        HARD RULES:
        • MINESHAFT managers: only in mine shafts (never elevator/warehouse)
        • ELEVATOR managers: only in elevator
        • WAREHOUSE managers: only in warehouse
        • There is **1 elevator slot**, **1 warehouse slot**, and multiple mine shafts.
        • Do NOT assign more than **1 manager per department at the same time**.
        • Only use manager NAMES that appear in "Available Managers".
        \(unknownWarning)

        YOUR JOB:
        1. Pick **one elevator manager**, **one warehouse manager**, and **3–5 mineshaft managers** that form a strong combo.
        2. Assume a burst window of about **5 minutes**.
        3. Produce a **precise rotation** with timestamps like 0:00, 0:10, 1:30 based on typical skill durations:
           - Long skills (~5m): fire at the start of the burst.
           - Medium (1–2m): layer after the long skills.
           - Short (30s): use as a finisher when income is already high.
        4. Assign strongest mineshaft managers to the deepest shafts (Shaft \(maxShaft), then \(maxShaft - 1), \(maxShaft - 2)…).

        THE PLAN MUST INCLUDE:
        • Exact **positioning**: which manager in Elevator, Warehouse, and which **shaft numbers** for mineshaft managers.
        • A **burst script**: step-by-step bullet points with timestamps in MM:SS format.
        • Short **rationale**: why these managers and why this order.
        • A rough **estimatedMultiplier** (overall cash gain during a well-executed burst).

        FORBIDDEN:
        • Vague phrases like "rotate every few minutes" or "maximize efficiency".
        • Assigning multiple managers to the same department at the same time.
        • Suggesting managers NOT in the Available Managers list.

        Return JSON:
        {
          "comboName": "creative strategy name",
          "recommendedManagers": ["names you actually use in the plan"],
          "strategySummary": "1–2 sentence summary of the burst loop",
          "estimatedMultiplier": number,
          "detailedPlan": "Markdown bullets with timestamps and shaft assignments (<= 800 chars)"
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

