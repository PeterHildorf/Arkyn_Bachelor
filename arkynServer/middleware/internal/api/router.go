package api

import (
	"net/http"
)

// NewRouter sets up and returns the HTTP ServeMux with all routes.
func NewRouter() *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", HealthHandler)
	mux.HandleFunc("POST /analyze", AnalyzeHandler)
	mux.HandleFunc("GET /version", VersionHandler)

	return mux
}
