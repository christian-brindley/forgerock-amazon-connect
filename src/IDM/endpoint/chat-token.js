(function () {

    // Configuration

    var config = {
        endpointName: "chatToken",
        userObject: "alpha_user",
        signingKey: "YOUR_SECRET_KEY",
        widgetId: "YOUR_WIDGET_ID",
        validitySeconds: 500,
        userAttributes: {
            userName: "userName",
            emailAddress: "mail",
            fullName: "cn",
            firstName: "givenName",
            lastName: "sn",
            mobile: "telephoneNumber",
            customerId: "frIndexedString1"
        }
    };

    // Imports

    var fr = JavaImporter(
        com.sun.identity.authentication.callbacks.ScriptTextOutputCallback,
        java.time.Clock,
        java.time.temporal.ChronoUnit,
        javax.crypto.spec.SecretKeySpec,
        org.forgerock.json.jose.builders.JwtBuilderFactory,
        org.forgerock.json.jose.jws.JwsAlgorithm,
        org.forgerock.json.jose.jws.handlers.SecretHmacSigningHandler,
        org.forgerock.json.jose.jwt.JwtClaimsSet,
        org.forgerock.secrets.SecretBuilder,
        org.forgerock.secrets.keys.SigningKey,
        org.forgerock.util.encode.Base64,
        org.forgerock.json.jose.jws.SignedJwt,
        org.forgerock.json.jose.jws.EncryptedThenSignedJwt,
        org.forgerock.json.jose.jwe.SignedThenEncryptedJwt,
        org.forgerock.secrets.keys.VerificationKey,
        javax.crypto.spec.SecretKeySpec,
        org.forgerock.json.jose.jwe.JweAlgorithm,
        org.forgerock.json.jose.jwe.EncryptionMethod,
        java.lang.String
    );

    function tag(message) {
        return "***".concat(config.endpointName).concat(" ").concat(message);
    }

    function getSigningKey(secret) {

        var secretBytes = new fr.String(config.signingKey).getBytes();
        var secretBuilder = new fr.SecretBuilder;
        secretBuilder.secretKey(new javax.crypto.spec.SecretKeySpec(secretBytes, "Hmac"));
        secretBuilder.stableId(config.issuer).expiresIn(5, fr.ChronoUnit.MINUTES, fr.Clock.systemUTC());
        return new fr.SigningKey(secretBuilder);

    }

    function buildJwt(claims) {

        logger.debug(tag("Building JWT"));

        var signingKey = getSigningKey(config.signingKey);
        var signingHandler = new fr.SecretHmacSigningHandler(signingKey);

        var iat = new Date();
        var iatTime = iat.getTime();

        var attributes = { attributes: claims };

        var jwtClaims = new fr.JwtClaimsSet;
        jwtClaims.setIssuedAtTime(new Date());
        jwtClaims.setExpirationTime(new Date(iatTime + (config.validitySeconds * 1000)));
        jwtClaims.setSubject(config.widgetId);
        jwtClaims.setClaims(attributes);

        var jwt = new fr.JwtBuilderFactory()
            .jws(signingHandler)
            .headers()
            .alg(fr.JwsAlgorithm.HS256)
            .done()
            .claims(jwtClaims)
            .build();

        return jwt;
    }





    function logResponse(response) {
        logger.debug(tag("HTTP Response: " + response.getStatus() + ", Body: " + response.getEntity().getString()));
    }

    function getUserDetails(uid, fields) {
        var frAttributes = [];

        // First get array of FR fields to fetch - wihout using Object.values()
        Object.keys(fields).forEach(key => {
            frAttributes.push(fields[key]);
        });

        var user = openidm.read("managed/" + config.userObject + "/" + uid,
            null,
            frAttributes);

        var jwtClaims = {};

        // Now build the claims for the JWT - without using Object.entries()
        Object.keys(fields).forEach(key => {
            jwtClaims[key] = user[fields[key]];
        });

        logger.debug(tag("Got attributes " + jwtClaims));

        return jwtClaims;

    }

    logger.debug(tag("endpoint executing"));

    var callingUser = context.security.authenticationId;
    var userDetails = getUserDetails(callingUser, config.userAttributes);

    if (!userDetails) {
        throw { code: 500, message: "Error getting user details" };
    }

    var chatToken = buildJwt(userDetails);

    return {
        result: 0,
        chatToken: chatToken
    };
})();


