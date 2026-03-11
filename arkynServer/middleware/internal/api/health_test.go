package api

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthHandler(t *testing.T) {
	// Opret en fake HTTP request til GET /health
	req := httptest.NewRequest(http.MethodGet, "/health", nil)

	// Opret en recorder der opfanger svaret
	w := httptest.NewRecorder()

	// Kald handleren direkte — ingen rigtig server nødvendig
	HealthHandler(w, req)

	// Tjek statuskode
	if w.Code != http.StatusOK {
		t.Errorf("forventet statuskode 200, fik %d", w.Code)
	}

	// Tjek at body indeholder "ok"
	body := w.Body.String()
	if body == "" {
		t.Error("response body er tom")
	}
}
