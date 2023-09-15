source .env
TIMESTAMP=$(date +%Y%m%d%H%M%S)
npm run build
cp -r ./node_modules dist/
cd dist
find . -name "*.zip" -type f -delete
zip -rq ../lambda_function_"$TIMESTAMP".zip .
cd .. && rm -rf dist
terraform apply -auto-approve \
  -var lambdasVersion="$TIMESTAMP" \
  -var REDIS_DB_PATH="$REDIS_DB_PATH" \
  -var REDIS_PASS="$REDIS_PASS"
rm lambda_function_*