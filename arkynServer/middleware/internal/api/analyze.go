package api

import (
	"encoding/json"
	"net/http"
)

// analyzeRequest is the expected JSON body for POST /analyze.
type analyzeRequest struct {
	ImageBase64 string `json:"image_base64"` // Base64-encoded image or video frame
	MimeType    string `json:"mime_type"`    // e.g. "image/jpeg"
}

// analyzeResponse is the JSON returned after processing.
type analyzeResponse struct {
	Status  string `json:"status"`
	Message string `json:"message"`
	// Future fields: OCRText, Confidence, AIGuidance, etc.
}

// AnalyzeHandler receives an image payload, runs OCR + AI analysis,
// and returns structured maintenance guidance.
// POST /analyze
func AnalyzeHandler(w http.ResponseWriter, r *http.Request) {
	var req analyzeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid JSON body",
		})
		return
	}

	if req.ImageBase64 == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{
			"error": "image_base64 is required",
		})
		return
	}

	// TODO: pipe req.ImageBase64 through OCR service → AI service
	resp := analyzeResponse{
		Status:  "received",
		Message: "Image received. OCR and AI pipeline not yet implemented.",
	}
	writeJSON(w, http.StatusOK, resp)
}
