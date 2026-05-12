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
		// 1. Parse multipart form (max 50 MB for videos)
		// ----------------------------------------------------------------
		if err := r.ParseMultipartForm(50 << 20); err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse("failed to parse multipart form: "+err.Error()))
			return
		}

		var rawText string
		var confidence float64

		// Check if it's an image
		imageFile, _, errImage := r.FormFile("image")
		if errImage == nil {
			defer imageFile.Close()
			imageBytes, err := io.ReadAll(imageFile)
			if err != nil {
				writeJSON(w, http.StatusInternalServerError, errorResponse("failed to read uploaded image"))
				return
			}
			if len(imageBytes) == 0 {
				writeJSON(w, http.StatusBadRequest, errorResponse("uploaded image is empty"))
				return
			}
			
			// ----------------------------------------------------------------
			// 2a. Google Cloud Vision OCR (Image)
			// ----------------------------------------------------------------
			ocrResult, err := visionClient.ExtractText(r.Context(), imageBytes)
			if err != nil {
				writeJSON(w, http.StatusInternalServerError, errorResponse(fmt.Sprintf("OCR failed: %v", err)))
				return
			}
			rawText = ocrResult.RawText
			confidence = ocrResult.Confidence
		} else {
			// Check if it's a video
			videoFile, _, errVideo := r.FormFile("video")
			if errVideo != nil {
				writeJSON(w, http.StatusBadRequest, errorResponse("field 'image' or 'video' is required in multipart form"))
				return
			}
			defer videoFile.Close()

			// ----------------------------------------------------------------
			// 2b. Video Processing (Extract Frames + OCR)
			// ----------------------------------------------------------------
			var err error
			rawText, confidence, err = processVideo(r.Context(), videoFile, visionClient)
			if err != nil {
				writeJSON(w, http.StatusInternalServerError, errorResponse(fmt.Sprintf("video processing failed: %v", err)))
				return
			}
		}

		// ----------------------------------------------------------------
		// 3. Low-confidence guard – flag without calling Claude
		// ----------------------------------------------------------------
		if rawText == "" {
			writeJSON(w, http.StatusOK, ai.ExtractionResult{
				Entities:         []ai.Entity{},
				RawText:          "",
				Confidence:       confidence,
				FlaggedForReview: true,
			})
			return
		}

		if confidence > 0 && confidence < confidenceThreshold {
			writeJSON(w, http.StatusOK, ai.ExtractionResult{
				Entities:         []ai.Entity{},
				RawText:          rawText,
				Confidence:       confidence,
				FlaggedForReview: true,
			})
			return
		}

		// ----------------------------------------------------------------
		// 4. Claude: format raw OCR text into structured entities
		// ----------------------------------------------------------------
		entities, err := claude.FormatEntities(r.Context(), rawText, confidence)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, errorResponse(fmt.Sprintf("entity formatting failed: %v", err)))
			return
		}

		writeJSON(w, http.StatusOK, ai.ExtractionResult{
			Entities:         entities,
			RawText:          rawText,
			Confidence:       confidence,
			FlaggedForReview: false,
		})
	}
}
