# Use a minimal base image
FROM golang:1.21-alpine AS builder

# Set working directory inside container
WORKDIR /app

# Copy Go modules and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the Go application
RUN go build -o music_albums

# Use a lightweight runtime image
FROM alpine:latest

# Create non-root user
RUN adduser -D appuser

WORKDIR /app

# Copy built binary from the builder stage
COPY --from=builder /app/music_albums .

# Change ownership of the application
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Run the application
CMD ["./music_albums", "redis:6379"]

# Expose the port for the app
EXPOSE 9090