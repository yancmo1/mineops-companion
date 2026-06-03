// # File: Sources/MineOpsCompanionPackage/Networking/ResponsesPayloadBuilder.swift

import Foundation

enum ResponsesPayloadBuilder {
    static func strategy(model: String, prompt: String) -> [String: Any] {
        return [
            "model": model,
            "max_output_tokens": 2048,
            "input": prompt,
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