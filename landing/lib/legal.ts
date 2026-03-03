import type { Locale } from "@/lib/i18n";

/* ------------------------------------------------------------------ */
/*  Terms of Service                                                   */
/* ------------------------------------------------------------------ */
const termsEN = `
<p><em>Last updated: February 22, 2026</em></p>

<h2>1. Acceptance of Terms</h2>
<p>By accessing or using the Adat mobile application and related services (collectively, the "Service"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree, do not use the Service.</p>

<h2>2. Description of Service</h2>
<p>Adat is an offline-first Islamic habit tracking application that helps users build consistent daily habits, track streaks, view daily quotes, and participate in group accountability features. The Service is provided by the Adat team ("we", "us", "our").</p>

<h2>3. Eligibility</h2>
<p>You must be at least 13 years old to use the Service. If you are under 18, you must have parental or guardian consent. By using the Service, you represent that you meet these requirements.</p>

<h2>4. User Accounts</h2>
<p>An account is optional for core functionality. If you create an account to use group features:</p>
<ul>
<li>You are responsible for maintaining the security of your account credentials.</li>
<li>You must provide accurate information during registration.</li>
<li>You must not share your account with others.</li>
<li>You must notify us immediately of any unauthorized use.</li>
</ul>

<h2>5. Acceptable Use</h2>
<p>You agree not to:</p>
<ul>
<li>Use the Service for any unlawful purpose.</li>
<li>Attempt to access other users' data without authorization.</li>
<li>Interfere with or disrupt the Service or its infrastructure.</li>
<li>Submit false or misleading information.</li>
<li>Use automated means to interact with the Service unless authorized.</li>
<li>Harass, abuse, or harm other users.</li>
</ul>

<h2>6. Content and Intellectual Property</h2>
<p>All content included in the Service — including text, graphics, logos, icons, quotes, and software — is the property of the Adat team or its licensors and is protected by applicable intellectual property laws. You may not copy, modify, distribute, or create derivative works without prior written consent.</p>

<h2>7. Privacy</h2>
<p>Your use of the Service is also governed by our Privacy Policy. By using the Service, you consent to the collection and use of information as described therein.</p>

<h2>8. Disclaimer of Warranties</h2>
<p>The Service is provided "as is" and "as available" without warranties of any kind, either express or implied. We do not warrant that the Service will be uninterrupted, error-free, or free of viruses or other harmful components.</p>

<h2>9. Limitation of Liability</h2>
<p>To the maximum extent permitted by applicable law, the Adat team shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses resulting from your use of the Service.</p>

<h2>10. Termination</h2>
<p>We may suspend or terminate your access to the Service at any time, with or without cause, and with or without notice. Upon termination, your right to use the Service ceases immediately. You may delete your account at any time through the app settings.</p>

<h2>11. Changes to Terms</h2>
<p>We reserve the right to modify these Terms at any time. Changes will be posted within the app or on our website. Continued use of the Service after changes constitutes acceptance of the revised Terms.</p>

<h2>12. Governing Law</h2>
<p>These Terms shall be governed by and construed in accordance with the laws of the Republic of Kazakhstan, without regard to its conflict of law provisions.</p>

<h2>13. Contact</h2>
<p>If you have questions about these Terms, please contact us at <a href="mailto:alimkhan.ergebayev@gmail.com">alimkhan.ergebayev@gmail.com</a>.</p>
`;

