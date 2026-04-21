package config

import (
	"log"
	"os"
)

// Config holds all runtime configuration for the middleware.
type Config struct {
	AnthropicAPIKey string
	ServerAddr      string
}

// Load reads configuration from environment variables.
// The caller is responsible for loading .env before calling Load.
func Load() *Config {
	key := os.Getenv("ANTHROPIC_API_KEY")
	if key == "" {
		log.Fatal("ANTHROPIC_API_KEY is not set – add it to your .env file")
	}

	addr := os.Getenv("SERVER_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	return &Config{
		AnthropicAPIKey: key,
		ServerAddr:      addr,
	}
}
