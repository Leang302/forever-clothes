FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY build/libs/Forever-API-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8989
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