const termsRU = `
<p><em>Последнее обновление: 22 февраля 2026 г.</em></p>

<h2>1. Принятие условий</h2>
<p>Получая доступ к мобильному приложению Adat и связанным сервисам (совместно именуемым «Сервис»), вы соглашаетесь соблюдать настоящие Условия использования («Условия»). Если вы не согласны, не используйте Сервис.</p>

<h2>2. Описание сервиса</h2>
<p>Adat — это офлайн-первое исламское приложение для отслеживания привычек, которое помогает пользователям формировать ежедневные привычки, отслеживать серии, просматривать ежедневные цитаты и участвовать в групповой ответственности. Сервис предоставляется командой Adat («мы», «нас», «наш»).</p>

<h2>3. Допуск</h2>
<p>Для использования Сервиса вам должно быть не менее 13 лет. Если вам менее 18 лет, вы должны иметь согласие родителей или опекунов. Используя Сервис, вы подтверждаете, что соответствуете этим требованиям.</p>

<h2>4. Учётные записи</h2>
<p>Учётная запись не обязательна для основного функционала. Если вы создаёте аккаунт для групповых функций:</p>
<ul>
<li>Вы несёте ответственность за безопасность учётных данных.</li>
<li>Вы обязаны предоставлять точную информацию при регистрации.</li>
<li>Вы не должны передавать свой аккаунт третьим лицам.</li>
<li>Вы обязаны уведомить нас о несанкционированном использовании.</li>
</ul>

<h2>5. Допустимое использование</h2>
<p>Вы соглашаетесь не:</p>
<ul>
<li>Использовать Сервис в незаконных целях.</li>
<li>Пытаться получить доступ к данным других пользователей без разрешения.</li>
<li>Вмешиваться в работу Сервиса или его инфраструктуры.</li>
<li>Предоставлять ложную или вводящую в заблуждение информацию.</li>
<li>Использовать автоматизированные средства без разрешения.</li>
<li>Преследовать или причинять вред другим пользователям.</li>
</ul>

<h2>6. Контент и интеллектуальная собственность</h2>
<p>Весь контент Сервиса — включая текст, графику, логотипы, значки, цитаты и программное обеспечение — является собственностью команды Adat или её лицензиаров и защищён применимыми законами об интеллектуальной собственности.</p>

<h2>7. Конфиденциальность</h2>
<p>Использование Сервиса также регулируется нашей Политикой конфиденциальности. Используя Сервис, вы даёте согласие на сбор и использование информации.</p>

<h2>8. Отказ от гарантий</h2>
<p>Сервис предоставляется «как есть» и «как доступно» без каких-либо гарантий, явных или подразумеваемых.</p>

<h2>9. Ограничение ответственности</h2>
<p>В максимальной степени, допускаемой законом, команда Adat не несёт ответственности за любые косвенные, случайные, штрафные убытки или потерю прибыли, данных или деловой репутации.</p>

<h2>10. Прекращение</h2>
<p>Мы можем приостановить или прекратить ваш доступ к Сервису в любое время. Вы можете удалить свой аккаунт через настройки приложения.</p>

<h2>11. Изменения условий</h2>
<p>Мы оставляем за собой право изменять эти Условия в любое время. Продолжение использования означает принятие изменений.</p>

<h2>12. Применимое право</h2>
<p>Настоящие Условия регулируются законодательством Республики Казахстан.</p>

<h2>13. Контакты</h2>
<p>По вопросам об этих Условиях обращайтесь: <a href="mailto:alimkhan.ergebayev@gmail.com">alimkhan.ergebayev@gmail.com</a>.</p>
`;

const termsKK = `
<p><em>Соңғы жаңарту: 2026 жылғы 22 ақпан</em></p>

<h2>1. Шарттарды қабылдау</h2>
<p>Adat мобильді қосымшасына және онымен байланысты қызметтерге (жиынтықта «Қызмет») кіру немесе пайдалану арқылы сіз осы Қызмет көрсету шарттарын («Шарттар») сақтауға келісесіз. Келіспесеңіз, Қызметті пайдаланбаңыз.</p>

<h2>2. Қызмет сипаттамасы</h2>
<p>Adat — бұл мұсылмандарға күнделікті әдеттерді қалыптастыруға, серияларды бақылауға, күнделікті дәйексөздерді көруге және топтық жауапкершілікке қатысуға көмектесетін офлайн-бірінші ислами әдет бақылау қосымшасы.</p>

<h2>3. Қолжетімділік</h2>
<p>Қызметті пайдалану үшін сіздің жасыңыз кем дегенде 13-те болуы керек. 18-ден томен болсаңыз, ата-ана немесе қорғаншы келісімі қажет.</p>

<h2>4. Тіркелгілер</h2>
<p>Негізгі функционал үшін тіркелгі міндетті емес. Топтық мүмкіндіктер үшін тіркелгі жасасаңыз:</p>
<ul>
<li>Тіркелгі деректерінің қауіпсіздігіне сіз жауаптысыз.</li>
<li>Тіркелу кезінде дұрыс ақпарат беруіңіз қажет.</li>
<li>Тіркелгіні басқалармен бөліспеңіз.</li>
<li>Рұқсатсыз пайдалану туралы бізге хабарлаңыз.</li>
</ul>

<h2>5. Рұқсат етілген пайдалану</h2>
<p>Сіз мыналарды жасамауға келісесіз:</p>
<ul>
<li>Қызметті заңсыз мақсаттарда пайдалану.</li>
<li>Басқа пайдаланушылардың деректеріне рұқсатсыз кіруге тырысу.</li>
<li>Қызметтің жұмысына кедергі келтіру.</li>
<li>Жалған немесе адасушылық ақпарат беру.</li>
<li>Рұқсатсыз автоматтандырылған құралдарды пайдалану.</li>
<li>Басқа пайдаланушыларды қудалау немесе зиян келтіру.</li>
</ul>

<h2>6. Мазмұн және зияткерлік меншік</h2>
<p>Қызметтегі барлық мазмұн — мәтін, графика, логотиптер, белгішелер, дәйексөздер және бағдарламалық қамтамасыз ету — Adat командасының немесе оның лицензиарларының меншігі болып табылады.</p>

<h2>7. Құпиялылық</h2>
<p>Қызметті пайдалану біздің Құпиялылық саясатымызбен де реттеледі.</p>

<h2>8. Кепілдіктерден бас тарту</h2>
<p>Қызмет «қалай болса, солай» және «қолжетімді болса» негізінде ешқандай кепілдіксіз ұсынылады.</p>

<h2>9. Жауапкершілікті шектеу</h2>
<p>Заңмен рұқсат етілген шамада Adat командасы жанама, кездейсоқ, айыппұл шығындары немесе пайда, деректер жоғалтуы үшін жауапты болмайды.</p>

<h2>10. Тоқтату</h2>
<p>Біз сіздің Қызметке кіруіңізді кез келген уақытта тоқтата аламыз. Тіркелгіңізді қосымша баптаулары арқылы жоюға болады.</p>

<h2>11. Шарттардың өзгеруі</h2>
<p>Біз бұл Шарттарды кез келген уақытта өзгерту құқығын сақтаймыз. Пайдалануды жалғастыру өзгерістерді қабылдауды білдіреді.</p>

<h2>12. Қолданылатын құқық</h2>
<p>Бұл Шарттар Қазақстан Республикасының заңнамасымен реттеледі.</p>

<h2>13. Байланыс</h2>
<p>Сұрақтарыңыз болса, бізге хабарласыңыз: <a href="mailto:alimkhan.ergebayev@gmail.com">alimkhan.ergebayev@gmail.com</a>.</p>
`;

