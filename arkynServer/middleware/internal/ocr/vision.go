package ocr

import (
	"context"
	"fmt"
	"os"

	vision "cloud.google.com/go/vision/v2/apiv1"
	visionpb "cloud.google.com/go/vision/v2/apiv1/visionpb"
)

// OCRResult holds the raw text and a confidence score produced by Google Vision.
type OCRResult struct {
	RawText    string  // Full document text extracted from the image
	Confidence float64 // Average symbol confidence (0.0 – 1.0)
}

// VisionClient wraps the Google Cloud Vision image annotator.
type VisionClient struct {
	client *vision.ImageAnnotatorClient
}

// NewVisionClient creates an authenticated Google Vision client.
// It relies on Application Default Credentials (ADC), which automatically
// reads the GOOGLE_APPLICATION_CREDENTIALS environment variable.
func NewVisionClient(ctx context.Context) (*VisionClient, error) {
	if os.Getenv("GOOGLE_APPLICATION_CREDENTIALS") == "" {
		return nil, fmt.Errorf("GOOGLE_APPLICATION_CREDENTIALS is not set in environment")
	}

	client, err := vision.NewImageAnnotatorClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create Vision client: %w", err)
	}

	return &VisionClient{client: client}, nil
}

// Close releases the underlying gRPC connection.
func (v *VisionClient) Close() {
	v.client.Close()
}

// ExtractText sends an image (raw bytes) to Google Cloud Vision and returns
// the detected text together with an average confidence score.
func (v *VisionClient) ExtractText(ctx context.Context, imageBytes []byte) (*OCRResult, error) {
	img := &visionpb.Image{
		Content: imageBytes,
	}

	req := &visionpb.BatchAnnotateImagesRequest{
		Requests: []*visionpb.AnnotateImageRequest{
			{
				Image: img,
				Features: []*visionpb.Feature{
					{Type: visionpb.Feature_DOCUMENT_TEXT_DETECTION},
				},
			},
		},
	}

	resp, err := v.client.BatchAnnotateImages(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("vision API call failed: %w", err)
	}

	if len(resp.Responses) == 0 {
		return nil, fmt.Errorf("empty response from Vision API")
	}

	res := resp.Responses[0]
	if res.Error != nil {
		return nil, fmt.Errorf("vision API returned error: %s", res.Error.Message)
	}

	annotation := res.FullTextAnnotation
	if annotation == nil || annotation.Text == "" {
		return &OCRResult{RawText: "", Confidence: 0}, nil
	}

	// Walk all symbol confidences and compute average.
	confidence := averageSymbolConfidence(annotation)

	return &OCRResult{
		RawText:    annotation.Text,
		Confidence: confidence,
	}, nil
}

// averageSymbolConfidence traverses the full-text annotation hierarchy and
// computes the mean symbol-level confidence. Returns 1.0 if no confidence data
// is available.
func averageSymbolConfidence(annotation *visionpb.TextAnnotation) float64 {
	var total float64
	var count int

	for _, page := range annotation.Pages {
		for _, block := range page.Blocks {
			for _, para := range block.Paragraphs {
				for _, word := range para.Words {
					for _, symbol := range word.Symbols {
						if symbol.Confidence > 0 {
							total += float64(symbol.Confidence)
							count++
						}
					}
				}
			}
		}
	}

	if count == 0 {
		return 1.0 // No confidence data –> assume full confidence
	}
	return total / float64(count)
}
