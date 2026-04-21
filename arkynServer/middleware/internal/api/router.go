package api

import (
	"net/http"

	"arkyn/middleware/internal/ai"
)

// NewRouter sets up and returns the HTTP ServeMux with all routes.
// The Claude client is injected here so handlers can use it.
func NewRouter(claude *ai.ClaudeClient) *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", HealthHandler)
	mux.HandleFunc("GET /version", VersionHandler)
	mux.HandleFunc("POST /analyze", NewAnalyzeHandler(claude))

	return mux
}