/* ------------------------------------------------------------------ */
/*  Privacy Policy                                                     */
/* ------------------------------------------------------------------ */
const privacyEN = `
<p><em>Last updated: February 22, 2026</em></p>

<h2>1. Introduction</h2>
<p>This Privacy Policy explains how Adat ("we", "us", "our") collects, uses, and protects information when you use our mobile application and related services (the "Service"). We are committed to protecting your privacy and being transparent about our data practices.</p>

<h2>2. Information We Collect</h2>

<p><strong>Waitlist Information:</strong> When you sign up for our waitlist, we collect:</p>
<ul>
<li>Email address</li>
<li>Language preference (English, Russian, or Kazakh)</li>
<li>Platform (iOS, Android, or web — detected automatically)</li>
<li>Timezone (detected automatically, optional)</li>
<li>Country (detected from request headers, optional)</li>
<li>A hash of your IP address (for rate-limiting purposes; we do not store your raw IP address)</li>
</ul>

<p><strong>App Usage (when the app launches):</strong></p>
<ul>
<li>Habit data, completions, and streaks — stored locally on your device</li>
<li>Saved quotes — stored locally on your device</li>
<li>Account information (email, username) — only if you create an account for group features</li>
</ul>

<h2>3. How We Use Your Information</h2>
<ul>
<li>To provide and maintain the Service</li>
<li>To notify you about launch availability and updates (waitlist emails)</li>
<li>To prevent abuse and enforce rate limits (IP hash)</li>
<li>To support group accountability features (if you create an account)</li>
<li>To improve the Service based on aggregate, anonymized usage patterns</li>
</ul>

<h2>4. Data Storage and Security</h2>
<p>Your habit data is stored locally on your device and is never sent to our servers unless you explicitly join a group. Waitlist and account data is stored securely on Supabase infrastructure with row-level security policies. We use industry-standard encryption for data in transit and at rest.</p>

<h2>5. Third-Party Services</h2>
<p>We use the following third-party services:</p>
<ul>
<li><strong>Supabase</strong> — Database and authentication infrastructure</li>
<li><strong>Cloudflare Turnstile</strong> — Bot protection for the waitlist form (no personal data shared)</li>
<li><strong>Resend</strong> — Email delivery for launch notifications</li>
</ul>
<p>Each service has its own privacy policy governing the use of your data.</p>

<h2>6. Data Retention</h2>
<ul>
<li>Waitlist data is retained until you unsubscribe or request deletion.</li>
<li>Local app data is retained on your device until you delete the app or clear data.</li>
<li>Account data is retained until you delete your account.</li>
</ul>

<h2>7. Your Rights</h2>
<p>You have the right to:</p>
<ul>
<li>Request access to your personal data</li>
<li>Request correction of inaccurate data</li>
<li>Request deletion of your data</li>
<li>Unsubscribe from waitlist emails at any time</li>
<li>Delete your account through the app settings</li>
</ul>
<p>To exercise these rights, contact us at the email address below.</p>

<h2>8. Cookies</h2>
<p>Our landing page may use a minimal cookie or localStorage entry to remember your language preference. We do not use tracking cookies or advertising cookies.</p>

<h2>9. Children's Privacy</h2>
<p>The Service is not intended for children under 13. We do not knowingly collect personal data from children under 13. If you believe we have inadvertently collected such data, please contact us so we can promptly delete it.</p>

<h2>10. Changes to This Policy</h2>
<p>We may update this Privacy Policy from time to time. Changes will be posted within the app or on our website with an updated revision date.</p>

<h2>11. Contact</h2>
<p>If you have questions about this Privacy Policy, please contact us at <a href="mailto:alimkhan.ergebayev@gmail.com">alimkhan.ergebayev@gmail.com</a>.</p>
`;

