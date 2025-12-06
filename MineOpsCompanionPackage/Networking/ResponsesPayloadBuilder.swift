// # File: Sources/MineOpsCompanionPackage/Networking/ResponsesPayloadBuilder.swift

import Foundation

enum ResponsesPayloadBuilder {
    static func strategy(model: String, prompt: String) -> [String: Any] {
        let enhancedPrompt = """
        You are a professional Idle Miner Tycoon strategist named MineOps AI.
        Your task is to design efficient manager rotation plans and resource timing guides.
        Respond with deep insight and realistic timing strategies.

        Your answer must describe:
        - The goal or target of the run (as provided)
        - Exact manager usage by position (Elevator, Warehouse, Shaft)
        - A time-based breakdown (with bullet lists, 0:00 timestamps, swaps, and rationale)
        - Optional AFK setup suggestions and conditional manager swaps
        - Use Markdown for readability (like **bold**, • bullets, and indents)

        Then summarize your recommendations as JSON in this format:
        {
          "comboName": "string",
          "recommendedManagers": ["string"],
          "strategySummary": "short summary of your logic",
          "estimatedMultiplier": number,
          "detailedPlan": "full markdown-formatted tactical walkthrough"
        }

        Be concise but smart, tactical, and practical for Idle Miner Tycoon play.

        PROMPT INPUT:
        \(prompt)
        """

        return [
            "model": model,
            "max_output_tokens": 600,
            "input": enhancedPrompt,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "strategy_schema",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "properties": [
                            "comboName": ["type": "string"],
                            "recommendedManagers": [
                                "type": "array",
                                "items": ["type": "string"]
                            ],
                            "strategySummary": ["type": "string"],
                            "estimatedMultiplier": ["type": "number"],
                            "detailedPlan": ["type": "string"]
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
                ]
            ]
        ]
    }
}