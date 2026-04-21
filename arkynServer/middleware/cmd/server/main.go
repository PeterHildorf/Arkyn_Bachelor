package main

import (
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"

	"arkyn/middleware/internal/ai"
	"arkyn/middleware/internal/api"
	"arkyn/middleware/internal/config"
)

func main() {
	// Load .env file if it exists (ignored in production where env vars are set directly)
	if err := godotenv.Load(); err != nil {
		if !os.IsNotExist(err) {
			log.Printf("Warning: could not load .env file: %v", err)
		}
	}

	cfg := config.Load()

	claudeClient := ai.NewClaudeClient(cfg.AnthropicAPIKey)

	router := api.NewRouter(claudeClient)

	log.Printf("Arkyn middleware server starting on %s", cfg.ServerAddr)
	if err := http.ListenAndServe(cfg.ServerAddr, router); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