const privacyRU = `
<p><em>Последнее обновление: 22 февраля 2026 г.</em></p>

<h2>1. Введение</h2>
<p>Настоящая Политика конфиденциальности объясняет, как Adat («мы», «нас», «наш») собирает, использует и защищает информацию при использовании мобильного приложения и связанных сервисов («Сервис»).</p>

<h2>2. Собираемая информация</h2>

<p><strong>Информация при записи в лист ожидания:</strong></p>
<ul>
<li>Электронная почта</li>
<li>Языковые предпочтения (английский, русский или казахский)</li>
<li>Платформа (iOS, Android или веб — определяется автоматически)</li>
<li>Часовой пояс (определяется автоматически, необязательно)</li>
<li>Страна (определяется из заголовков запроса, необязательно)</li>
<li>Хэш IP-адреса (для ограничения частоты запросов; исходный IP не хранится)</li>
</ul>

<p><strong>Данные приложения:</strong></p>
<ul>
<li>Данные о привычках, выполнениях и сериях — хранятся локально на устройстве</li>
<li>Сохранённые цитаты — хранятся локально на устройстве</li>
<li>Данные аккаунта (email, имя пользователя) — только при создании аккаунта для групп</li>
</ul>

<h2>3. Использование информации</h2>
<ul>
<li>Обеспечение и поддержка Сервиса</li>
<li>Уведомление о запуске и обновлениях</li>
<li>Предотвращение злоупотреблений (хэш IP)</li>
<li>Поддержка групповых функций</li>
<li>Улучшение Сервиса на основе анонимных данных</li>
</ul>

<h2>4. Хранение и безопасность данных</h2>
<p>Данные о привычках хранятся локально и не передаются на серверы, если вы не присоединитесь к группе. Данные аккаунтов хранятся на инфраструктуре Supabase с политиками безопасности на уровне строк.</p>

<h2>5. Сторонние сервисы</h2>
<ul>
<li><strong>Supabase</strong> — база данных и аутентификация</li>
<li><strong>Cloudflare Turnstile</strong> — защита от ботов</li>
<li><strong>Resend</strong> — доставка email-уведомлений</li>
</ul>

<h2>6. Срок хранения данных</h2>
<ul>
<li>Данные листа ожидания — до отписки или запроса удаления</li>
<li>Локальные данные — до удаления приложения</li>
<li>Данные аккаунта — до удаления аккаунта</li>
</ul>

<h2>7. Ваши права</h2>
<p>Вы имеете право запросить доступ, исправление или удаление ваших данных, отписаться от рассылки или удалить аккаунт через настройки приложения.</p>

<h2>8. Файлы cookie</h2>
<p>Мы можем использовать cookie или localStorage для сохранения языковых предпочтений. Трекинговые или рекламные cookie не используются.</p>

<h2>9. Конфиденциальность детей</h2>
<p>Сервис не предназначен для детей младше 13 лет. Если вы считаете, что мы случайно собрали такие данные, свяжитесь с нами.</p>

<h2>10. Изменения политики</h2>
<p>Мы можем обновлять эту Политику. Изменения публикуются в приложении или на сайте.</p>

<h2>11. Контакты</h2>
<p>По вопросам: <a href="mailto:alimkhan.ergebayev@gmail.com">alimkhan.ergebayev@gmail.com</a>.</p>
`;

