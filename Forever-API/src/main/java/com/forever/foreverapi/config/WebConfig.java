package com.forever.foreverapi.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    static {
        // Resolved from the request credentials, not a query parameter: keep it out of the OpenAPI docs.
        org.springdoc.core.utils.SpringDocUtils.getConfig()
                .addRequestWrapperToIgnore(com.forever.foreverapi.common.security.ShopperRef.class);
    }

    private final AppProperties props;

    public WebConfig(AppProperties props) {
        this.props = props;
    }

    @Override
    public void addArgumentResolvers(java.util.List<org.springframework.web.method.support.HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(new ShopperArgumentResolver());
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns(props.cors().allowedOriginPatterns().split(","))
                .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .maxAge(3600);
    }

    @Controller
    static class RootRedirect {
        @GetMapping("/")
        String root() {
            return "redirect:/swagger-ui.html";
        }
    }
}
