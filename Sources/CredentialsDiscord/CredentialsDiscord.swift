import Kitura
import KituraNet
import LoggerAPI
import Credentials
import Foundation

// MARK CredentialsDiscord

/// Authentication using Discord web login with OAuth.
/// See [Discord manual](https://discordapp.com/developers/docs/topics/oauth2
/// for more information.
public class CredentialsDiscord: CredentialsPluginProtocol {

    private var clientId: String

    private var clientSecret: String

    private let scopes: [String]

    /// The URL that Discord redirects back to.
    public var callbackUrl: String

    /// The User-Agent to be passed along on Discord API calls.
    private let userAgent: String = "DiscordBot (http://github.com/123FLO321/Kitura-CredentialsDiscord, 1.0.0)"

    /// The name of the plugin.
    public let name = "Discord"

    /// An indication as to whether the plugin is redirecting or not.
    public let redirecting = true

    /// User profile cache.
    public var usersCache: NSCache<NSString, BaseCacheElement>?

    /// A delegate for `UserProfile` manipulation.
    public let userProfileDelegate: UserProfileDelegate?

    /// Initialize a `CredentialsDiscord` instance.
    ///
    /// - Parameter clientId: The Client ID of the app in the Discord Developer applications.
    /// - Parameter clientSecret: The Client Secret of the app in the Discord Developer applications.
    /// - Parameter callbackUrl: The URL that Discord redirects back to.
    public init (clientId: String, clientSecret: String, callbackUrl: String, options: [String: Any] = [:]) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackUrl = callbackUrl
        self.scopes = options[CredentialsDiscordOptions.scopes] as? [String] ?? []
        self.userProfileDelegate = options[CredentialsDiscordOptions.userProfileDelegate] as? UserProfileDelegate
    }

    /// Authenticate incoming request using Discord web login with OAuth.
    ///
    /// - Parameter request: The `RouterRequest` object used to get information
    ///                     about the request.
    /// - Parameter response: The `RouterResponse` object used to respond to the
    ///                       request.
    /// - Parameter options: The dictionary of plugin specific options.
    /// - Parameter onSuccess: The closure to invoke in the case of successful authentication.
    /// - Parameter onFailure: The closure to invoke in the case of an authentication failure.
    /// - Parameter onPass: The closure to invoke when the plugin doesn't recognize the
    ///                     authentication data in the request.
    /// - Parameter inProgress: The closure to invoke to cause a redirect to the login page in the
    ///                     case of redirecting authentication.
    public func authenticate (request: RouterRequest, response: RouterResponse,
                              options: [String:Any], onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              inProgress: @escaping () -> Void) {
        if let code = request.queryParameters["code"] {
            // query contains code: exchange code for access token
            var requestOptions: [ClientRequest.Options] = []
            requestOptions.append(.schema("https://"))
            requestOptions.append(.hostname("discordapp.com"))
            requestOptions.append(.method("POST"))
            requestOptions.append(.path("api/oauth2/token"))
            var headers = [String:String]()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            headers["Accept"] = "application/json"
            requestOptions.append(.headers(headers))
            
            let scopeParameters = getScopeParameters()
            let body = "client_id=\(clientId)&redirect_uri=\(callbackUrl)&client_secret=\(clientSecret)&code=\(code)&grant_type=authorization_code\(scopeParameters)"
            
            let requestForToken = HTTP.request(requestOptions) { fbResponse in
                if let fbResponse = fbResponse, fbResponse.statusCode == .OK {
                    // get user profile with access token
                    do {
                        var body = Data()
                        try fbResponse.readAllData(into: &body)
                        if let jsonBody = try JSONSerialization.jsonObject(with: body, options: []) as? [String : Any],
                        let token = jsonBody["access_token"] as? String {
                            requestOptions = []
                            requestOptions.append(.schema("https://"))
                            requestOptions.append(.hostname("discordapp.com"))
                            requestOptions.append(.method("GET"))
                            requestOptions.append(.path("api/v6/users/@me"))
                            headers = [String:String]()
                            headers["Accept"] = "application/json"
                            headers["User-Agent"] = self.userAgent
                            headers["Authorization"] = "Bearer \(token)"
                            requestOptions.append(.headers(headers))

                            let requestForProfile = HTTP.request(requestOptions) { profileResponse in
                                if let profileResponse = profileResponse, profileResponse.statusCode == .OK {
                                    do {
                                        body = Data()
                                        try profileResponse.readAllData(into: &body)
                                        if let userDictionary = try JSONSerialization.jsonObject(with: body, options: []) as? [String : Any],
                                        let userProfile = self.createUserProfile(from: userDictionary) {
                                            if let delegate = self.userProfileDelegate {
                                                delegate.update(userProfile: userProfile, from: userDictionary)
                                            }

                                            onSuccess(userProfile)
                                            return
                                        }
                                    }
                                    catch {
                                        Log.error("Failed to read \(self.name) response")
                                    }
                                }
                                else {
                                    onFailure(nil, nil)
                                }
                            }
                            requestForProfile.end()
                        }
                    }
                    catch {
                        Log.error("Failed to read \(self.name) response")
                    }
                }
                else {
                    onFailure(nil, nil)
                }
            }
            requestForToken.write(from: body)
            requestForToken.end()
        }
        else {
            let scopeParameters = getScopeParameters()
            do {
                try response.redirect("https://discordapp.com/api/oauth2/authorize?client_id=\(clientId)&redirect_uri=\(callbackUrl)&response_type=code\(scopeParameters)")
                inProgress()
            }
            catch {
                Log.error("Failed to redirect to \(name) login page")
            }
        }
    }
    
    private func getScopeParameters() -> String {
        var scopeParameters = "&scope="
        for scope in scopes {
            // space delimited list: https://discordapp.com/developers/docs/topics/oauth2#authorization-code-grant
            // trailing space character is probably OK
            scopeParameters.append(scope + " ")
        }
        return scopeParameters
    }

    // Discord user profile response format looks like this: https://discordapp.com/developers/docs/resources/user#user-object
    private func createUserProfile(from userDictionary: [String: Any]) -> UserProfile? {
        guard let id = userDictionary["id"] as? String else {
            return nil
        }

        let name = userDictionary["username"] as? String ?? ""

        var userProfileEmails: [UserProfile.UserProfileEmail]?

        if let email = userDictionary["email"] as? String {
            userProfileEmails = [UserProfile.UserProfileEmail(value: email, type: "public")]
        }

        var userProfilePhotos: [UserProfile.UserProfilePhoto]?

        if let avatar = userDictionary["avatar"] as? String {
            userProfilePhotos = [UserProfile.UserProfilePhoto("https://cdn.discordapp.com/avatars/\(id)/\(avatar).png")]
        }

        return UserProfile(id: id, displayName: name, provider: self.name, emails: userProfileEmails, photos: userProfilePhotos)
    }
}
