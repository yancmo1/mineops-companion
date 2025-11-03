//
//  PromptBuilder.swift
//  MineOpsCompanion
//
//  Created by Yancy Shepherd on 10/30/25.
//

import Foundation

// TODO: Define AdvisorContext and complete AI Advisor implementation

/*
/// Builds the prompt text sent to the AI Advisor or used by the local strategy engine.
/// Combines mine context, roster data, and baseline knowledge into one compact, structured message.
struct PromptBuilder {
    
    /// Generates a formatted text prompt for GPT or other models.
    static func build(from context: AdvisorContext) -> String {
        var prompt = """
        You are the MineOps AI Advisor for Idle Miner Tycoon. Your job is to analyze the provided Super Manager roster and mine context, then recommend the optimal assignments, promotions, or upgrades.

        Please output structured results as clear, numbered recommendations.
        Each recommendation should contain:
          • Manager name
          • Assigned mine/role
          • Reasoning (1 sentence)
          • Priority score (1–10)
          • Optional: synergy or boost note

        Rules:
          • Always assume baseline max stats are known.
          • Use only the data provided below.
          • Respond concisely in plain text. Do not use markdown formatting.

        -----
        CURRENT MINE CONTEXT
        Name: \(context.gameMines.first?.name ?? "Unknown")
        Level: \(context.gameMines.first?.level.description ?? "—")
        Type: \(context.gameMines.first?.type.rawValue ?? "Normal")
        -----
        """
        
        prompt += "\nROSTER SUMMARY\n"
        if context.roster.isEmpty {
            prompt += "No active Super Managers found.\n"
        } else {
            for sm in context.roster {
                prompt += """
                Name: \(sm.name)
                Role: \(sm.role)
                Rarity: \(sm.rarity)
                Level: \(sm.levelCurrent)/\(sm.levelMax)
                Promotion: \(sm.promotionLevel)/\(sm.promotionMax)
                Active Multiplier: \(sm.activeMultiplier)x
                Passive Multiplier: \(sm.passiveMultiplier)x
                Element Affinity: \(sm.elementAffinity)
                Mine Affinity: \(sm.mineAffinity)
                -----
                """
            }
        }
        
        prompt += """
        END OF DATA
        Please analyze this data and return up to 10 prioritized recommendations.
        """
        
        return prompt
    }
}
*/