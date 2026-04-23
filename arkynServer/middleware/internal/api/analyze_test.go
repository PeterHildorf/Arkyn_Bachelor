package api

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAnalyzeHandler_Validation(t *testing.T) {
	// Vi sender en "nil" Claude-klient ind, fordi vores validerings-tests
	// forventer, at koden returnerer en fejl (HTTP 400) *før* den overhovedet
	// forsøger at kontakte AI'en. Hvis den prøver at kontakte AI'en i disse tests,
	// vil den crashe (panic), hvilket netop beviser at valideringen fejlede.
	handler := NewAnalyzeHandler(nil)

	tests := []struct {
		name         string
		payload      []byte
		expectedCode int
	}{
		{
			name:         "Empty Body",
			payload:      []byte(``),
			expectedCode: http.StatusBadRequest,
		},
		{
			name:         "Missing TargetLabel",
			payload:      []byte(`{"target_value": "MDX61B"}`),
			expectedCode: http.StatusBadRequest,
		},
		{
			name:         "Missing TargetValue",
			payload:      []byte(`{"target_label": "Model"}`),
			expectedCode: http.StatusBadRequest,
		},
		{
			name:         "Invalid JSON Format",
			payload:      []byte(`{"target_label": "Model", "target_value": "MDX61B",]`),
			expectedCode: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/api/v1/analyze", bytes.NewReader(tt.payload))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			handler.ServeHTTP(w, req)

			if w.Code != tt.expectedCode {
				t.Errorf("Forventede HTTP %d for '%s', fik %d. Body: %s", tt.expectedCode, tt.name, w.Code, w.Body.String())
			}
		})
	}
}
