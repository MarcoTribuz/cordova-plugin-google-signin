// Drop-in replacement for cordova-plugin-googleplus.
// Exposes the same window.plugins.googleplus interface so the
// meteor/google-oauth package works without any changes.

function GoogleSignIn() {}

GoogleSignIn.prototype.login = function (options, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, 'GoogleSignIn', 'login', [options]);
};

GoogleSignIn.prototype.trySilentLogin = function (options, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, 'GoogleSignIn', 'trySilentLogin', [options]);
};

GoogleSignIn.prototype.logout = function (successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, 'GoogleSignIn', 'logout', []);
};

GoogleSignIn.prototype.disconnect = function (successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, 'GoogleSignIn', 'disconnect', []);
};

GoogleSignIn.install = function () {
  if (!window.plugins) window.plugins = {};
  window.plugins.googleplus = new GoogleSignIn();
  return window.plugins.googleplus;
};

cordova.addConstructor(GoogleSignIn.install);
