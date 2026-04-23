package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

const anthropicAPIURL = "https://api.anthropic.com/v1/messages"
const anthropicVersion = "2023-06-01"
const claudeModel = "claude-haiku-4-5"

// ---------------------------------------------------------------------------
// Shared data models
// ---------------------------------------------------------------------------

// AllowedAction is one of the UI action tokens the server may assign.
// The iOS app reads these to decide which buttons to render for each entity.
type AllowedAction string

const (
	ActionCopy    AllowedAction = "copy"   // Copy value to clipboard
	ActionMaps    AllowedAction = "maps"   // Open in Apple/Google Maps (addresses only)
	ActionSearch  AllowedAction = "search" // Generic web search
	ActionAnalyze AllowedAction = "analyze" // Trigger /analyze endpoint
)

// Entity is one identified piece of information from a machine label.
type Entity struct {
	Label   string          `json:"label"`   // e.g. "Manufacturer", "Model", "Serial Number"
	Value   string          `json:"value"`   // Extracted value for this field
	Actions []AllowedAction `json:"actions"` // UI buttons available for this entity
}

// ExtractionResult is the top-level payload returned by /api/v1/extract.
type ExtractionResult struct {
	Entities         []Entity `json:"entities"`
	RawText          string   `json:"raw_text"`           // Original OCR text (for debugging)
	Confidence       float64  `json:"confidence"`         // OCR confidence (0.0–1.0)
	FlaggedForReview bool     `json:"flagged_for_review"` // true when confidence < threshold
}

// MaintenanceGuidance is the structured response returned by /api/v1/analyze.
// All fields are mandatory – Claude is constrained to always populate them.
type MaintenanceGuidance struct {
	TargetLabel             string   `json:"target_label"`
	TargetValue             string   `json:"target_value"`
	EquipmentContext        string   `json:"equipment_context"`         // Inferred from machine_model context
	GeneralGuidance         []string `json:"general_guidance"`
	SafetyNotes             []string `json:"safety_notes"`
	UncertaintyLevel        string   `json:"uncertainty_level"` // "low" | "medium" | "high"
}

// ---------------------------------------------------------------------------
// Claude client
// ---------------------------------------------------------------------------

// ClaudeClient wraps an HTTP client with the Anthropic API key.
type ClaudeClient struct {
	apiKey     string
	httpClient *http.Client
}

// NewClaudeClient creates a new Claude client.
func NewClaudeClient(apiKey string) *ClaudeClient {
	return &ClaudeClient{
		apiKey:     apiKey,
		httpClient: &http.Client{},
	}
}

// ---------------------------------------------------------------------------
// Internal Anthropic API types
// ---------------------------------------------------------------------------

type claudeMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type claudeRequest struct {
	Model     string          `json:"model"`
	MaxTokens int             `json:"max_tokens"`
	System    string          `json:"system"`
	Messages  []claudeMessage `json:"messages"`
}

