package com.forever.foreverapi.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Swagger UI shows two definitions in its "Select a definition" dropdown:
 * the customer-facing API and the admin API.
 */
@Configuration
public class OpenApiConfig {

    public static final String BEARER = "bearerAuth";

    @Bean
    OpenAPI foreverOpenApi() {
        return new OpenAPI()
                .info(new Info().title("Forever API").version("1.0"))
                .components(new Components().addSecuritySchemes(BEARER, new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")))
                .addSecurityItem(new SecurityRequirement().addList(BEARER));
    }

    @Bean
    GroupedOpenApi userApi() {
        return GroupedOpenApi.builder()
                .group("user")
                .displayName("User API")
                .pathsToMatch("/api/auth/**", "/api/users/**", "/api/products/**", "/api/cart/**",
                        "/api/orders/**", "/api/media/**")
                .addOpenApiCustomizer(api -> api.info(new Info()
                        .title("Forever API - User")
                        .version("1.0")
                        .description("""
                                Customer-facing API used by the web store and the mobile app.

                                **Sign in:** register -> verify the e-mail OTP (`/api/auth/verify-email`) or log in, \
                                then click **Authorize** and paste the `accessToken`.""")))
                .build();
    }

    @Bean
    GroupedOpenApi adminApi() {
        return GroupedOpenApi.builder()
                .group("admin")
                .displayName("Admin API")
                .pathsToMatch("/api/admin/**")
                .addOpenApiCustomizer(api -> api.info(new Info()
                        .title("Forever API - Admin")
                        .version("1.0")
                        .description("""
                                Back-office API for the admin panel: dashboard, product catalogue (with image upload to MinIO) \
                                and order management. Every endpoint needs an **ADMIN** access token.

                                Dev seed account: `admin@forever.com` / `Admin@12345` - log in through \
                                `POST /api/auth/login` in the **User API** definition, then **Authorize** here.""")))
                .build();
    }
}
