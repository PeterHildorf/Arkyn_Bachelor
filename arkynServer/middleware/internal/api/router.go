package api

import (
	"net/http"

	"arkyn/middleware/internal/ai"
	"arkyn/middleware/internal/ocr"
)

// NewRouter sets up and returns the HTTP ServeMux with all routes.
// The Vision and Claude clients are injected here so handlers can use them.
func NewRouter(vision *ocr.VisionClient, claude *ai.ClaudeClient) *http.ServeMux {
	mux := http.NewServeMux()

	// Generic/Utility
	mux.HandleFunc("GET /health", HealthHandler)
	mux.HandleFunc("GET /version", VersionHandler)

	// API v1
	mux.HandleFunc("POST /api/v1/extract", NewExtractHandler(vision, claude))
	mux.HandleFunc("POST /api/v1/analyze", NewAnalyzeHandler(claude))

	return mux
}
