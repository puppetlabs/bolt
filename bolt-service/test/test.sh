curl --insecure -X POST -H "Content-Type: application/json" -d @request.json -E ../certs/127.0.0.1.crt --key ../certs/127.0.0.1.key -k https://localhost:8144/ssh/run_task
