package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestVersionHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/version", nil)
	w := httptest.NewRecorder()

	VersionHandler(w, req)

	// Tjek statuskode
	if w.Code != http.StatusOK {
		t.Errorf("forventet statuskode 200, fik %d", w.Code)
	}

	// Decode JSON-svaret og tjek versionfeltet
	var resp versionResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("kunne ikke decode JSON: %v", err)
	}

	if resp.Version == "" {
		t.Error("version-feltet er tomt")
	}
}
