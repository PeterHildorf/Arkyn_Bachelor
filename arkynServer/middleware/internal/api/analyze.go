package api

import (
	"encoding/json"
	"net/http"

	"arkyn/middleware/internal/ai"
)

// analyzeRequest is the JSON body expected by POST /api/v1/analyze.
// The iOS app sends the entity the technician tapped "analyze" on,
// plus any other entities from extract as hidden context.
type analyzeRequest struct {
	TargetLabel  string      `json:"target_label"`  // e.g. "Model"
	TargetValue  string      `json:"target_value"`  // e.g. "SEW Eurodrive MDX61B"
	MachineModel string      `json:"machine_model"` // Best‑guess model (may equal TargetValue)
	Context      []ai.Entity `json:"context"`       // Other entities from the extract result
}

// NewAnalyzeHandler returns the handler for POST /api/v1/analyze.
func NewAnalyzeHandler(claude *ai.ClaudeClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// ----------------------------------------------------------------
		// 1. Decode JSON body
		// ----------------------------------------------------------------
		var req analyzeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse("invalid JSON body"))
			return
		}

		if req.TargetLabel == "" || req.TargetValue == "" {
			writeJSON(w, http.StatusBadRequest, errorResponse("target_label and target_value are required"))
			return
		}

		// ----------------------------------------------------------------
		// 2. Call Claude for focused maintenance guidance
		// ----------------------------------------------------------------
		guidance, err := claude.AnalyzeTarget(r.Context(), ai.AnalyzeTargetRequest{
			TargetLabel:  req.TargetLabel,
			TargetValue:  req.TargetValue,
			MachineModel: req.MachineModel,
			Context:      req.Context,
		})
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, errorResponse(err.Error()))
			return
		}

		writeJSON(w, http.StatusOK, guidance)
	}
}
