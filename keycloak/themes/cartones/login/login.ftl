<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>

    <#if section = "form">
        <form id="kc-form-login" class="cartones-form" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post" novalidate>

            <#if !usernameHidden??>
                <div class="cartones-field">
                    <label for="username" class="cartones-field__label">
                        <#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if>
                    </label>
                    <input
                        tabindex="1"
                        id="username"
                        class="cartones-field__input"
                        name="username"
                        value="${(login.username!'')}"
                        type="text"
                        autofocus
                        autocomplete="username"
                        aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                    />
                    <#if messagesPerField.existsError('username','password')>
                        <span id="input-error" class="cartones-field__error" aria-live="polite">
                            ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                        </span>
                    </#if>
                </div>
            </#if>

            <div class="cartones-field">
                <label for="password" class="cartones-field__label">${msg("password")}</label>
                <div class="cartones-field__password">
                    <input
                        tabindex="2"
                        id="password"
                        class="cartones-field__input"
                        name="password"
                        type="password"
                        autocomplete="current-password"
                        aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                    />
                    <button
                        type="button"
                        class="cartones-field__toggle"
                        aria-label="${msg('showPassword')!'Mostrar contraseña'}"
                        data-password-target="password"
                        tabindex="-1"
                    >
                        <span aria-hidden="true">👁</span>
                    </button>
                </div>
            </div>

            <div class="cartones-row">
                <#if realm.rememberMe && !usernameHidden??>
                    <label class="cartones-checkbox">
                        <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox" <#if login.rememberMe??>checked</#if>>
                        <span>${msg("rememberMe")}</span>
                    </label>
                </#if>
                <#if realm.resetPasswordAllowed>
                    <a tabindex="5" class="cartones-link" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a>
                </#if>
            </div>

            <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>

            <button tabindex="4" class="cartones-btn cartones-btn--primary" name="login" id="kc-login" type="submit">
                <span>${msg("doLogIn")}</span>
                <svg aria-hidden="true" viewBox="0 0 24 24" class="cartones-btn__arrow"><path d="M5 12h14M13 6l6 6-6 6" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>
            </button>
        </form>

        <#-- Toggle de mostrar/ocultar password (CSS sin JS no se puede,
             un pelín de JS inline para el click). -->
        <script>
            document.querySelectorAll('[data-password-target]').forEach(function (btn) {
                btn.addEventListener('click', function () {
                    var input = document.getElementById(btn.dataset.passwordTarget);
                    if (!input) return;
                    var hidden = input.type === 'password';
                    input.type = hidden ? 'text' : 'password';
                    btn.setAttribute('aria-pressed', hidden);
                });
            });
        </script>
    </#if>

    <#if section = "info">
        <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
            <p class="cartones-info__text">
                ${msg("noAccount")} <a tabindex="6" class="cartones-link" href="${url.registrationUrl}">${msg("doRegister")}</a>
            </p>
        </#if>
    </#if>

</@layout.registrationLayout>
