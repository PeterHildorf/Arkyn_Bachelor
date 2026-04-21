package api

import (
	"encoding/json"
	"net/http"

	"arkyn/middleware/internal/ai"
)

// analyzeRequest is the expected JSON body for POST /analyze.
type analyzeRequest struct {
	ImageBase64 string  `json:"image_base64"` // Base64-encoded image or video frame
	MimeType    string  `json:"mime_type"`    // e.g. "image/jpeg"
	OCRText     string  `json:"ocr_text"`     // Pre-extracted OCR text (from mobile app or server-side OCR)
	Confidence  float64 `json:"confidence"`   // OCR confidence score (0.0 – 1.0)
}

// analyzeResponse is the JSON returned after processing.
type analyzeResponse struct {
	Status                  string   `json:"status"`
	EquipmentIdentification string   `json:"equipment_identification"`
	GeneralGuidance         []string `json:"general_guidance"`
	SafetyNotes             []string `json:"safety_notes"`
	UncertaintyLevel        string   `json:"uncertainty_level"`
	FlaggedForReview        bool     `json:"flagged_for_review"`
}

// confidenceThreshold defines the minimum OCR confidence required before
// sending to AI. Below this, the request is flagged for manual review.
const confidenceThreshold = 0.60

// NewAnalyzeHandler returns an HTTP handler with the Claude client injected.
func NewAnalyzeHandler(claude *ai.ClaudeClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req analyzeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{
				"error": "invalid JSON body",
			})
			return
		}

		if req.OCRText == "" {
			writeJSON(w, http.StatusBadRequest, map[string]string{
				"error": "ocr_text is required",
			})
			return
		}

		// Flag low-confidence OCR results before sending to AI
		if req.Confidence > 0 && req.Confidence < confidenceThreshold {
			writeJSON(w, http.StatusOK, analyzeResponse{
				Status:           "flagged",
				FlaggedForReview: true,
				UncertaintyLevel: "high",
				SafetyNotes:      []string{"OCR confidence is low – please retake the image or verify manually."},
			})
			return
		}

		guidance, err := claude.AnalyzeOCRText(r.Context(), req.OCRText, req.Confidence)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{
				"error": err.Error(),
			})
			return
		}

		writeJSON(w, http.StatusOK, analyzeResponse{
			Status:                  "ok",
			EquipmentIdentification: guidance.EquipmentIdentification,
			GeneralGuidance:         guidance.GeneralGuidance,
			SafetyNotes:             guidance.SafetyNotes,
			UncertaintyLevel:        guidance.UncertaintyLevel,
			FlaggedForReview:        false,
		})
	}
}