type claudeResponse struct {
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
	StopReason string `json:"stop_reason"`
	Error      *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// ---------------------------------------------------------------------------
// FormatEntities – used by POST /api/v1/extract
// ---------------------------------------------------------------------------

const extractSystemPrompt = `You are a machine-label parser for an industrial maintenance app.
A technician has photographed a nameplate or label on industrial equipment.
You receive the raw OCR text and must extract structured information.

Return ONLY a valid JSON object with this exact structure (no markdown, no extra text):
{
  "entities": [
    {
      "label": "<field name in English>",
      "value": "<extracted value>",
      "actions": ["<action1>", "<action2>"]
    }
  ]
}

Rules for entities:
- Include only fields that are actually present in the OCR text
- Common labels: "Manufacturer", "Model", "Serial Number", "Part Number", "Voltage",
  "Current", "Power", "Frequency", "IP Rating", "Weight", "Year", "Address", "Country"
- Values should be cleaned up (fix obvious OCR artefacts where confident)

Rules for actions (assign only applicable ones):
- "copy"    → always include for every entity
- "maps"    → ONLY for entities whose label relates to a physical address or location
- "search"  → include for Manufacturer, Model, Part Number (useful for web search)
- "analyze" → include for Model and Serial Number (used to trigger maintenance analysis)

Never invent values not present in the OCR text.`

// FormatEntities calls Claude Haiku to parse OCR text into structured entities.
func (c *ClaudeClient) FormatEntities(ctx context.Context, rawText string, confidence float64) ([]Entity, error) {
	userMsg := fmt.Sprintf(
		"Raw OCR text (confidence %.0f%%):\n\n%s\n\nExtract all identifiable fields as entities.",
		confidence*100,
		rawText,
	)

	payload := claudeRequest{
		Model:     claudeModel,
		MaxTokens: 1024,
		System:    extractSystemPrompt,
		Messages:  []claudeMessage{{Role: "user", Content: userMsg}},
	}

	text, err := c.callClaude(ctx, payload)
	if err != nil {
		return nil, err
	}

	var result struct {
		Entities []Entity `json:"entities"`
	}
	cleanedText := cleanJSONResponse(text)
	if err := json.Unmarshal([]byte(cleanedText), &result); err != nil {
		return nil, fmt.Errorf("failed to parse entity JSON from Claude: %w (raw: %s)", err, text)
	}

	return result.Entities, nil
}

// ---------------------------------------------------------------------------
// AnalyzeTarget – used by POST /api/v1/analyze
// ---------------------------------------------------------------------------

const analyzeSystemPrompt = `You are a general-purpose industrial maintenance assistant.
A field technician has identified a specific field on a machine label and wants
maintenance guidance focused on that particular value.

Return ONLY a valid JSON object with this exact structure (no markdown, no extra text):
{
  "target_label": "<the field the technician selected>",
  "target_value": "<the value of that field>",
  "equipment_context": "<brief description of what this equipment appears to be>",
  "general_guidance": ["<step 1>", "<step 2>", "..."],
  "safety_notes": ["<safety note 1>", "..."],
  "uncertainty_level": "<low|medium|high>"
}

Important constraints:
- Do NOT give instructions requiring ERP, SAP, or internal company systems
- Do NOT invent part numbers, proprietary service procedures, or specific torque values
  unless they are standard industry values
- Always prioritize safety over efficiency
- If information is insufficient, set uncertainty_level to "high" and explain in guidance
- general_guidance must have at least 3 steps
- safety_notes must have at least 2 items`

// AnalyzeTargetRequest groups the data sent from iOS when the user taps "analyze".
type AnalyzeTargetRequest struct {
	TargetLabel  string   `json:"target_label"`  // e.g. "Model"
	TargetValue  string   `json:"target_value"`  // e.g. "SEW Eurodrive MDX61B"
	MachineModel string   `json:"machine_model"` // Best-known model from extract (may equal TargetValue)
	Context      []Entity `json:"context"`       // All other entities for background context
}

// AnalyzeTarget calls Claude to produce focused maintenance guidance.
func (c *ClaudeClient) AnalyzeTarget(ctx context.Context, req AnalyzeTargetRequest) (*MaintenanceGuidance, error) {
	// Build a concise context string from the surrounding entities
	contextLines := ""
	for _, e := range req.Context {
		contextLines += fmt.Sprintf("  %s: %s\n", e.Label, e.Value)
	}

	userMsg := fmt.Sprintf(
		"The technician wants maintenance guidance for:\n"+
			"  Field: %s\n"+
			"  Value: %s\n\n"+
			"Additional label context (do not focus on these, use only as background):\n%s\n"+
			"Provide targeted maintenance guidance for this specific field/value.",
		req.TargetLabel,
		req.TargetValue,
		contextLines,
	)

	payload := claudeRequest{
		Model:     claudeModel,
		MaxTokens: 2048,
		System:    analyzeSystemPrompt,
		Messages:  []claudeMessage{{Role: "user", Content: userMsg}},
	}

	text, err := c.callClaude(ctx, payload)
	if err != nil {
		return nil, err
	}

	var guidance MaintenanceGuidance
	cleanedText := cleanJSONResponse(text)
	if err := json.Unmarshal([]byte(cleanedText), &guidance); err != nil {
		return nil, fmt.Errorf("failed to parse guidance JSON from Claude: %w (raw: %s)", err, text)
	}

	return &guidance, nil
}

// ---------------------------------------------------------------------------
// Internal: shared HTTP call to Anthropic
// ---------------------------------------------------------------------------

func (c *ClaudeClient) callClaude(ctx context.Context, payload claudeRequest) (string, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal Claude request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, anthropicAPIURL, bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("failed to create HTTP request: %w", err)
	}
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", anthropicVersion)
	req.Header.Set("content-type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("HTTP request to Claude failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read Claude response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("claude API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var claudeResp claudeResponse
	if err := json.Unmarshal(respBody, &claudeResp); err != nil {
		return "", fmt.Errorf("failed to parse Claude response envelope: %w", err)
	}

	switch claudeResp.StopReason {
	case "refusal":
		return "", fmt.Errorf("claude refused the request for safety reasons")
	case "max_tokens":
		return "", fmt.Errorf("claude response was truncated – increase max_tokens")
	}

	if len(claudeResp.Content) == 0 {
		return "", fmt.Errorf("empty response from Claude")
	}

	return claudeResp.Content[0].Text, nil
}

// cleanJSONResponse removes markdown code block formatting if Claude includes it.
func cleanJSONResponse(text string) string {
	text = strings.TrimSpace(text)
	if strings.HasPrefix(text, "```json") {
		text = strings.TrimPrefix(text, "```json")
	} else if strings.HasPrefix(text, "```") {
		text = strings.TrimPrefix(text, "```")
	}
	if strings.HasSuffix(text, "```") {
		text = strings.TrimSuffix(text, "```")
	}
	return strings.TrimSpace(text)
}
