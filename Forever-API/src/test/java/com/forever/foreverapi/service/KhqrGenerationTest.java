package com.forever.foreverapi.service;

import kh.gov.nbc.bakong_khqr.BakongKHQR;
import kh.gov.nbc.bakong_khqr.model.IndividualInfo;
import kh.gov.nbc.bakong_khqr.model.KHQRCurrency;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

/** The KHQR fields KhqrServiceImpl sends must be accepted by the Bakong SDK and survive a decode. */
class KhqrGenerationTest {

    @Test
    void generatesAValidDynamicUsdKhqr() {
        var info = new IndividualInfo();
        info.setBakongAccountId("forever_shop@aclb");
        info.setMerchantName("Forever");
        info.setMerchantCity("Phnom Penh");
        info.setCurrency(KHQRCurrency.USD);
        info.setAmount(45.5);
        info.setBillNumber("ORDER123");
        info.setExpirationTimestamp(Instant.now().plus(Duration.ofMinutes(10)).toEpochMilli());

        var result = BakongKHQR.generateIndividual(info);

        assertThat(result.getKHQRStatus().getCode()).as(result.getKHQRStatus().getMessage()).isZero();
        String qr = result.getData().getQr();
        assertThat(result.getData().getMd5()).hasSize(32);
        assertThat(BakongKHQR.verify(qr).getData().isValid()).isTrue();
        var decoded = BakongKHQR.decode(qr).getData();
        assertThat(decoded.getBakongAccountID()).isEqualTo("forever_shop@aclb");
        assertThat(decoded.getTransactionAmount()).isEqualTo("45.5");
        assertThat(decoded.getTransactionCurrency()).isEqualTo("840");
        assertThat(decoded.getBillNumber()).isEqualTo("ORDER123");
    }
}
