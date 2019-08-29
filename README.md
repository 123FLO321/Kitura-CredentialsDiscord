# Kitura-CredentialsDiscord

A plugin for the Kitura-Credentials framework that authenticates using the Discord OAuth web login.<br>
Based on Kitura-CredentialsGitHub.

![Mac OS X](https://img.shields.io/badge/os-Mac%20OS%20X-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)

## Summary
Plugins for [Kitura-Credentials](https://github.com/IBM-Swift/Kitura-Credentials) framework that authenticate using [Discord web login with OAuth2 ](http://discordapp.com/developers/docs/topics/oauth2).

## Swift Version

The latest version of Kitura-CredentialsDiscord requires Swift 4.0 or newer. You can download this version of the Swift binaries by following this [link](https://swift.org/download/)). Compatibility with other Swift versions is not guaranteed.

## Before You Start

Head on over to the [Discord Developer Portal](https://discordapp.com/developers/applications/) and register an application you'll be using Kitura for. <br>
Click on the `OAuth2` section and enter a redirect url (For instance: `http://localhost:8080/login/discord/callback`). The redirect url needs to match the one specidied in the code exactly! <br>
Client ID and Client Secret can be viewed in `General Information` section.

## Example of Discord Web Login

_Note: for more detailed instructions, please refer to [Kitura-Credentials-Sample](https://github.com/IBM-Swift/Kitura-Credentials-Sample)._

First, set up the session:

```swift
import KituraSession

router.all(middleware: Session(secret: "Some random string"))
```

Create an instance of `CredentialsDiscord` plugin and register it with `Credentials` framework:

```swift
import Credentials
import CredentialsDiscord

let credentials = Credentials()
let discordCredentials = CredentialsDiscord(
    clientId: "YOUR_CLIENT_ID",
    clientSecret: "YOUR_CLIENT_SECRET",
    callbackUrl: "YOUR_CALLBACK_URL"
)
credentials.register(discordCredentials)
```

**Where:**
   - *YOUR_CLIENT_ID* is the Client ID of the App you created.
   - *YOUR_CLIENT_SECRET* is the Client Secret of the App you created.
   - *YOUR_CALLBACK_URL* is the Callback URL Discord calles once OAuth is completed. This Callback URL needs to match the one you specified in the Developer Portal.

Specify where to redirect non-authenticated requests:
```swift
credentials.options["failureRedirect"] = "/login/discord"
```

Connect `credentials` middleware to requests to `/private`:

```swift
router.all("/private", middleware: credentials)
router.get("/private/data", handler:
    { request, response, next in
        ...  
        next()
})
```
And call `authenticate` to login with Discord and to handle the redirect (callback) from the Discord login web page after a successful login:

```swift
router.get("/login/discord",
           handler: credentials.authenticate(discordCredentials.name))

router.get("/login/discord/callback",
           handler: credentials.authenticate(discordCredentials.name))
```

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
