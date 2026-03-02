import SwiftUI

struct WelcomeOnboardingView: View {
    let onChangeLanguage: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScreenScaffold {
            HStack {
                Spacer()
                Button(action: onChangeLanguage) {
                    Image(systemName: "globe")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .padding(11)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .accessibilityLabel(L10n.t("profile.language"))
            }
            .padding(.top, 8)

            VStack(spacing: 18) {
                Spacer(minLength: 90)

                Text("Adat")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(localizedOmarQuote())
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)

                Spacer(minLength: 220)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            PrimaryButton(title: L10n.t("onboarding.welcome.cta"), action: onContinue)
        }
    }

    private func localizedOmarQuote() -> String {
        let languageCode = Locale.current.language.languageCode?.identifier.lowercased() ?? "en"
        switch languageCode {
        case "ru":
            return "Призовите себя к отчёту, прежде чем вас призовут к отчёту. Взвешивайте свои деяния, прежде чем их взвесят.\n- Омар ибн аль-Хаттаб, да будет доволен им Аллах."
        case "kk":
            return "Есепке тартылмай тұрып өздеріңді есепке тартыңдар.\nАмалдарың таразыланбай тұрып, өз амалдарыңды таразылаңдар\n- Омар ибн әл-Хаттаб р.а."
        default:
            return "Call yourselves to account before you are called to account. Weigh your deeds before your deeds are weighed.\n- Omar ibn al-Khattab, may Allah be pleased with him."
        }
    }
}
