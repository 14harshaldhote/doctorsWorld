/// Version information for the game core, shown on the title screen so a
/// build can always be matched to the rules it runs.
public enum GameCoreInfo {
    /// Semantic version of the rules. Bump the minor version whenever a
    /// change could alter the outcome of a replayed shift.
    public static let version = "0.3.0"
}
