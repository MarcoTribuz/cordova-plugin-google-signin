package com.junction.plugins;

import android.content.Intent;
import android.util.Log;

import com.google.android.gms.auth.api.signin.GoogleSignIn;
import com.google.android.gms.auth.api.signin.GoogleSignInAccount;
import com.google.android.gms.auth.api.signin.GoogleSignInClient;
import com.google.android.gms.auth.api.signin.GoogleSignInOptions;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.common.api.Scope;
import com.google.android.gms.tasks.Task;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class GoogleSignInPlugin extends CordovaPlugin {

    private static final String TAG = "GoogleSignInPlugin";
    private static final int RC_SIGN_IN = 9001;

    private CallbackContext savedCallbackContext;
    private GoogleSignInClient googleSignInClient;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext)
            throws JSONException {

        savedCallbackContext = callbackContext;

        switch (action) {
            case "login":
                buildClient(args.optJSONObject(0));
                cordova.setActivityResultCallback(this);
                cordova.getActivity().startActivityForResult(
                        googleSignInClient.getSignInIntent(), RC_SIGN_IN);
                return true;

            case "trySilentLogin":
                buildClient(args.optJSONObject(0));
                trySilentLogin();
                return true;

            case "logout":
                signOut();
                return true;

            case "disconnect":
                disconnect();
                return true;

            default:
                return false;
        }
    }

    private void buildClient(JSONObject options) throws JSONException {
        if (options == null) options = new JSONObject();

        String webClientId = options.optString("webClientId", null);
        boolean offline    = options.optBoolean("offline", false);
        String scopes      = options.optString("scopes", null);

        GoogleSignInOptions.Builder gso =
                new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                        .requestEmail()
                        .requestProfile();

        if (webClientId != null && !webClientId.isEmpty()) {
            gso.requestIdToken(webClientId);
            // offline=true → request serverAuthCode so the Meteor server can exchange tokens
            if (offline) {
                gso.requestServerAuthCode(webClientId);
            }
        }

        if (scopes != null && !scopes.isEmpty()) {
            for (String scope : scopes.split(" ")) {
                gso.requestScopes(new Scope(scope));
            }
        }

        googleSignInClient = GoogleSignIn.getClient(cordova.getActivity(), gso.build());
    }

    private void trySilentLogin() {
        Task<GoogleSignInAccount> task = googleSignInClient.silentSignIn();
        if (task.isSuccessful()) {
            handleAccount(task.getResult());
        } else {
            task.addOnCompleteListener(cordova.getActivity(), t -> {
                try {
                    handleAccount(t.getResult(ApiException.class));
                } catch (ApiException e) {
                    savedCallbackContext.error(e.getStatusCode());
                }
            });
        }
    }

    private void signOut() {
        if (googleSignInClient == null) {
            // Build a minimal client just to sign out
            GoogleSignInOptions gso =
                    new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN).build();
            googleSignInClient = GoogleSignIn.getClient(cordova.getActivity(), gso);
        }
        googleSignInClient.signOut().addOnCompleteListener(cordova.getActivity(), task -> {
            if (task.isSuccessful()) {
                savedCallbackContext.success("logged out");
            } else {
                savedCallbackContext.error("signOut failed");
            }
        });
    }

    private void disconnect() {
        if (googleSignInClient == null) {
            GoogleSignInOptions gso =
                    new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN).build();
            googleSignInClient = GoogleSignIn.getClient(cordova.getActivity(), gso);
        }
        googleSignInClient.revokeAccess().addOnCompleteListener(cordova.getActivity(), task -> {
            if (task.isSuccessful()) {
                savedCallbackContext.success("disconnected");
            } else {
                savedCallbackContext.error("disconnect failed");
            }
        });
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != RC_SIGN_IN) return;

        Task<GoogleSignInAccount> task = GoogleSignIn.getSignedInAccountFromIntent(data);
        try {
            handleAccount(task.getResult(ApiException.class));
        } catch (ApiException e) {
            Log.w(TAG, "signInResult:failed code=" + e.getStatusCode());
            savedCallbackContext.error(e.getStatusCode());
        }
    }

    private void handleAccount(GoogleSignInAccount account) {
        try {
            JSONObject result = new JSONObject();
            result.put("email",          account.getEmail()          != null ? account.getEmail()          : "");
            result.put("idToken",        account.getIdToken()        != null ? account.getIdToken()        : "");
            result.put("serverAuthCode", account.getServerAuthCode() != null ? account.getServerAuthCode() : "");
            result.put("accessToken",    ""); // server exchanges serverAuthCode for tokens
            result.put("userId",         account.getId()             != null ? account.getId()             : "");
            result.put("displayName",    account.getDisplayName()    != null ? account.getDisplayName()    : JSONObject.NULL);
            result.put("givenName",      account.getGivenName()      != null ? account.getGivenName()      : JSONObject.NULL);
            result.put("familyName",     account.getFamilyName()     != null ? account.getFamilyName()     : JSONObject.NULL);
            result.put("imageUrl",       account.getPhotoUrl()       != null ? account.getPhotoUrl().toString() : JSONObject.NULL);
            savedCallbackContext.success(result);
        } catch (JSONException e) {
            savedCallbackContext.error("Failed to build result: " + e.getMessage());
        }
    }
}
