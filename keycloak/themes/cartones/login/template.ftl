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
             HERO PANEL — banda decorativa con la marca. En mobile se ve
             compacto arriba del form (≈30vh); en desktop ocupa la columna
             izquierda completa con la lista de features.
             ============================================================= -->
        <aside class="cartones-hero">
            <div class="cartones-hero__bg">
                <div class="cartones-hero__glow cartones-hero__glow--a"></div>
                <div class="cartones-hero__glow cartones-hero__glow--b"></div>
                <#-- Pattern decorativo: grid de dots SVG con drift muy lento.
                     `userSpaceOnUse` hace que el pattern sea estable al
                     resize. La opacidad baja + el blur de los glows evitan
                     que distraiga del contenido. -->
                <svg class="cartones-hero__pattern" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">
                    <defs>
                        <pattern id="cartones-dots" x="0" y="0" width="32" height="32" patternUnits="userSpaceOnUse">
                            <circle cx="16" cy="16" r="1.2" fill="currentColor" />
                        </pattern>
                    </defs>
                    <rect width="100%" height="100%" fill="url(#cartones-dots)" />
                </svg>
            </div>

            <div class="cartones-hero__content">
                <h1 class="cartones-brand">
                    <span class="cartones-brand__overline">Gestión de</span>
                    <span class="cartones-brand__main">
                        <#-- Stagger letra-por-letra para fade-in animado. -->
                        <span class="cartones-brand__letter" style="--i:0">C</span><span class="cartones-brand__letter" style="--i:1">a</span><span class="cartones-brand__letter" style="--i:2">r</span><span class="cartones-brand__letter" style="--i:3">t</span><span class="cartones-brand__letter" style="--i:4">o</span><span class="cartones-brand__letter" style="--i:5">n</span><span class="cartones-brand__letter" style="--i:6">e</span><span class="cartones-brand__letter" style="--i:7">s</span>
                    </span>
                </h1>
                <p class="cartones-tagline">Plataforma de gestión y distribución</p>

                <ul class="cartones-features">
                    <li style="--i:0"><span class="cartones-features__check" aria-hidden="true">✓</span>Procesamiento unificado de Senete y Telebingo</li>
                    <li style="--i:1"><span class="cartones-features__check" aria-hidden="true">✓</span>Generación automatizada de archivos para impresión</li>
                    <li style="--i:2"><span class="cartones-features__check" aria-hidden="true">✓</span>Trazabilidad completa del histórico de entregas</li>
                </ul>
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
