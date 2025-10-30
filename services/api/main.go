package main

import (
	"context"
	"encoding/json"
	"errors"
	"expvar"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
)

type sumReq struct {
	A int `json:"a"`
	B int `json:"b"`
}
type sumResp struct {
	Sum int `json:"sum"`
}

var (
	startTime     = time.Now()
	sumCounter    = expvar.NewInt("sum_requests_total")
	buildInfo     = expvar.NewMap("build_info")
	requireAPIKey = os.Getenv("REQUIRE_API_KEY") == "true"
	apiKey        = os.Getenv("API_KEY")
	ready         = false
)

// main initializes and starts the HTTP server with health endpoints, metrics, and graceful shutdown.
func main() {
	buildInfo.Set("version", expvar.Func(func() any { return "v0.1.0" }))
	buildInfo.Set("go", expvar.Func(func() any { return "1.25.3" }))

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthz)
	mux.HandleFunc("/readyz", readyz)
	mux.HandleFunc("/sum", withAuth(sum))
	// Optional: expose expvar at /metrics (JSON format)
	mux.Handle("/metrics", expvar.Handler())

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           loggingMiddleware(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}

	// Readiness gate ~2s after boot to simulate warmup
	go func() {
		time.Sleep(2 * time.Second)
		ready = true
	}()

	// Graceful shutdown
	go func() {
		sigc := make(chan os.Signal, 1)
		signal.Notify(sigc, syscall.SIGINT, syscall.SIGTERM)
		<-sigc
		log.Printf(`{"level":"info","msg":"shutting down"}`)
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(ctx)
	}()

	log.Printf(`{"level":"info","msg":"starting api","addr":":8080","require_api_key":%v}`, requireAPIKey)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("server error: %v", err)
	}
}

// healthz handles the health check endpoint and returns service status with uptime.
func healthz(w http.ResponseWriter, r *http.Request) {
	uptime := time.Since(startTime).Seconds()
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"status":"ok","uptime_seconds":` + strconv.FormatFloat(uptime, 'f', 1, 64) + `}`))
}

// readyz handles the readiness probe and returns 200 only when the service is ready to accept traffic.
func readyz(w http.ResponseWriter, r *http.Request) {
	if !ready {
		http.Error(w, "not ready", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ready"))
}

// sum handles POST requests to add two integers and returns their sum as JSON.
func sum(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	defer r.Body.Close()
	var req sumReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad json", http.StatusBadRequest)
		return
	}
	sumCounter.Add(1)
	resp := sumResp{Sum: req.A + req.B}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

// withAuth wraps an HTTP handler with API key authentication when REQUIRE_API_KEY is enabled.
func withAuth(inner http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// health/readiness are handled by other handlers; this wraps /sum.
		if requireAPIKey {
			key := r.Header.Get("X-Api-Key")
			if apiKey == "" || key != apiKey {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
		}
		inner.ServeHTTP(w, r)
	}
}

// loggingMiddleware wraps an HTTP handler to log request details including method, path, status, and duration.
func loggingMiddleware(inner http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ww := &respWriter{ResponseWriter: w, status: 200}
		inner.ServeHTTP(ww, r)
		elapsed := time.Since(start)
		log.Printf(`{"time":"%s","remote_addr":"%s","method":"%s","path":"%s","status":%d,"duration_ms":%d}`,
			time.Now().Format(time.RFC3339Nano), r.RemoteAddr, r.Method, r.URL.Path, ww.status, elapsed.Milliseconds())
	})
}

type respWriter struct {
	http.ResponseWriter
	status int
}

// WriteHeader captures the HTTP status code and passes it to the underlying ResponseWriter.
func (rw *respWriter) WriteHeader(code int) {
	rw.status = code
	rw.ResponseWriter.WriteHeader(code)
}
