package com.forever.foreverapi.client.minio;

import com.forever.foreverapi.config.AppProperties;
import com.forever.foreverapi.exception.ApiException;
import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.GetObjectResponse;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import io.minio.StatObjectArgs;
import io.minio.StatObjectResponse;
import io.minio.errors.ErrorResponseException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.io.InputStream;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
public class StorageService {

    private static final Set<String> IMAGE_TYPES = Set.of("image/png", "image/jpeg", "image/webp", "image/gif");

    private final MinioClient client;
    private final String bucket;

    public StorageService(AppProperties props) {
        var m = props.minio();
        this.client = MinioClient.builder().endpoint(m.endpoint()).credentials(m.accessKey(), m.secretKey()).build();
        this.bucket = m.bucket();
    }

    @PostConstruct
    void ensureBucket() {
        try {
            if (!client.bucketExists(BucketExistsArgs.builder().bucket(bucket).build())) {
                client.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
                log.info("Created MinIO bucket '{}'", bucket);
            }
        } catch (Exception e) {
            throw new IllegalStateException("Cannot reach MinIO bucket '" + bucket + "': " + e.getMessage(), e);
        }
    }

    /** Uploads an admin-provided image and returns its object key. */
    public String uploadImage(MultipartFile file, String folder) {
        String type = file.getContentType();
        if (type == null || !IMAGE_TYPES.contains(type)) {
            throw ApiException.badRequest("INVALID_IMAGE", "Only PNG, JPEG, WEBP or GIF images are allowed");
        }
        String ext = switch (type) {
            case "image/jpeg" -> "jpg";
            case "image/webp" -> "webp";
            case "image/gif" -> "gif";
            default -> "png";
        };
        String key = folder + "/" + UUID.randomUUID() + "." + ext;
        try (InputStream in = file.getInputStream()) {
            put(key, in, file.getSize(), type);
        } catch (IOException e) {
            throw ApiException.unavailable("STORAGE_ERROR", "Could not read uploaded file");
        }
        return key;
    }

    public void put(String key, InputStream in, long size, String contentType) {
        try {
            client.putObject(PutObjectArgs.builder().bucket(bucket).object(key)
                    .stream(in, size, -1L).contentType(contentType).build());
        } catch (Exception e) {
            log.error("MinIO upload failed for {}", key, e);
            throw ApiException.unavailable("STORAGE_ERROR", "Could not store file");
        }
    }

    public boolean exists(String key) {
        try {
            client.statObject(StatObjectArgs.builder().bucket(bucket).object(key).build());
            return true;
        } catch (ErrorResponseException e) {
            return false;
        } catch (Exception e) {
            throw ApiException.unavailable("STORAGE_ERROR", "Storage is unavailable");
        }
    }

    public StoredObject get(String key) {
        try {
            StatObjectResponse stat = client.statObject(StatObjectArgs.builder().bucket(bucket).object(key).build());
            GetObjectResponse stream = client.getObject(GetObjectArgs.builder().bucket(bucket).object(key).build());
            return new StoredObject(stream, stat.size(), stat.contentType(), stat.etag());
        } catch (ErrorResponseException e) {
            throw ApiException.notFound("File not found");
        } catch (Exception e) {
            throw ApiException.unavailable("STORAGE_ERROR", "Storage is unavailable");
        }
    }

    public void delete(String key) {
        try {
            client.removeObject(RemoveObjectArgs.builder().bucket(bucket).object(key).build());
        } catch (Exception e) {
            log.warn("Could not delete {} from MinIO: {}", key, e.getMessage());
        }
    }

    public record StoredObject(InputStream stream, long size, String contentType, String etag) {
    }
}