const privacyKK = `
<p><em>Соңғы жаңарту: 2026 жылғы 22 ақпан</em></p>

<h2>1. Кіріспе</h2>
<p>Бұл Құпиялылық саясаты Adat («біз», «бізді», «біздің») мобильді қосымшаны және онымен байланысты қызметтерді («Қызмет») пайдаланған кезде ақпаратты қалай жинайтынын, пайдаланатынын және қорғайтынын түсіндіреді.</p>

<h2>2. Жиналатын ақпарат</h2>

<p><strong>Күту тізіміне тіркелу кезінде:</strong></p>
<ul>
<li>Электрондық пошта</li>
<li>Тіл параметрлері (ағылшын, орыс немесе қазақ)</li>
<li>Платформа (iOS, Android немесе веб — автоматты түрде анықталады)</li>
<li>Уақыт белдеуі (автоматты, міндетті емес)</li>
<li>Ел (сұрау тақырыбынан анықталады, міндетті емес)</li>
<li>IP мекенжайыңыздың хэші (жиілікті шектеу мақсатында; бастапқы IP сақталмайды)</li>
</ul>

<p><strong>Қосымша деректері:</strong></p>
<ul>
<li>Әдеттер, орындалулар және сериялар — құрылғыда жергілікті түрде сақталады</li>
<li>Сақталған дәйексөздер — құрылғыда жергілікті түрде сақталады</li>
<li>Тіркелгі ақпараты — тек топтық мүмкіндіктер үшін тіркелгі жасағанда</li>
</ul>

<h2>3. Ақпаратты пайдалану</h2>
<ul>
<li>Қызметті қамтамасыз ету және қолдау</li>
<li>Іске қосылу және жаңартулар туралы хабарлау</li>
<li>Теріс пайдалануды болдырмау (IP хэші)</li>
<li>Топтық мүмкіндіктерді қолдау</li>
<li>Анонимді деректер негізінде Қызметті жақсарту</li>
</ul>

<h2>4. Деректерді сақтау және қауіпсіздік</h2>
<p>Әдет деректері құрылғыда жергілікті түрде сақталады және топқа қосылмасаңыз серверлерімізге жіберілмейді. Тіркелгі деректері Supabase инфрақұрылымында қатар деңгейіндегі қауіпсіздік саясаттарымен сақталады.</p>

<h2>5. Үшінші тарап қызметтері</h2>
<ul>
<li><strong>Supabase</strong> — дерекқор және аутентификация</li>
<li><strong>Cloudflare Turnstile</strong> — боттардан қорғау</li>
<li><strong>Resend</strong> — email хабарламаларын жеткізу</li>
</ul>

<h2>6. Деректерді сақтау мерзімі</h2>
<ul>
<li>Күту тізімінің деректері — жазылымнан бас тартқанша немесе жою сұранымына дейін</li>
<li>Жергілікті деректер — қосымшаны жойғанша</li>
<li>Тіркелгі деректері — тіркелгіні жойғанша</li>
</ul>

<h2>7. Сіздің құқықтарыңыз</h2>
<p>Деректеріңізге кіруді, түзетуді немесе жоюды сұрауға, тарату тізімінен шығуға немесе тіркелгіңізді қосымша баптаулары арқылы жоюға құқығыңыз бар.</p>

<h2>8. Cookie файлдары</h2>
<p>Тіл параметрлерін сақтау үшін cookie немесе localStorage пайдалануымыз мүмкін. Бақылау немесе жарнамалық cookie пайдаланылмайды.</p>

<h2>9. Балалардың құпиялылығы</h2>
<p>Қызмет 13 жасқа толмаған балаларға арналмаған. Мұндай деректер жиналған деп ойласаңыз, бізге хабарласыңыз.</p>

<h2>10. Саясат өзгерістері</h2>
<p>Біз бұл Саясатты жаңарта аламыз. Өзгерістер қосымшада немесе сайтта жарияланады.</p>

<h2>11. Байланыс</h2>
<p>Сұрақтарыңыз бойынша: <a href="mailto:alimkhan.ergebayev@gmail.com">alimkhan.ergebayev@gmail.com</a>.</p>
`;

/* ------------------------------------------------------------------ */
/*  Exports                                                            */
/* ------------------------------------------------------------------ */
const termsContent: Record<Locale, string> = {
  en: termsEN,
  ru: termsRU,
  kk: termsKK,
};

const privacyContent: Record<Locale, string> = {
  en: privacyEN,
  ru: privacyRU,
  kk: privacyKK,
};

export function getTermsContent(locale: Locale): string {
  return termsContent[locale] ?? termsContent.en;
}

export function getPrivacyContent(locale: Locale): string {
  return privacyContent[locale] ?? privacyContent.en;
}
