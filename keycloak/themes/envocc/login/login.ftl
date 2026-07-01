<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>
    <#if section = "header">
        ${msg("loginTitle")}
    <#elseif section = "form">
        <div id="kc-form">
            <div id="kc-form-wrapper">

                <#-- Story 2.5: Anti-phishing banner (pinned, non-dismissible) -->
                <div class="alert alert-info anti-phishing-banner" role="alert" aria-live="polite">
                    <svg aria-hidden="true" focusable="false" width="16" height="16" viewBox="0 0 16 16" fill="none">
                        <circle cx="8" cy="8" r="7" stroke="currentColor" stroke-width="1.5"/>
                        <path d="M8 5v1m0 2v4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
                    </svg>
                    <span>${msg("antiphishingBanner")}</span>
                </div>

                <form id="kc-form-login" action="${url.loginAction}" method="post">
                    <div class="${properties.kcFormGroupClass!}">
                        <label for="username" class="${properties.kcLabelClass!}">${msg("usernameOrEmail")}</label>

                        <#if usernameHidden??>
                            <input tabindex="${properties.kcLoginTabIndex!}"
                                   id="username"
                                   class="${properties.kcInputClass!}"
                                   name="username"
                                   value="${(login.username!'')}"
                                   type="hidden">
                        <#else>
                            <input tabindex="${properties.kcLoginTabIndex!}"
                                   id="username"
                                   class="${properties.kcInputClass!}"
                                   name="username"
                                   value="${(login.username!'')}"
                                   type="text"
                                   autofocus
                                   autocomplete="username"
                                   aria-invalid="<#if messagesPerField.existsError('username','password')>true<#else>false</#if>"
                                   <#if messagesPerField.existsError('username','password')>aria-describedby="input-error"</#if>
                            />

                            <#if messagesPerField.existsError('username','password')>
                                <span id="input-error"
                                      class="${properties.kcInputErrorMessageClass!}"
                                      aria-live="polite">
                                    ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                                </span>
                            </#if>
                        </#if>
                    </div>

                    <div class="${properties.kcFormGroupClass!}" <#if auth.selectedCredential?has_content && auth.selectedCredential != "password">hidden</#if>>
                        <label for="password" class="${properties.kcLabelClass!}">${msg("password")}</label>
                        <div class="${properties.kcInputGroup!}">
                            <input tabindex="${properties.kcLoginTabIndex!}"
                                   id="password"
                                   class="${properties.kcInputClass!}"
                                   name="password"
                                   type="password"
                                   autocomplete="current-password"
                                   aria-invalid="<#if messagesPerField.existsError('username','password')>true<#else>false</#if>"
                                   <#if messagesPerField.existsError('username','password')>aria-describedby="input-error"</#if>
                            />
                        </div>
                    </div>

                    <div class="${properties.kcFormGroupClass!} ${properties.kcFormSettingClass!}">
                        <div id="kc-form-options">
                            <#if realm.rememberMe && !usernameHidden??>
                                <div class="checkbox">
                                    <label>
                                        <#if login.rememberMe??>
                                            <input tabindex="${properties.kcLoginTabIndex!}"
                                                   id="rememberMe"
                                                   name="rememberMe"
                                                   type="checkbox"
                                                   checked> ${msg("rememberMe")}
                                        <#else>
                                            <input tabindex="${properties.kcLoginTabIndex!}"
                                                   id="rememberMe"
                                                   name="rememberMe"
                                                   type="checkbox"> ${msg("rememberMe")}
                                        </#if>
                                    </label>
                                </div>
                            </#if>
                        </div>
                        <div class="${properties.kcFormOptionsWrapperClass!}">
                            <#if realm.resetPasswordAllowed>
                                <span><a tabindex="${properties.kcLoginTabIndex!}"
                                         href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a></span>
                            </#if>
                        </div>
                    </div>

                    <div id="kc-form-buttons" class="${properties.kcFormGroupClass!}">
                        <input type="hidden"
                               id="id-hidden-input"
                               name="credentialId"
                               <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                        <input tabindex="${properties.kcLoginTabIndex!}"
                               class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonBlockClass!} ${properties.kcButtonLargeClass!}"
                               name="login"
                               id="kc-login"
                               type="submit"
                               value="${msg("doLogIn")}"/>
                    </div>
                </form>
            </div>
        </div>
    <#elseif section = "info">
        <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
            <div id="kc-registration-container">
                <div id="kc-registration">
                    <span>${msg("noAccount")} <a tabindex="${properties.kcLoginTabIndex!}"
                                                  href="${url.registrationUrl}">${msg("doRegister")}</a></span>
                </div>
            </div>
        </#if>
    <#elseif section = "socialProviders">
        <#if realm.password && social.providers??>
            <div id="kc-social-providers" class="${properties.kcFormSocialAccountSectionClass!}">
                <hr/>
                <h2>${msg("identity-provider-login-label")}</h2>
                <ul class="${properties.kcFormSocialAccountListClass!} <#if social.providers?size gt 3>${properties.kcFormSocialAccountListGridClass!}</#if>">
                    <#list social.providers as p>
                        <li>
                            <a id="social-${p.alias}"
                               class="${properties.kcFormSocialAccountListButtonClass!} <#if social.providers?size gt 3>${properties.kcFormSocialAccountGridItem!}</#if>"
                               type="button"
                               href="${p.loginUrl}">
                                <#-- Story 2.9: prefer the theme's translatable message key for the
                                     thaid provider (FR12 externalized-strings requirement) over the
                                     realm-config displayName, which is not localizable. Falls back to
                                     displayName for any other provider (none exist today, but this
                                     keeps the loop generically correct). -->
                                <#if p.iconClasses?has_content>
                                    <i class="${properties.kcCommonLogoIdP!} ${p.iconClasses!}" aria-hidden="true"></i>
                                    <span class="${properties.kcFormSocialAccountNameClass!} kc-social-icon-text"><#if p.alias == "thaid">${msg("loginWithThaiD")}<#else>${p.displayName!}</#if></span>
                                <#else>
                                    <span class="${properties.kcFormSocialAccountNameClass!}"><#if p.alias == "thaid">${msg("loginWithThaiD")}<#else>${p.displayName!}</#if></span>
                                </#if>
                            </a>
                        </li>
                    </#list>
                </ul>
            </div>
        </#if>
    </#if>
</@layout.registrationLayout>
