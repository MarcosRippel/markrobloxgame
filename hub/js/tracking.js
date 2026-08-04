/* ============================================
   game.terpens.com.br — Meta Pixel + Google tag
   IDs alinhados ao site institucional Terpens
   (terpens.com.br / js/tracking.js)
   ============================================ */

(function () {
    "use strict";

    var DEFAULTS = {
        metaPixelId: "",
        // GA4 propriedade Terpens — stream web (mesmo ID do site principal por enquanto)
        googleGaId: "G-XDXFWNM48H",
        // Google Ads — conta Terpens
        googleAdsId: "AW-945957869",
        googleAdsConversionLabel: ""
    };

    var raw = window.TERPENS_TRACKING || {};
    var cfg = Object.assign({}, DEFAULTS);
    Object.keys(raw).forEach(function (k) {
        if (raw[k] !== "" && raw[k] != null) cfg[k] = raw[k];
    });
    window.TERPENS_TRACKING = cfg;

    function loadMeta(pixelId) {
        if (!pixelId) return;
        !(function (f, b, e, v, n, t, s) {
            if (f.fbq) return;
            n = f.fbq = function () {
                n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments);
            };
            if (!f._fbq) f._fbq = n;
            n.push = n;
            n.loaded = !0;
            n.version = "2.0";
            n.queue = [];
            t = b.createElement(e);
            t.async = !0;
            t.src = v;
            s = b.getElementsByTagName(e)[0];
            s.parentNode.insertBefore(t, s);
        })(window, document, "script", "https://connect.facebook.net/en_US/fbevents.js");
        window.fbq("init", pixelId);
        window.fbq("track", "PageView");
    }

    function loadGoogle(gaId, adsId) {
        var id = gaId || adsId;
        if (!id) return;

        var s = document.createElement("script");
        s.async = true;
        s.src = "https://www.googletagmanager.com/gtag/js?id=" + encodeURIComponent(id);
        document.head.appendChild(s);

        window.dataLayer = window.dataLayer || [];
        function gtag() {
            window.dataLayer.push(arguments);
        }
        window.gtag = gtag;
        gtag("js", new Date());
        if (gaId) {
            gtag("config", gaId, {
                content_group: "game_hub",
                page_title: document.title,
                page_location: window.location.href
            });
        }
        if (adsId) gtag("config", adsId);
    }

    loadMeta(cfg.metaPixelId);
    loadGoogle(cfg.googleGaId, cfg.googleAdsId);

    window.terpensTrackLead = function (extra) {
        extra = extra || {};
        try {
            if (typeof window.fbq === "function" && cfg.metaPixelId) {
                window.fbq("track", "Lead", extra);
            }
        } catch (_) {}

        try {
            if (typeof window.gtag === "function") {
                window.gtag(
                    "event",
                    "generate_lead",
                    Object.assign(
                        {
                            event_category: "lead",
                            event_label: extra.page || "game"
                        },
                        extra
                    )
                );

                if (cfg.googleAdsId && cfg.googleAdsConversionLabel) {
                    window.gtag("event", "conversion", {
                        send_to: cfg.googleAdsId + "/" + cfg.googleAdsConversionLabel
                    });
                }
            }
        } catch (_) {}
    };

    window.terpensTrackEvent = function (name, params) {
        try {
            if (typeof window.gtag === "function") {
                window.gtag("event", name, Object.assign({ content_group: "game_hub" }, params || {}));
            }
        } catch (_) {}
    };
})();
