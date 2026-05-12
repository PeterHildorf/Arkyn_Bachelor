package api

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"arkyn/middleware/internal/ocr"
)

// processVideo extracts frames from the video file at 1 FPS,
// runs OCR on each frame, and returns the concatenated raw text and average confidence.
func processVideo(ctx context.Context, videoFile multipart.File, visionClient *ocr.VisionClient) (string, float64, error) {
	// Create a temporary directory for video and frames
	tempDir, err := os.MkdirTemp("", "arkyn_video_")
	if err != nil {
		return "", 0, fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tempDir) // Clean up everything when done

	// Save the uploaded video
	videoPath := filepath.Join(tempDir, "video.mp4")
	out, err := os.Create(videoPath)
	if err != nil {
		return "", 0, fmt.Errorf("failed to create temp video file: %w", err)
	}
	_, err = io.Copy(out, videoFile)
	out.Close()
	if err != nil {
		return "", 0, fmt.Errorf("failed to save video: %w", err)
	}

	// Extract frames using ffmpeg
	// -i input.mp4 -vf fps=1 frame_%03d.jpg
	framePattern := filepath.Join(tempDir, "frame_%03d.jpg")
	cmd := exec.CommandContext(ctx, "ffmpeg", "-i", videoPath, "-vf", "fps=1", framePattern)
	if output, err := cmd.CombinedOutput(); err != nil {
		return "", 0, fmt.Errorf("ffmpeg failed: %w, output: %s", err, string(output))
	}

	// Read generated frames
	frames, err := filepath.Glob(filepath.Join(tempDir, "frame_*.jpg"))
	if err != nil {
		return "", 0, fmt.Errorf("failed to list frames: %w", err)
	}

	if len(frames) == 0 {
		return "", 0, fmt.Errorf("no frames extracted from video")
	}

	// Process each frame
	var allText strings.Builder
	var totalConfidence float64
	var validFrames int

	for i, framePath := range frames {
		frameBytes, err := os.ReadFile(framePath)
		if err != nil {
			continue
		}

		ocrResult, err := visionClient.ExtractText(ctx, frameBytes)
		if err != nil || ocrResult.RawText == "" {
			continue
		}

		allText.WriteString(fmt.Sprintf("--- Frame %d ---\n%s\n\n", i+1, ocrResult.RawText))
		totalConfidence += ocrResult.Confidence
		validFrames++
	}

	if validFrames == 0 {
		return "", 0, nil // No text found in any frame
	}

	avgConfidence := totalConfidence / float64(validFrames)

	return allText.String(), avgConfidence, nil
}
