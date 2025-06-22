package main

import (
	"bytes"
	"context"
	"errors"
	"io"
	"mime"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	backend "github.com/grafana/grafana-plugin-sdk-go/backend"
	"github.com/grafana/grafana-plugin-sdk-go/backend/log"
)

type plugin struct{}

func (p *plugin) CallResource(ctx context.Context, req *backend.CallResourceRequest, sender backend.CallResourceResponseSender) error {
	log.DefaultLogger.Info("CallResource received",
		"path", req.Path,
		"method", req.Method,
		"headers", req.Headers)

	if req.Path != "upload" || req.Method != http.MethodPost {
		log.DefaultLogger.Warn("Invalid path or method")
		return sender.Send(&backend.CallResourceResponse{
			Status: http.StatusNotFound,
			Body:   []byte("not found"),
		})
	}

	// Obtener el boundary de forma segura
	log.DefaultLogger.Info("Extracting boundary")
	boundary, err := getBoundary(req)
	if err != nil {
		log.DefaultLogger.Error("Failed to get boundary", "err", err)
		return senderError(sender, http.StatusBadRequest, err)
	}
	log.DefaultLogger.Info("Boundary extracted", "boundary", boundary)

	mr := multipart.NewReader(bytes.NewReader(req.Body), boundary)
	log.DefaultLogger.Info("Parsing multipart form")
	form, err := mr.ReadForm(32 << 20) // hasta 32 MB
	if err != nil {
		log.DefaultLogger.Error("Failed to parse multipart form", "err", err)
		return senderError(sender, http.StatusBadRequest, err)
	}
	log.DefaultLogger.Info("Form parsed", "formKeys", form.Value)

	files := form.File["file"]
	if len(files) == 0 {
		log.DefaultLogger.Error("No file part found in form")
		return senderError(sender, http.StatusBadRequest, errors.New("no file found"))
	}

	fheader := files[0]
	log.DefaultLogger.Info("File received", "filename", fheader.Filename, "size", fheader.Size)

	src, err := fheader.Open()
	if err != nil {
		log.DefaultLogger.Error("Failed to open uploaded file", "err", err)
		return senderError(sender, http.StatusInternalServerError, err)
	}
	defer src.Close()

	// Obtener nombre destino
	dstName := fheader.Filename
	if name := form.Value["name"]; len(name) > 0 && strings.TrimSpace(name[0]) != "" {
		dstName = name[0]
	}
	log.DefaultLogger.Info("Resolved destination filename", "dstName", dstName)

	// Usar ruta segura dentro del directorio de datos
	uploadsDir := filepath.Join(os.Getenv("GF_PATHS_DATA"), "uploads")
	log.DefaultLogger.Info("Creating upload dir", "path", uploadsDir)
	if err := os.MkdirAll(uploadsDir, 0o755); err != nil {
		log.DefaultLogger.Error("Failed to create uploads directory", "err", err)
		return senderError(sender, http.StatusInternalServerError, err)
	}

	dstPath := filepath.Join(uploadsDir, filepath.Base(dstName))
	log.DefaultLogger.Info("Creating file", "path", dstPath)
	dst, err := os.Create(dstPath)
	if err != nil {
		log.DefaultLogger.Error("Failed to create destination file", "err", err)
		return senderError(sender, http.StatusInternalServerError, err)
	}
	defer dst.Close()

	log.DefaultLogger.Info("Copying uploaded content to destination file")
	if _, err := io.Copy(dst, src); err != nil {
		log.DefaultLogger.Error("Failed to copy file", "err", err)
		return senderError(sender, http.StatusInternalServerError, err)
	}

	log.DefaultLogger.Info("File saved successfully", "path", dstPath)

	return sender.Send(&backend.CallResourceResponse{
		Status: http.StatusOK,
		Body:   []byte("saved"),
	})
}

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

func senderError(sender backend.CallResourceResponseSender, code int, err error) error {
	log.DefaultLogger.Error("upload error", "code", code, "err", err)
	return sender.Send(&backend.CallResourceResponse{
		Status: code,
		Body:   []byte(err.Error()),
	})
}

func getBoundary(req *backend.CallResourceRequest) (string, error) {
	for k, v := range req.Headers {
		if strings.EqualFold(k, "Content-Type") && len(v) > 0 {
			_, params, err := mime.ParseMediaType(v[0])
			if err != nil {
				return "", err
			}
			if b, ok := params["boundary"]; ok {
				return b, nil
			}
		}
	}
	return "", errors.New("missing multipart boundary")
}

// ──────────────────────────────────────────────

func main() {
	log.DefaultLogger.Info("Starting file-uploader plugin")
	backend.SetupPluginEnvironment("mapdevs-fileuploader-app")

	if err := backend.Serve(backend.ServeOpts{
		CallResourceHandler: &plugin{},
	}); err != nil {
		log.DefaultLogger.Error("plugin failed", "err", err)
		os.Exit(1)
	}
}
