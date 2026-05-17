<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<#-- Paréntesis: el `!` solo se aplica si la expresión completa falla; sin
     ellos, si `locale` mismo es null (no solo `currentLanguageTag`), el
     evaluador tira InvalidReferenceException. Mismo patrón en el resto. -->
<html lang="${(locale.currentLanguageTag)!'es'}" class="${(properties.kcHtmlClass)!''}">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no" />
    <meta http-equiv="x-ua-compatible" content="ie=edge">
    <meta name="robots" content="noindex, nofollow">
    <title>${msg("loginTitle",(realm.displayName!''))}</title>
    <link rel="icon" href="${url.resourcesPath}/img/favicon.ico" />
    <#if properties.styles?has_content>
        <#list properties.styles?split(' ') as style>
            <link href="${url.resourcesPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
</head>

<body class="cartones-body ${bodyClass}">
    <div class="cartones-layout">

        <#-- =============================================================
             HERO PANEL — visible solo en ≥ md (CSS lo oculta en mobile)
             ============================================================= -->
        <aside class="cartones-hero" aria-hidden="true">
            <div class="cartones-hero__bg">
                <div class="cartones-hero__glow cartones-hero__glow--a"></div>
                <div class="cartones-hero__glow cartones-hero__glow--b"></div>
            </div>
            <div class="cartones-hero__content">
                <h1 class="cartones-brand">
                    <#-- Stagger letra-por-letra para fade-in animado. -->
                    <span class="cartones-brand__letter" style="--i:0">C</span><span class="cartones-brand__letter" style="--i:1">a</span><span class="cartones-brand__letter" style="--i:2">r</span><span class="cartones-brand__letter" style="--i:3">t</span><span class="cartones-brand__letter" style="--i:4">o</span><span class="cartones-brand__letter" style="--i:5">n</span><span class="cartones-brand__letter" style="--i:6">e</span><span class="cartones-brand__letter" style="--i:7">s</span>
                </h1>
                <p class="cartones-tagline">Distribución inteligente</p>
            </div>
        </aside>

        <#-- =============================================================
             FORM PANEL — el contenido real del login (o de cualquier
             template que use esta macro: reset password, OTP, etc).
             ============================================================= -->
        <main class="cartones-panel">
            <div class="cartones-card">

                <header class="cartones-card__head">
                    <h2 class="cartones-card__title">
                        <#if auth?has_content && auth.showUsername() && !auth.showResetCredentials()>
                            ${msg("loginTitle", (realm.displayName!''))}
                        <#else>
                            ${msg("loginAccountTitle")}
                        </#if>
                    </h2>
                    <#if auth?has_content && auth.showUsername() && !auth.showResetCredentials()>
                        <p class="cartones-card__subtitle">${auth.attemptedUsername}</p>
                    </#if>
                </header>

                <#-- Mensajes del backend (errores, warnings, info) -->
                <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
                    <div class="cartones-alert cartones-alert--${message.type}" role="alert">
                        <#if message.type = 'success'><span aria-hidden="true">✓</span></#if>
                        <#if message.type = 'warning'><span aria-hidden="true">⚠</span></#if>
                        <#if message.type = 'error'><span aria-hidden="true">✕</span></#if>
                        <#if message.type = 'info'><span aria-hidden="true">ⓘ</span></#if>
                        <span class="cartones-alert__text">${kcSanitize(message.summary)?no_esc}</span>
                    </div>
                </#if>

                <#-- Slot del form (lo aporta login.ftl, login-reset-password.ftl, etc.) -->
                <#nested "form">

                <#-- Slot del bloque de info/social providers -->
                <#if displayInfo>
                    <div class="cartones-info">
                        <#nested "info">
                    </div>
                </#if>

                <#if displayRequiredFields>
                    <p class="cartones-required-fields">
                        <span class="required">*</span> ${msg("requiredFields")}
                    </p>
                </#if>
            </div>

            <footer class="cartones-foot">
                <#if realm.internationalizationEnabled  && locale.supported?size gt 1>
                    <div class="cartones-locale">
                        <#list locale.supported as l>
                            <a class="cartones-locale__link <#if l.languageTag == locale.currentLanguageTag>cartones-locale__link--active</#if>" href="${l.url}">${l.label}</a>
                        </#list>
                    </div>
                </#if>
            </footer>
        </main>

    </div>
</body>
</html>
</#macro>
