package api

import (
	"bytes"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestExtractHandler_Validation(t *testing.T) {
	// Ligesom ved analyze-tests sender vi 'nil' klienter ind for at sikre,
	// at requesten afvises i vores form-validering (HTTP 400) inden vi når til OCR og AI.
	handler := NewExtractHandler(nil, nil)

	t.Run("Missing Multipart Form", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/extract", bytes.NewReader([]byte("plain text instead of multipart")))
		req.Header.Set("Content-Type", "text/plain")
		w := httptest.NewRecorder()

		handler.ServeHTTP(w, req)

		if w.Code != http.StatusBadRequest {
			t.Errorf("Forventede HTTP 400 når multipart/form-data mangler, fik %d", w.Code)
		}
	})

	t.Run("Missing Image Field", func(t *testing.T) {
		// Vi bygger en rigtig multipart form, men 'glemmer' at tilføje billedet
		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		_ = writer.WriteField("some_other_field", "123")
		writer.Close()

		req := httptest.NewRequest(http.MethodPost, "/api/v1/extract", body)
		req.Header.Set("Content-Type", writer.FormDataContentType())
		w := httptest.NewRecorder()

		handler.ServeHTTP(w, req)

		if w.Code != http.StatusBadRequest {
			t.Errorf("Forventede HTTP 400 når 'image' feltet mangler i form, fik %d", w.Code)
		}
	})
}
