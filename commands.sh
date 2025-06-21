# Run locally

docker container remove -f grafana && docker build -t grafana-integration:latest . && docker run -d -p 3000:8000 --name grafana grafana-api