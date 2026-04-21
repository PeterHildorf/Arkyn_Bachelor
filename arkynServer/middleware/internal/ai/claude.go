package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

const anthropicAPIURL = "https://api.anthropic.com/v1/messages"
const anthropicVersion = "2023-06-01"
const claudeModel = "claude-sonnet-4-6"

// MaintenanceGuidance is the structured response returned by Claude.
// All fields are mandatory – Claude is constrained to always fill them.
type MaintenanceGuidance struct {
	EquipmentIdentification string   `json:"equipment_identification"`
	GeneralGuidance         []string `json:"general_guidance"`
	SafetyNotes             []string `json:"safety_notes"`
	UncertaintyLevel        string   `json:"uncertainty_level"` // "low" | "medium" | "high"
}

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

// --- Internal request/response types ---

type claudeMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type claudeOutputFormat struct {
	Type   string      `json:"type"`
	Schema interface{} `json:"schema"`
}

type claudeOutputConfig struct {
	Format claudeOutputFormat `json:"format"`
}

type claudeRequest struct {
	Model        string              `json:"model"`
	MaxTokens    int                 `json:"max_tokens"`
	System       string              `json:"system"`
	Messages     []claudeMessage     `json:"messages"`
	OutputConfig *claudeOutputConfig `json:"output_config,omitempty"`
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

// maintenanceSchema is the JSON Schema Claude must follow in its response.
var maintenanceSchema = map[string]interface{}{
	"type": "object",
	"properties": map[string]interface{}{
		"equipment_identification": map[string]interface{}{
			"type":        "string",
			"description": "Identified equipment type, manufacturer, and model based on the OCR text",
		},
		"general_guidance": map[string]interface{}{
			"type":        "array",
			"items":       map[string]interface{}{"type": "string"},
			"description": "Step-by-step general maintenance guidance relevant to the identified equipment",
		},
		"safety_notes": map[string]interface{}{
			"type":        "array",
			"items":       map[string]interface{}{"type": "string"},
			"description": "Safety warnings and precautions the technician must be aware of",
		},
		"uncertainty_level": map[string]interface{}{
			"type":        "string",
			"enum":        []string{"low", "medium", "high"},
			"description": "How confident Claude is in the guidance based on the available OCR text",
		},
	},
	"required":             []string{"equipment_identification", "general_guidance", "safety_notes", "uncertainty_level"},
	"additionalProperties": false,
}

const systemPrompt = `You are a general-purpose industrial maintenance assistant.
A field technician has photographed a machine label, nameplate, or display.
You will receive the extracted OCR text from that image.

Your task:
- Identify the equipment type and manufacturer if possible
- Provide general, safe, step-by-step maintenance guidance
- List important safety precautions
- Be honest about uncertainty if the OCR text is incomplete or ambiguous

Important constraints:
- Do NOT give system-specific instructions requiring ERP or SAP access
- Do NOT invent part numbers, serial procedures, or proprietary steps
- Always prioritize safety over efficiency
- If the text is insufficient, set uncertainty_level to "high" and explain in the guidance`

// AnalyzeOCRText sends OCR-extracted text to Claude and returns structured maintenance guidance.
func (c *ClaudeClient) AnalyzeOCRText(ctx context.Context, ocrText string, confidence float64) (*MaintenanceGuidance, error) {
	userMessage := fmt.Sprintf(
		"OCR extracted text (confidence: %.0f%%):\n\n%s\n\nPlease provide maintenance guidance based on this.",
		confidence*100,
		ocrText,
	)

	payload := claudeRequest{
		Model:     claudeModel,
		MaxTokens: 2048,
		System:    systemPrompt,
		Messages: []claudeMessage{
			{Role: "user", Content: userMessage},
		},
		OutputConfig: &claudeOutputConfig{
			Format: claudeOutputFormat{
				Type:   "json_schema",
				Schema: maintenanceSchema,
			},
		},
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, anthropicAPIURL, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("failed to create HTTP request: %w", err)
	}
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", anthropicVersion)
	req.Header.Set("content-type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request to Claude failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read Claude response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("claude API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var claudeResp claudeResponse
	if err := json.Unmarshal(respBody, &claudeResp); err != nil {
		return nil, fmt.Errorf("failed to parse Claude response: %w", err)
	}

	// Guard: check stop reason before parsing content
	switch claudeResp.StopReason {
	case "refusal":
		return nil, fmt.Errorf("claude refused the request for safety reasons")
	case "max_tokens":
		return nil, fmt.Errorf("claude response was truncated – increase max_tokens")
	}

	if len(claudeResp.Content) == 0 {
		return nil, fmt.Errorf("empty response from Claude")
	}

	var guidance MaintenanceGuidance
	if err := json.Unmarshal([]byte(claudeResp.Content[0].Text), &guidance); err != nil {
		return nil, fmt.Errorf("failed to parse guidance JSON: %w", err)
	}

	return &guidance, nil
}
