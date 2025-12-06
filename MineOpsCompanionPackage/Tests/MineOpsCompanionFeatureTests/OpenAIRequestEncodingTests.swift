import Foundation
import Testing
@testable import MineOpsCompanionFeature

struct OpenAIRequestEncodingTests {
    @Test("OpenAI request matches Responses API schema")
    func encodesExpectedPayload() throws {
        let root = AIStrategyEngine.debugPayload(prompt: "Test prompt")

        // ✅ Updated key set for /v1/responses
        #expect(Set(root.keys) == ["model", "input", "text", "max_output_tokens"])
        #expect(root["model"] as? String == "gpt-4o-mini")

        // ✅ Validate simple text input
        #expect(root["input"] as? String == "Test prompt")

        // ✅ Validate structured text format block
        let text = try #require(root["text"] as? [String: Any])
        let format = try #require(text["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")

        #expect(format["name"] as? String == "strategy_schema")
        #expect(format["strict"] as? Bool == true)

        let schema = try #require(format["schema"] as? [String: Any])
        #expect(schema["type"] as? String == "object")
        #expect(schema["additionalProperties"] as? Bool == false)

        let properties = try #require(schema["properties"] as? [String: Any])
        #expect(Set(properties.keys) == [
            "comboName",
            "estimatedMultiplier",
            "recommendedManagers",
            "strategySummary",
            "detailedPlan"
        ])

        let recommended = try #require(properties["recommendedManagers"] as? [String: Any])
        #expect(recommended["type"] as? String == "array")
        let items = try #require(recommended["items"] as? [String: Any])
        #expect(items["type"] as? String == "string")

        let required = try #require(schema["required"] as? [String])
        #expect(Set(required) == [
            "comboName",
            "recommendedManagers",
            "strategySummary",
            "estimatedMultiplier",
            "detailedPlan"
        ])
    }

        @Test("Decodes strategy from Responses API payload")
        func decodesStrategyFromResponseEnvelope() throws {
                let rawResponse = #"""
                {
                    "id": "resp_sample",
                    "object": "response",
                    "created_at": 1762291510,
                    "status": "completed",
                    "output": [
                        {
                            "id": "msg_sample",
                            "type": "message",
                            "status": "completed",
                            "role": "assistant",
                            "content": [
                                {
                                    "type": "output_text",
                                    "annotations": [],
                                    "logprobs": [],
                                    "text": "{\"comboName\":\"Frontier Powerhouse\",\"recommendedManagers\":[\"Al Titude\",\"Blingsley\",\"Chris Capella\",\"Cliff Walker\",\"Damian Jones\",\"H4V0C\"],\"strategySummary\":\"Utilize Al Titude for speed, Blingsley for capacity, and combine the earnings boosts from Chris Capella and Damian Jones to maximize production for the Frontier Mine. H4V0C's efficiency boosts also complement the overall strategy by enhancing resource extraction.\",\"estimatedMultiplier\":5.0}"
                                }
                            ]
                        }
                    ]
                }
                """#.data(using: .utf8)

                let rawData = try #require(rawResponse)
                let envelope = try JSONDecoder().decode(ResponsesEnvelope.self, from: rawData)
                let jsonString = try #require(envelope.firstText)
                let strategyData = try #require(jsonString.data(using: .utf8))
                let strategy = try JSONDecoder().decode(StrategyResponse.self, from: strategyData)

                        #expect(strategy.comboName == "Frontier Powerhouse")
                        #expect(strategy.recommendedManagers == ["Al Titude", "Blingsley", "Chris Capella", "Cliff Walker", "Damian Jones", "H4V0C"])
                        #expect(strategy.strategySummary.starts(with: "Utilize Al Titude"))
                        #expect(strategy.estimatedMultiplier == 5.0)
        }
}
