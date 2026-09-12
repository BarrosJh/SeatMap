// SeatMap WebAuthn & Biometric Bridge
(function () {
  function base64urlToBuffer(base64url) {
    var padding = '='.repeat((4 - (base64url.length % 4)) % 4);
    var base64 = (base64url + padding).replace(/-/g, '+').replace(/_/g, '/');
    var rawData = window.atob(base64);
    var outputArray = new Uint8Array(rawData.length);
    for (var i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray.buffer;
  }

  function bufferToBase64url(buffer) {
    var byteView = new Uint8Array(buffer);
    var str = '';
    for (var i = 0; i < byteView.length; i++) {
      str += String.fromCharCode(byteView[i]);
    }
    var base64 = window.btoa(str);
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  }

  window.SeatMapWebAuthn = {
    isPwaStandalone: function () {
      var isStandalone = (window.matchMedia && (
                            window.matchMedia('(display-mode: standalone)').matches ||
                            window.matchMedia('(display-mode: fullscreen)').matches ||
                            window.matchMedia('(display-mode: minimal-ui)').matches
                          )) ||
                         navigator.standalone === true ||
                         (document.referrer && document.referrer.startsWith('android-app://'));
      return Boolean(isStandalone);
    },

    isAvailable: async function () {
      if (!window.PublicKeyCredential) return false;
      try {
        if (PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) {
          return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
        }
        return true;
      } catch (_) {
        return false;
      }
    },

    register: async function (optionsJsonStr) {
      var options = typeof optionsJsonStr === 'string' ? JSON.parse(optionsJsonStr) : optionsJsonStr;
      
      // Convert base64url to buffers
      options.challenge = base64urlToBuffer(options.challenge);
      options.user.id = base64urlToBuffer(options.user.id);
      if (options.excludeCredentials) {
        for (var i = 0; i < options.excludeCredentials.length; i++) {
          options.excludeCredentials[i].id = base64urlToBuffer(options.excludeCredentials[i].id);
        }
      }

      var credential = await navigator.credentials.create({ publicKey: options });
      if (!credential) throw new Error('Biometria cancelada ou não autorizada.');

      var response = {
        id: credential.id,
        rawId: bufferToBase64url(credential.rawId),
        type: credential.type,
        response: {
          clientDataJSON: bufferToBase64url(credential.response.clientDataJSON),
          attestationObject: bufferToBase64url(credential.response.attestationObject),
          transports: credential.response.getTransports ? credential.response.getTransports() : []
        },
        clientExtensionResults: credential.getClientExtensionResults()
      };

      return JSON.stringify(response);
    },

    authenticate: async function (optionsJsonStr) {
      var options = typeof optionsJsonStr === 'string' ? JSON.parse(optionsJsonStr) : optionsJsonStr;

      options.challenge = base64urlToBuffer(options.challenge);
      if (options.allowCredentials) {
        for (var i = 0; i < options.allowCredentials.length; i++) {
          options.allowCredentials[i].id = base64urlToBuffer(options.allowCredentials[i].id);
        }
      }

      var assertion = await navigator.credentials.get({ publicKey: options });
      if (!assertion) throw new Error('Leitura biométrica cancelada.');

      var response = {
        id: assertion.id,
        rawId: bufferToBase64url(assertion.rawId),
        type: assertion.type,
        response: {
          clientDataJSON: bufferToBase64url(assertion.response.clientDataJSON),
          authenticatorData: bufferToBase64url(assertion.response.authenticatorData),
          signature: bufferToBase64url(assertion.response.signature),
          userHandle: assertion.response.userHandle ? bufferToBase64url(assertion.response.userHandle) : null
        },
        clientExtensionResults: assertion.getClientExtensionResults()
      };

      return JSON.stringify(response);
    }
  };

  window.SeatMapCamera = {
    requestCameraPermission: async function () {
      if (navigator.mediaDevices && typeof navigator.mediaDevices.getUserMedia === 'function') {
        try {
          var stream = await navigator.mediaDevices.getUserMedia({
            video: {
              facingMode: { ideal: 'environment' }
            }
          });
          // Para as tracks imediatamente após o consentimento do usuário
          stream.getTracks().forEach(function (track) {
            track.stop();
          });
          return true;
        } catch (err) {
          console.warn('[SeatMapCamera] Permissão de câmera não concedida pelo usuário:', err);
          return false;
        }
      }
      return false;
    }
  };
})();


