<#import "template.ftl" as layout>
<@layout.registrationLayout displayInfo=otpLogin.userOtpCredentials?? && otpLogin.userOtpCredentials?size gt 1; section>
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
                            <label for="kc-otp-credential-${otpCredential?index}">${otpCredential.userLabel}</label>
                        </div>
                    </#list>
                </div>
            </#if>

            <form id="kc-otp-login-form" action="${url.loginAction}" method="post">
                <div class="${properties.kcFormGroupClass!}">
                    <div class="${properties.kcLabelWrapperClass!}">
                        <label for="totp" class="${properties.kcLabelClass!}">${msg("loginTotpOneTime")}</label>
                    </div>
                    <div class="${properties.kcInputWrapperClass!}">
                        <input id="totp"
                               name="totp"
                               autocomplete="one-time-code"
                               type="text"
                               class="${properties.kcInputClass!}"
                               autofocus
                               inputmode="numeric"
                               aria-invalid="<#if messagesPerField.existsError('totp')>true</#if>"
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
        </div>
    </#if>
</@layout.registrationLayout>
