ARG DB_LOCATION=/home/dynamodblocal/db
FROM amazon/dynamodb-local:3.1.0 AS install
USER root
RUN yum -y install awscli
USER dynamodblocal
# hadolint ignore=DL3025
ENV AWS_ACCESS_KEY_ID=GOSYNC
# hadolint ignore=DL3025
ENV AWS_SECRET_ACCESS_KEY=GOSYNC
ARG AWS_ENDPOINT=http://localhost:8000
ARG AWS_REGION=us-west-2
ARG DB_LOCATION
ARG TABLE_NAME=client-entity-dev
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

FROM amazon/dynamodb-local:3.1.0
ARG DB_LOCATION
COPY --chown=dynamodblocal:dynamodblocal --from=install ${DB_LOCATION} /db
CMD ["-jar", "DynamoDBLocal.jar", "-sharedDb", "-dbPath", "/db"]
