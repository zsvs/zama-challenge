package main

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestHealthz(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	healthz(w, req)
	if w.Code != 200 {
		t.Fatalf("healthz expected 200, got %d", w.Code)
	}
}

func TestSum(t *testing.T) {
	// Disable API key for unit test
	os.Setenv("REQUIRE_API_KEY", "false")
	req := httptest.NewRequest(http.MethodPost, "/sum", bytes.NewBufferString(`{"a":2,"b":3}`))
	w := httptest.NewRecorder()
	withAuth(sum)(w, req)
	if w.Code != 200 {
		t.Fatalf("sum expected 200, got %d", w.Code)
	}
	expected := `{"sum":5}` + "\n"
	if w.Body.String() != expected {
		t.Fatalf("unexpected body: %s", w.Body.String())
	}
}

func TestSumWithAPIKey(t *testing.T) {
	// Enable API key requirement
	os.Setenv("REQUIRE_API_KEY", "true")
	os.Setenv("API_KEY", "test-secret-key")
	defer func() {
		os.Setenv("REQUIRE_API_KEY", "false")
		os.Unsetenv("API_KEY")
	}()

	// Re-read the environment variables
	requireAPIKey = os.Getenv("REQUIRE_API_KEY") == "true"
	apiKey = os.Getenv("API_KEY")

	t.Run("without API key", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/sum", bytes.NewBufferString(`{"a":2,"b":3}`))
		w := httptest.NewRecorder()
		withAuth(sum)(w, req)
		if w.Code != http.StatusUnauthorized {
			t.Fatalf("expected 401 Unauthorized, got %d", w.Code)
		}
	})

	t.Run("with wrong API key", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/sum", bytes.NewBufferString(`{"a":2,"b":3}`))
		req.Header.Set("X-Api-Key", "wrong-key")
		w := httptest.NewRecorder()
		withAuth(sum)(w, req)
		if w.Code != http.StatusUnauthorized {
			t.Fatalf("expected 401 Unauthorized, got %d", w.Code)
		}
	})

	t.Run("with correct API key", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/sum", bytes.NewBufferString(`{"a":2,"b":3}`))
		req.Header.Set("X-Api-Key", "test-secret-key")
		w := httptest.NewRecorder()
		withAuth(sum)(w, req)
		if w.Code != http.StatusOK {
			t.Fatalf("expected 200 OK, got %d", w.Code)
		}
		expected := `{"sum":5}` + "\n"
		if w.Body.String() != expected {
			t.Fatalf("unexpected body: %s", w.Body.String())
		}
	})
}
