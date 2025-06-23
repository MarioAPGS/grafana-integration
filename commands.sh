
cd mapdevs-fileuploader-app

npm install
npm run build
go mod tidy && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dist/mapdevs-fileuploader-app ./src/backend/main.go
cd ..
# Run locally
docker container remove -f grafana && docker build -t grafana-integration:latest . && docker run -p 3000:3000 --name grafana grafana-integration