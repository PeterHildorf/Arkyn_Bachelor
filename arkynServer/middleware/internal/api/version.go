package api

import (
	"net/http"
)

type versionResponse struct {
	Version string `json:"version"`
}

func VersionHandler(w http.ResponseWriter, r *http.Request) {
	resp := versionResponse{
		Version: "1.22",
	}
	writeJSON(w, http.StatusOK, resp)
}
