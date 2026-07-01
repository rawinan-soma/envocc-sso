<#import "template.ftl" as layout>
<#-- displayMessage: suppress global alert when there is already an inline field error (avoids duplicate error messages) -->
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('totp') displayInfo=otpLogin.userOtpCredentials?? && otpLogin.userOtpCredentials?size gt 1; section>
    <#if section = "header">
        ${msg("loginTotpTitle")}
    <#elseif section = "form">
        <div id="kc-otp-login">

            <#-- Story 2.5: Anti-phishing banner (pinned, non-dismissible) -->
            <div class="alert alert-info anti-phishing-banner" role="alert" aria-live="polite">
                <svg aria-hidden="true" focusable="false" width="16" height="16" viewBox="0 0 16 16" fill="none">
                    <circle cx="8" cy="8" r="7" stroke="currentColor" stroke-width="1.5"/>
                    <path d="M8 5v1m0 2v4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
                </svg>
                <span>${msg("antiphishingBanner")}</span>
            </div>

            <form id="kc-otp-login-form" action="${url.loginAction}" method="post">

                <#-- Credential selector: inside the form so selectedCredentialId is included in POST body -->
                <#if otpLogin.userOtpCredentials?? && otpLogin.userOtpCredentials?size gt 1>
                    <div id="kc-otp-credentials">
                        <#list otpLogin.userOtpCredentials as otpCredential>
                            <div class="${properties.kcSelectOTPListItemClass!}">
                                <input id="kc-otp-credential-${otpCredential?index}"
                                       class="${properties.kcSelectOTPListItemHeaderClass!}"
                                       type="radio"
                                       name="selectedCredentialId"
                                       value="${otpCredential.id}"
                                       <#if otpCredential.id == otpLogin.selectedCredentialId>checked</#if>>
                                <label for="kc-otp-credential-${otpCredential?index}">${otpCredential.userLabel!}</label>
                            </div>
                        </#list>
                    </div>
                </#if>
                <div class="${properties.kcFormGroupClass!}">
                    <div class="${properties.kcLabelWrapperClass!}">
                        <label for="totp" class="${properties.kcLabelClass!}">${msg("loginTotpOneTime")}</label>
                    </div>
                    <#-- Story 2.6 (AC2, UX-DR6/UX-DR8): six-cell verification-code presentation.
                         Kept as ONE real text field (Dev Notes "Code-Input Implementation Approach"
                         — recommended path): the .otp-cell-field class in login.css paints six
                         bordered cells behind the single field via a repeating background, so the
                         field looks like six cells but stays one logical, one-labeled, one-POST-field
                         form control. No aria-label is added here — the label above (for="totp") is
                         the field's single accessible name; adding aria-label would double-announce.

                         NOTE — corrected POST field name (deliberate, reviewed correction, not a
                         silent workaround): Keycloak 26.6.3's built-in auth-otp-form execution
                         (org.keycloak.authentication.authenticators.browser.OTPFormAuthenticator
                         .validateOTP()) reads the submitted code from request parameter "otp", not
                         "totp" — verified by decompiling the shipped 26.6.3 server JAR
                         (getDecodedFormParameters().getFirst("otp")). The error-message field key
                         it reports on an invalid code is still "totp" (challenge(context,
                         "invalidTotpMessage", "totp")), which is why messagesPerField.existsError
                         below still checks 'totp' — only the <input> name= attribute changes. -->
                    <div id="otp-cells" class="${properties.kcInputWrapperClass!} otp-cell-group">
                        <input id="totp"
                               name="otp"
                               autocomplete="one-time-code"
                               type="text"
                               class="${properties.kcInputClass!} otp-cell-field"
                               autofocus
                               inputmode="numeric"
                               pattern="[0-9]{6}"
                               maxlength="6"
                               aria-invalid="<#if messagesPerField.existsError('totp')>true<#else>false</#if>"
                               <#if messagesPerField.existsError('totp')>aria-describedby="input-error-otp-code"</#if>
                        />

                        <#if messagesPerField.existsError('totp')>
                            <span id="input-error-otp-code"
                                  class="${properties.kcInputErrorMessageClass!}"
                                  aria-live="polite">
                                ${kcSanitize(messagesPerField.getFirstError('totp'))?no_esc}
                            </span>
                        </#if>
                    </div>
                </div>

                <div class="${properties.kcFormGroupClass!}">
                    <div id="kc-form-options" class="${properties.kcFormOptionsClass!}">
                        <div class="${properties.kcFormOptionsWrapperClass!}">
                        </div>
                    </div>

                    <div id="kc-form-buttons" class="${properties.kcFormButtonsClass!}">
                        <input class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonBlockClass!} ${properties.kcButtonLargeClass!}"
                               name="login"
                               id="kc-login"
                               type="submit"
                               value="${msg("doSubmit")}"/>
                    </div>
                </div>
            </form>

            <#-- Story 2.6 (AC2): additive progressive-enhancement script only — auto-submit on the
                 6th digit and paste-fills-all-six. The form above already POSTs a single 6-digit
                 name="totp" value via standard HTML submission with this script absent (no-JS
                 fallback, NFR8-aligned: no framework, no change to the POST contract). -->
            <script src="${url.resourcesPath}/js/otp-input.js" defer></script>
        </div>
    </#if>
</@layout.registrationLayout>
