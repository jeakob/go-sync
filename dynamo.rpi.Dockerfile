ARG DB_LOCATION=/home/dynamodblocal/db

FROM eclipse-temurin:21-jre AS install

RUN apt-get update && apt-get install -y curl unzip awscli && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -sL https://s3.us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.tar.gz \
    -o dynamodb.tar.gz && \
    tar -xzf dynamodb.tar.gz && \
    rm dynamodb.tar.gz

ARG DB_LOCATION
ARG AWS_ENDPOINT=http://localhost:8000
ARG AWS_REGION=us-west-2
ARG TABLE_NAME=client-entity-dev
ENV AWS_ACCESS_KEY_ID=GOSYNC
ENV AWS_SECRET_ACCESS_KEY=GOSYNC

COPY schema/dynamodb/ .

RUN mkdir -p ${DB_LOCATION} && \
    java -jar DynamoDBLocal.jar -sharedDb -dbPath ${DB_LOCATION} & \
    DYNAMO_PID=$! && \
    until aws dynamodb list-tables --endpoint-url ${AWS_ENDPOINT} --region ${AWS_REGION} > /dev/null 2>&1; do \
        echo "Waiting for DynamoDB..." && sleep 2; \
    done && \
    aws dynamodb create-table --cli-input-json file://table.json \
        --endpoint-url ${AWS_ENDPOINT} --region ${AWS_REGION} && \
    aws dynamodb update-time-to-live --table-name ${TABLE_NAME} \
        --time-to-live-specification "Enabled=true, AttributeName=ExpirationTime" \
        --endpoint-url ${AWS_ENDPOINT} --region ${AWS_REGION} && \
    kill $DYNAMO_PID

FROM eclipse-temurin:21-jre
ARG DB_LOCATION
WORKDIR /app
COPY --from=install /app/DynamoDBLocal.jar .
COPY --from=install /app/DynamoDBLocal_lib ./DynamoDBLocal_lib
COPY --from=install ${DB_LOCATION} /db

CMD ["java", "-jar", "DynamoDBLocal.jar", "-sharedDb", "-dbPath", "/db"]
