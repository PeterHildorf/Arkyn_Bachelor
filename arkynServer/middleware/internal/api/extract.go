package api

import (
	"fmt"
	"io"
	"net/http"

	"arkyn/middleware/internal/ai"
	"arkyn/middleware/internal/ocr"
)

// confidenceThreshold is the minimum OCR score before we flag for review.
// Below this the result is returned immediately without calling Claude.
const confidenceThreshold = 0.60

// NewExtractHandler returns the handler for POST /api/v1/extract.
// It accepts a multipart image upload, runs Google Vision OCR, then
// calls Claude to structure the raw text into typed entities with UI actions.
func NewExtractHandler(visionClient *ocr.VisionClient, claude *ai.ClaudeClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// ----------------------------------------------------------------
		// 1. Parse multipart form (max 20 MB image)
		// ----------------------------------------------------------------
		if err := r.ParseMultipartForm(20 << 20); err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse("failed to parse multipart form: "+err.Error()))
			return
		}

		file, _, err := r.FormFile("image")
		if err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse("field 'image' is required in multipart form"))
			return
		}
		defer file.Close()

		imageBytes, err := io.ReadAll(file)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, errorResponse("failed to read uploaded image"))
			return
		}

		if len(imageBytes) == 0 {
			writeJSON(w, http.StatusBadRequest, errorResponse("uploaded image is empty"))
			return
		}

		// ----------------------------------------------------------------
		// 2. Google Cloud Vision OCR
		// ----------------------------------------------------------------
		ocrResult, err := visionClient.ExtractText(r.Context(), imageBytes)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, errorResponse(fmt.Sprintf("OCR failed: %v", err)))
			return
		}

		// ----------------------------------------------------------------
		// 3. Low-confidence guard – flag without calling Claude
		// ----------------------------------------------------------------
		if ocrResult.RawText == "" {
			writeJSON(w, http.StatusOK, ai.ExtractionResult{
				Entities:         []ai.Entity{},
				RawText:          "",
				Confidence:       ocrResult.Confidence,
				FlaggedForReview: true,
			})
			return
		}

		if ocrResult.Confidence > 0 && ocrResult.Confidence < confidenceThreshold {
			writeJSON(w, http.StatusOK, ai.ExtractionResult{
				Entities:         []ai.Entity{},
				RawText:          ocrResult.RawText,
				Confidence:       ocrResult.Confidence,
				FlaggedForReview: true,
			})
			return
		}

		// ----------------------------------------------------------------
		// 4. Claude: format raw OCR text into structured entities
		// ----------------------------------------------------------------
		entities, err := claude.FormatEntities(r.Context(), ocrResult.RawText, ocrResult.Confidence)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, errorResponse(fmt.Sprintf("entity formatting failed: %v", err)))
			return
		}

		writeJSON(w, http.StatusOK, ai.ExtractionResult{
			Entities:         entities,
			RawText:          ocrResult.RawText,
			Confidence:       ocrResult.Confidence,
			FlaggedForReview: false,
		})
	}
}
