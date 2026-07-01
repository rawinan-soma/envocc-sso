/**
 * otp-input.js — Story 2.6: six-cell TOTP verification-code progressive enhancement
 *
 * The underlying form field stays a single <input id="totp" name="otp"> (see
 * login-otp.ftl and Dev Notes "Code-Input Implementation Approach" — Keycloak's
 * server-side OTPFormAuthenticator reads getDecodedFormParameters().getFirst("otp"),
 * not "totp" (verified by decompiling the shipped 26.6.3 server JAR — id=
 * stays "totp" to match the existing <label for="totp">, only name= is "otp"),
 * so this script must never rename, remove, or duplicate that field).
 *
 * Because the code is a SINGLE real <input> (visually presented as six cells via
 * CSS, see .otp-cell-field in login.css), most of AC2's "six-cell" interaction
 * requirements are satisfied for free by the browser's native text-input
 * behavior:
 *   - "auto-advance focus to the next cell" on digit entry — there is only one
 *     field, so the caret already advances natively; no per-cell focus
 *     management is needed.
 *   - "Backspace on an empty cell steps focus back" — same reasoning; Backspace
 *     already edits the single field natively.
 *   - "pasting a full 6-digit code fills all six cells in one action" — pasting
 *     into the single input already fills the whole value in one action.
 *
 * What THIS script adds on top of native behavior (purely additive — the field
 * still works with JavaScript disabled, satisfying AC2's no-JS fallback):
 *   - strips non-digit characters and enforces the 6-digit max client-side
 *     (defense-in-depth; the server and maxlength="6"/pattern="[0-9]{6}"
 *     already constrain this without JS)
 *   - auto-submits the form once the 6th digit is entered or pasted
 */
(function () {
  'use strict';

  function initOtpInput() {
    var input = document.getElementById('totp');
    if (!input) {
      return;
    }

    function submitForm() {
      var form = input.form;
      if (!form) {
        return;
      }
      if (typeof form.requestSubmit === 'function') {
        form.requestSubmit();
      } else {
        form.submit();
      }
    }

    input.addEventListener('input', function () {
      var digitsOnly = input.value.replace(/\D/g, '').slice(0, 6);
      if (digitsOnly !== input.value) {
        input.value = digitsOnly;
      }
      if (input.value.length === 6) {
        submitForm();
      }
    });

    input.addEventListener('paste', function (event) {
      var clipboard = event.clipboardData || window.clipboardData;
      if (!clipboard) {
        return;
      }
      var pasted = clipboard.getData('text') || '';
      var digitsOnly = pasted.replace(/\D/g, '').slice(0, 6);
      if (digitsOnly.length === 6) {
        event.preventDefault();
        input.value = digitsOnly;
        submitForm();
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initOtpInput);
  } else {
    initOtpInput();
  }
})();
