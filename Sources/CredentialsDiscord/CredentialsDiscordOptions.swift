// MARK CredentialsDiscordOptions
/// A list of options for authentication with Discord.
public struct CredentialsDiscordOptions {
    /// [Discord access token scopes](https://discordapp.com/developers/docs/topics/oauth2#shared-resources-oauth2-scopes)
    public static let scopes = "scopes"

    /// An implementation of `Credentials.UserProfileDelegate` to update user profile.
    public static let userProfileDelegate = "userProfileDelegate"
}
