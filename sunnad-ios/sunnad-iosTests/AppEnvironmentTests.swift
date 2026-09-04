import Foundation
import Testing
@testable import sunnad_ios

struct AppEnvironmentTests {
    @Test
    func resolvesAPNsEnvironmentFromSignedProvisioningProfile() {
        let developmentProfile = Data("""
        <plist><dict>
        <key>aps-environment</key>
        <string>development</string>
        </dict></plist>
        """.utf8)
        let productionProfile = Data("""
        <plist><dict>
        <key>aps-environment</key><string>production</string>
        </dict></plist>
        """.utf8)

        #expect(
            APNsEnvironmentResolver.environment(inProvisioningProfile: developmentProfile) == "development"
        )
        #expect(
            APNsEnvironmentResolver.environment(inProvisioningProfile: productionProfile) == "production"
        )
    }

    @Test
    func rejectsMissingOrUnknownAPNsEnvironment() {
        #expect(
            APNsEnvironmentResolver.environment(inProvisioningProfile: Data("<plist/>".utf8)) == nil
        )
        #expect(
            APNsEnvironmentResolver.environment(
                inProvisioningProfile: Data("<key>aps-environment</key><string>preview</string>".utf8)
            ) == nil
        )
    }
}
